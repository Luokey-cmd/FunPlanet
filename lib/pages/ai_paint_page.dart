import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/ai_artwork.dart';
import '../data/product_data.dart';
import '../services/ai_paint_service.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../utils/media_url.dart';
import '../utils/save_artwork_image.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/sparkle_background.dart';
import 'image_preview_page.dart';

class AiPaintPage extends StatefulWidget {
  const AiPaintPage({super.key});

  @override
  State<AiPaintPage> createState() => _AiPaintPageState();
}

class _AiPaintPageState extends State<AiPaintPage> {
  final _service = AiPaintService();
  final _promptController = TextEditingController();

  List<AiArtwork> _artworks = [];
  AiArtwork? _currentArtwork;
  AiPaintQuota? _quota;
  String _styleKey = 'default';
  bool _loadingPage = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _loadInitial();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial({bool retried = false}) async {
    setState(() => _loadingPage = true);
    String? errorMsg;

    try {
      _quota = await _service.fetchQuota();
    } catch (error) {
      errorMsg = _formatLoadError(error);
      _quota = const AiPaintQuota(dailyLimit: 20, usedToday: 0, remainingToday: 20);
    }

    try {
      _artworks = await _service.fetchArtworks();
    } catch (error) {
      errorMsg ??= _formatLoadError(error);
      _artworks = [];
    }

    if (!mounted) return;

    if (errorMsg != null && !retried && _shouldRetryWithFreshBaseUrl(errorMsg)) {
      ApiConfig.reset();
      await _loadInitial(retried: true);
      return;
    }

    setState(() => _loadingPage = false);
    if (errorMsg != null) {
      showTopSnackBar(
        context,
        content: Text(
          errorMsg,
          style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  bool _shouldRetryWithFreshBaseUrl(String message) {
    return message.contains('无法连接后端') ||
        message.contains('Connection') ||
        message.contains('SocketException') ||
        message.contains('服务器响应格式错误');
  }

  String _formatLoadError(Object error) {
    if (error is ApiException) return error.message;
    if (error is TimeoutException) return '网络超时，请检查网络后重试';
    if (error is StateError) return error.message;
    return error.toString();
  }

  String _formatGenerateError(Object error) {
    if (error is TimeoutException) {
      return '绘画超时，万相生成通常需要 20～60 秒，请稍后再试';
    }
    return _formatLoadError(error);
  }

  Future<void> _generate() async {
    final rawPrompt = _promptController.text.trim();
    if (rawPrompt.isEmpty || _generating) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _currentArtwork = null;
    });

    final prompt = buildAiPaintPrompt(rawPrompt, _styleKey);
    try {
      final result = await _service.generate(prompt: prompt, style: _styleKey);
      if (!mounted) return;
      setState(() {
        _currentArtwork = result.artwork;
        _artworks = [
          result.artwork,
          ..._artworks.where((item) => item.id != result.artwork.id),
        ];
        _quota = AiPaintQuota(
          dailyLimit: _quota?.dailyLimit ?? 20,
          usedToday: (_quota?.dailyLimit ?? 20) - result.remainingToday,
          remainingToday: result.remainingToday,
        );
        _generating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      showTopSnackBar(
        context,
        content: Text(
          _formatGenerateError(error),
          style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  void _applySuggestion(String text) {
    _promptController.text = text;
    _promptController.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _saveArtwork(AiArtwork artwork) async {
    try {
      await saveArtworkImageToGallery(artwork.imagePath);
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text(
          '已保存到相册',
          style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is SaveArtworkImageException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(
          message,
          style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  void _openPreview(AiArtwork artwork) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ImagePreviewPage(
          saveImagePath: artwork.imagePath,
          child: FutureBuilder<String>(
            future: resolveRemoteMediaUrl(artwork.imagePath),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              return Image.network(snapshot.data!, fit: BoxFit.contain);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(8), FeaturePageStyle.s(8), FeaturePageStyle.s(12), FeaturePageStyle.s(8)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: FeaturePageStyle.iconSize),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI绘画', style: FeaturePageStyle.pageTitle()),
                          Text(
                            _quota == null ? '通义万相 · 文生图' : '今日剩余 ${_quota!.remainingToday}/${_quota!.dailyLimit} 次',
                            style: FeaturePageStyle.caption(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loadingPage
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        FeaturePageStyle.s(16),
                        FeaturePageStyle.s(12),
                        FeaturePageStyle.s(16),
                        FeaturePageStyle.s(24) + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _TopBanner(),
                          SizedBox(height: FeaturePageStyle.s(12)),
                          _HintCard(),
                          SizedBox(height: FeaturePageStyle.s(14)),
                          _PromptInput(controller: _promptController, enabled: !_generating),
                          SizedBox(height: FeaturePageStyle.s(12)),
                          _SuggestionRow(onPick: _applySuggestion),
                          SizedBox(height: FeaturePageStyle.s(14)),
                          _StyleSection(
                            selectedKey: _styleKey,
                            onSelected: (key) => setState(() => _styleKey = key),
                          ),
                          SizedBox(height: FeaturePageStyle.s(16)),
                          _GenerateButton(
                            generating: _generating,
                            enabled: _promptController.text.trim().isNotEmpty && (_quota?.remainingToday ?? 1) > 0,
                            onPressed: _generate,
                          ),
                          if (_generating) ...[
                            SizedBox(height: FeaturePageStyle.s(18)),
                            _GeneratingPanel(),
                          ],
                          if (_currentArtwork != null && !_generating) ...[
                            SizedBox(height: FeaturePageStyle.s(18)),
                            _ResultCard(
                              artwork: _currentArtwork!,
                              onPreview: () => _openPreview(_currentArtwork!),
                              onRegenerate: _generate,
                              onSave: () => _saveArtwork(_currentArtwork!),
                            ),
                          ],
                          if (_artworks.isNotEmpty) ...[
                            SizedBox(height: FeaturePageStyle.s(22)),
                            Text('我的作品', style: FeaturePageStyle.sectionTitle()),
                            SizedBox(height: FeaturePageStyle.s(12)),
                            _ArtworkGrid(
                              artworks: _artworks,
                              onTap: (artwork) {
                                setState(() => _currentArtwork = artwork);
                                _openPreview(artwork);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          aiPaintEntryPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.muted,
            alignment: Alignment.center,
            child: Icon(Icons.image_not_supported_outlined, color: AppColors.mutedForeground, size: FeaturePageStyle.s(28)),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(FeaturePageStyle.s(14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary, size: FeaturePageStyle.s(24)),
          SizedBox(width: FeaturePageStyle.s(10)),
          Expanded(
            child: Text(
              '描述你想画的画面，选择风格后一键生成 2K 高清插画。',
              style: FeaturePageStyle.secondary(color: AppColors.foreground.withValues(alpha: 0.82)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptInput extends StatelessWidget {
  const _PromptInput({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: 4,
      maxLines: 6,
      maxLength: 500,
      style: FeaturePageStyle.body(),
      decoration: InputDecoration(
        hintText: '例如：一只可爱的卡通猫咪，坐在洒满阳光的窗台上，背景是蓝天白云',
        hintStyle: FeaturePageStyle.secondary(),
        filled: true,
        fillColor: AppColors.card,
        counterStyle: FeaturePageStyle.caption(),
        contentPadding: EdgeInsets.all(FeaturePageStyle.s(14)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: FeaturePageStyle.s(8),
      runSpacing: FeaturePageStyle.s(8),
      children: aiPromptSuggestions.map((text) {
        return ActionChip(
          label: Text(text, style: FeaturePageStyle.caption(color: AppColors.foreground)),
          backgroundColor: AppColors.muted,
          side: const BorderSide(color: AppColors.border),
          onPressed: () => onPick(text),
        );
      }).toList(),
    );
  }
}

class _StyleSection extends StatelessWidget {
  const _StyleSection({required this.selectedKey, required this.onSelected});

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('绘画风格', style: FeaturePageStyle.sectionTitle()),
        SizedBox(height: FeaturePageStyle.s(10)),
        Wrap(
          spacing: FeaturePageStyle.s(8),
          runSpacing: FeaturePageStyle.s(8),
          children: aiStylePresets.map((preset) {
            final active = preset.key == selectedKey;
            return ChoiceChip(
              label: Text(preset.label),
              selected: active,
              onSelected: (_) => onSelected(preset.key),
              selectedColor: AppColors.secondary,
              labelStyle: FeaturePageStyle.caption(
                color: active ? AppColors.primary : AppColors.mutedForeground,
                weight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(color: active ? AppColors.primaryLight : AppColors.border),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.generating,
    required this.enabled,
    required this.onPressed,
  });

  final bool generating;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: generating || !enabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(FeaturePageStyle.buttonHeight),
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FeaturePageStyle.s(999))),
      ),
      child: generating
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: FeaturePageStyle.s(18),
                  height: FeaturePageStyle.s(18),
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: FeaturePageStyle.s(10)),
                Text('正在创作中…', style: FeaturePageStyle.action(color: Colors.white)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.brush, color: Colors.white, size: FeaturePageStyle.s(20)),
                SizedBox(width: FeaturePageStyle.s(8)),
                Text('开始创作', style: FeaturePageStyle.action(color: Colors.white)),
              ],
            ),
    );
  }
}

class _GeneratingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(FeaturePageStyle.s(18)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: FeaturePageStyle.s(42),
            height: FeaturePageStyle.s(42),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: FeaturePageStyle.s(12)),
          Text('AI 正在绘制你的想象…', style: FeaturePageStyle.bodyBold()),
          SizedBox(height: FeaturePageStyle.s(4)),
          Text('通常需要 10～40 秒，请耐心等待', style: FeaturePageStyle.caption()),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.artwork,
    required this.onPreview,
    required this.onRegenerate,
    required this.onSave,
  });

  final AiArtwork artwork;
  final VoidCallback onPreview;
  final VoidCallback onRegenerate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onPreview,
            child: AspectRatio(
              aspectRatio: 1,
              child: _ArtworkImage(imagePath: artwork.imagePath),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(FeaturePageStyle.s(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artwork.prompt, maxLines: 3, overflow: TextOverflow.ellipsis, style: FeaturePageStyle.body()),
                SizedBox(height: FeaturePageStyle.s(12)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPreview,
                        child: Text('查看大图', style: FeaturePageStyle.action()),
                      ),
                    ),
                    SizedBox(width: FeaturePageStyle.s(8)),
                    Expanded(
                      child: FilledButton(
                        onPressed: onRegenerate,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: Text('再次生成', style: FeaturePageStyle.action(color: Colors.white)),
                      ),
                    ),
                    SizedBox(width: FeaturePageStyle.s(8)),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSave,
                        child: Text('保存到本地', style: FeaturePageStyle.action()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({required this.artworks, required this.onTap});

  final List<AiArtwork> artworks;
  final ValueChanged<AiArtwork> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: artworks.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: FeaturePageStyle.s(8),
        mainAxisSpacing: FeaturePageStyle.s(8),
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final artwork = artworks[index];
        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(artwork),
            child: _ArtworkImage(imagePath: artwork.imagePath),
          ),
        );
      },
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(imagePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: AppColors.muted,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Image.network(
          snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.muted,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: AppColors.mutedForeground, size: FeaturePageStyle.s(28)),
          ),
        );
      },
    );
  }
}
