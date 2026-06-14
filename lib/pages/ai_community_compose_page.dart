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
import '../widgets/feature_page_scaffold.dart';

class AiCommunityComposePage extends StatefulWidget {
  const AiCommunityComposePage({super.key});

  @override
  State<AiCommunityComposePage> createState() => _AiCommunityComposePageState();
}

class _AiCommunityComposePageState extends State<AiCommunityComposePage> {
  final _service = AiCommunityService();
  final _paintService = AiPaintService();
  final _controller = TextEditingController();

  List<AiArtwork> _artworks = [];
  bool _loadingArtworks = true;
  bool _submitting = false;
  String? _selectedArtworkPath;
  Uint8List? _pickedBytes;
  String? _pickedMimeType;

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    setState(() {
      _pickedBytes = bytes;
      _pickedMimeType = mimeType;
      _selectedArtworkPath = null;
    });
  }

  void _selectArtwork(AiArtwork artwork) {
    setState(() {
      _selectedArtworkPath = artwork.imagePath;
      _pickedBytes = null;
      _pickedMimeType = null;
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      showTopSnackBar(
        context,
        content: Text('请输入朋友圈内容', style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      var imagePath = _selectedArtworkPath ?? '';
      if (_pickedBytes != null && _pickedMimeType != null) {
        imagePath = await _service.uploadImage(_pickedBytes!, _pickedMimeType!);
      }

      final post = await _service.createPost(content: content, imagePath: imagePath);
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '发朋友圈',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '分享此刻的想法…',
              hintStyle: FeaturePageStyle.secondary(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(FeaturePageStyle.s(12))),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: FeaturePageStyle.s(16)),
          Text('配图（可选）', style: FeaturePageStyle.sectionTitle()),
          SizedBox(height: FeaturePageStyle.s(10)),
          Wrap(
            spacing: FeaturePageStyle.s(10),
            runSpacing: FeaturePageStyle.s(10),
            children: [
              _AddImageTile(onTap: _pickImage),
              if (_pickedBytes != null)
                _PreviewTile(
                  child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                  onRemove: () => setState(() {
                    _pickedBytes = null;
                    _pickedMimeType = null;
                  }),
                ),
              if (_selectedArtworkPath != null)
                FutureBuilder<String>(
                  future: resolveRemoteMediaUrl(_selectedArtworkPath),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return SizedBox(
                        width: FeaturePageStyle.s(88),
                        height: FeaturePageStyle.s(88),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _PreviewTile(
                      child: Image.network(snapshot.data!, fit: BoxFit.cover),
                      onRemove: () => setState(() => _selectedArtworkPath = null),
                    );
                  },
                ),
            ],
          ),
          SizedBox(height: FeaturePageStyle.s(18)),
          Text('从我的 AI 绘画选择', style: FeaturePageStyle.caption()),
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
                  final selected = _selectedArtworkPath == artwork.imagePath;
                  return GestureDetector(
                    onTap: () => _selectArtwork(artwork),
                    child: FutureBuilder<String>(
                      future: resolveRemoteMediaUrl(artwork.imagePath),
                      builder: (context, snapshot) {
                        return Container(
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
                              ? Image.network(snapshot.data!, fit: BoxFit.cover)
                              : Container(color: AppColors.muted),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: FeaturePageStyle.s(28)),
          FilledButton(
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
                : Text('发布', style: TextStyle(fontSize: FeaturePageStyle.s(16), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: FeaturePageStyle.s(88),
        height: FeaturePageStyle.s(88),
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

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: FeaturePageStyle.s(88),
          height: FeaturePageStyle.s(88),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FeaturePageStyle.s(10)),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
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
