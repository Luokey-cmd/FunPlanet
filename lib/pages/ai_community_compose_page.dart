import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/ai_artwork.dart';
import '../services/ai_community_service.dart';
import '../services/ai_paint_service.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../utils/media_url.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/ai_generated_badge.dart';
import '../widgets/app_network_image.dart';
import '../widgets/click_effect/app_buttons.dart';
import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_pressable.dart';
import '../widgets/sparkle_background.dart';

enum _ComposeMode { text, image }

class _PickedUpload {
  _PickedUpload.local({
    required this.bytes,
    required this.mimeType,
  })  : remotePath = '',
        uploading = true,
        failed = false,
        progress = 0,
        fromArtwork = false;

  _PickedUpload.remote({
    required this.remotePath,
  })  : bytes = null,
        mimeType = null,
        uploading = false,
        failed = false,
        progress = 1,
        fromArtwork = true;

  final Uint8List? bytes;
  final String? mimeType;
  String remotePath;
  double progress;
  bool uploading;
  bool failed;
  final bool fromArtwork;

  bool get ready => remotePath.trim().isNotEmpty && !failed && !uploading;
}

/// 参考 peduliAI 广场发帖：类型切换 + 九宫格选图上传进度 + AppBar 发布。
class AiCommunityComposePage extends StatefulWidget {
  const AiCommunityComposePage({super.key});

  @override
  State<AiCommunityComposePage> createState() => _AiCommunityComposePageState();
}

class _AiCommunityComposePageState extends State<AiCommunityComposePage> {
  static const _maxImages = 9;
  static const _maxContentLength = 500;

  final _service = AiCommunityService();
  final _paintService = AiPaintService();
  final _controller = TextEditingController();

  _ComposeMode _mode = _ComposeMode.text;
  final List<_PickedUpload> _images = [];
  List<AiArtwork> _artworks = [];
  bool _loadingArtworks = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _loadArtworks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadArtworks() async {
    try {
      _artworks = await _paintService.fetchArtworks(limit: 30);
    } catch (_) {
      _artworks = [];
    }
    if (mounted) setState(() => _loadingArtworks = false);
  }

  void _toast(String message) {
    showTopSnackBar(
      context,
      content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      _toast('最多上传 $_maxImages 张图片');
      return;
    }
    final remain = _maxImages - _images.length;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final pending = <_PickedUpload>[];
    for (final file in result.files.take(remain)) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final ext = (file.extension ?? '').toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      pending.add(_PickedUpload.local(bytes: bytes, mimeType: mimeType));
    }
    if (pending.isEmpty) return;

    setState(() {
      _mode = _ComposeMode.image;
      _images.addAll(pending);
    });

    for (final item in pending) {
      if (!mounted) return;
      try {
        setState(() {
          item.uploading = true;
          item.progress = 0.2;
        });
        final path = await _service.uploadImage(item.bytes!, item.mimeType!);
        if (!mounted) return;
        setState(() {
          item.remotePath = path;
          item.uploading = false;
          item.failed = false;
          item.progress = 1;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          item.uploading = false;
          item.failed = true;
          item.progress = 0;
        });
      }
    }
    if (!mounted) return;
    if (_images.any((e) => e.failed)) {
      _toast('部分图片上传失败，可删除后重试');
    }
  }

  void _addArtwork(AiArtwork artwork) {
    final path = artwork.imagePath.trim();
    if (path.isEmpty) return;
    if (_images.any((e) => e.remotePath == path)) {
      _toast('该作品已添加');
      return;
    }
    if (_images.length >= _maxImages) {
      _toast('最多上传 $_maxImages 张图片');
      return;
    }
    setState(() {
      _mode = _ComposeMode.image;
      _images.add(_PickedUpload.remote(remotePath: path));
    });
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final content = _controller.text.trim();

    if (_mode == _ComposeMode.text && content.isEmpty) {
      _toast('请输入动态内容');
      return;
    }
    if (_mode == _ComposeMode.image && _images.isEmpty) {
      _toast('请至少添加一张图片');
      return;
    }
    if (_images.any((e) => e.uploading)) {
      _toast('图片上传中，请稍候');
      return;
    }
    if (_mode == _ComposeMode.image && !_images.any((e) => e.ready)) {
      _toast('没有可用图片，请重新选择');
      return;
    }

    final readyPaths = _images.where((e) => e.ready).map((e) => e.remotePath).toList();

    setState(() => _submitting = true);
    try {
      final post = await _service.createPost(
        content: content,
        imagePaths: _mode == _ComposeMode.image ? readyPaths : const [],
      );
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      _toast(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SparkleBackground(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    FeaturePageStyle.s(4),
                    FeaturePageStyle.s(4),
                    FeaturePageStyle.s(12),
                    FeaturePageStyle.s(4),
                  ),
                  child: Row(
                    children: [
                      AppIconButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.foreground, size: FeaturePageStyle.iconSize),
                      ),
                      Expanded(
                        child: Text('发布动态', style: FeaturePageStyle.pageTitle()),
                      ),
                      AppTextButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting ? '发布中' : '发布',
                          style: TextStyle(
                            fontSize: FeaturePageStyle.t(15),
                            fontWeight: FontWeight.w700,
                            color: _submitting ? AppColors.mutedForeground : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    FeaturePageStyle.s(16),
                    FeaturePageStyle.s(8),
                    FeaturePageStyle.s(16),
                    FeaturePageStyle.s(28),
                  ),
                  children: [
                    _ModeChips(
                      mode: _mode,
                      enabled: !_submitting,
                      onChanged: (mode) {
                        setState(() {
                          _mode = mode;
                          if (mode == _ComposeMode.text) {
                            _images.clear();
                          }
                        });
                      },
                    ),
                    SizedBox(height: FeaturePageStyle.s(16)),
                    AppTextField(
                      controller: _controller,
                      enabled: !_submitting,
                      maxLines: 8,
                      minLines: 4,
                      maxLength: _maxContentLength,
                      decoration: InputDecoration(
                        hintText: _mode == _ComposeMode.text ? '分享你的想法…' : '添加描述（可选）',
                        hintStyle: FeaturePageStyle.secondary(),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      style: TextStyle(
                        fontSize: FeaturePageStyle.t(15),
                        height: 1.5,
                        color: AppColors.foreground,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_controller.text.length}/$_maxContentLength',
                        style: FeaturePageStyle.caption(),
                      ),
                    ),
                    if (_mode == _ComposeMode.image) ...[
                      SizedBox(height: FeaturePageStyle.s(8)),
                      _ImageGrid(
                        images: _images,
                        onAdd: _submitting ? null : _pickImages,
                        onRemove: _submitting ? null : _removeImage,
                      ),
                      SizedBox(height: FeaturePageStyle.s(18)),
                      Text('从我的 AI 绘画添加', style: FeaturePageStyle.caption()),
                      SizedBox(height: FeaturePageStyle.s(10)),
                      if (_loadingArtworks)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      else if (_artworks.isEmpty)
                        Text('暂无 AI 绘画作品，可先去 AI 绘画创作', style: FeaturePageStyle.secondary())
                      else
                        SizedBox(
                          height: FeaturePageStyle.s(92),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _artworks.length,
                            separatorBuilder: (_, __) => SizedBox(width: FeaturePageStyle.s(10)),
                            itemBuilder: (context, index) {
                              final artwork = _artworks[index];
                              final selected = _images.any((e) => e.remotePath == artwork.imagePath);
                              return AppGestureDetector(
                                onTap: _submitting ? null : () => _addArtwork(artwork),
                                child: FutureBuilder<String>(
                                  future: resolveRemoteMediaUrl(artwork.imagePath),
                                  builder: (context, snapshot) {
                                    return Stack(
                                      children: [
                                        Container(
                                          width: FeaturePageStyle.s(88),
                                          height: FeaturePageStyle.s(88),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(FeaturePageStyle.s(10)),
                                            border: Border.all(
                                              color: selected ? AppColors.primary : AppColors.border,
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: snapshot.hasData
                                              ? AppNetworkImage(url: snapshot.data!, fit: BoxFit.cover)
                                              : Container(color: AppColors.muted),
                                        ),
                                        const Positioned(
                                          left: 4,
                                          top: 4,
                                          child: AiGeneratedBadge(compact: true),
                                        ),
                                        if (selected)
                                          Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: Icon(Icons.check_circle, color: AppColors.primary, size: FeaturePageStyle.s(18)),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                    SizedBox(height: FeaturePageStyle.s(24)),
                    AppFilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size.fromHeight(FeaturePageStyle.s(48)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FeaturePageStyle.s(14))),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: FeaturePageStyle.s(22),
                              height: FeaturePageStyle.s(22),
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('发布', style: TextStyle(fontSize: FeaturePageStyle.t(16), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _ComposeMode mode;
  final bool enabled;
  final ValueChanged<_ComposeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _ComposeMode value) {
      final selected = mode == value;
      return AppGestureDetector(
        onTap: enabled ? () => onChanged(value) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(14), vertical: FeaturePageStyle.s(8)),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.muted,
            borderRadius: BorderRadius.circular(FeaturePageStyle.s(20)),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: FeaturePageStyle.t(13),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('文字', _ComposeMode.text),
        SizedBox(width: FeaturePageStyle.s(8)),
        chip('图片', _ComposeMode.image),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_PickedUpload> images;
  final VoidCallback? onAdd;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    final size = FeaturePageStyle.s(96);
    final tiles = <Widget>[
      for (var i = 0; i < images.length; i++)
        _ImageTile(
          size: size,
          item: images[i],
          onRemove: onRemove == null ? null : () => onRemove!(i),
        ),
      if (images.length < 9 && onAdd != null) _AddTile(size: size, onTap: onAdd!),
    ];
    return Wrap(
      spacing: FeaturePageStyle.s(8),
      runSpacing: FeaturePageStyle.s(8),
      children: tiles,
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(FeaturePageStyle.s(10)),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.mutedForeground, size: FeaturePageStyle.s(28)),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.size,
    required this.item,
    required this.onRemove,
  });

  final double size;
  final _PickedUpload item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(FeaturePageStyle.s(10)),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.bytes != null)
                  Image.memory(item.bytes!, fit: BoxFit.cover)
                else if (item.remotePath.isNotEmpty)
                  FutureBuilder<String>(
                    future: resolveRemoteMediaUrl(item.remotePath),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container(color: AppColors.muted);
                      return AppNetworkImage(url: snapshot.data!, fit: BoxFit.cover);
                    },
                  )
                else
                  Container(color: AppColors.muted),
                if (item.uploading || item.failed)
                  ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: item.failed
                          ? Icon(Icons.error_outline, color: Colors.white, size: FeaturePageStyle.s(24))
                          : SizedBox(
                              width: FeaturePageStyle.s(28),
                              height: FeaturePageStyle.s(28),
                              child: CircularProgressIndicator(
                                value: item.progress > 0 && item.progress < 1 ? item.progress : null,
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                if (item.fromArtwork)
                  const Positioned(
                    left: 4,
                    top: 4,
                    child: AiGeneratedBadge(compact: true),
                  ),
              ],
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -4,
            right: -4,
            child: AppGestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: FeaturePageStyle.s(16), color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
