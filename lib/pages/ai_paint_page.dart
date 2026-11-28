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
import '../widgets/ai_generated_badge.dart';
import '../widgets/app_network_image.dart';
import '../widgets/sparkle_background.dart';
import 'image_preview_page.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_buttons.dart';
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
  String _ratioKey = 'square';
  // 我的作品多选模式：开着时点作品图是勾选（不是打开预览），
  // 底部操作条批量下载/删除；取消或处理完自动退出。
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};
  bool _batchBusy = false;
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
          style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600),
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
    final ratio = aiRatioPresets.firstWhere(
      (item) => item.key == _ratioKey,
      orElse: () => aiRatioPresets.first,
    );
    try {
      final result = await _service.generate(
        prompt: prompt,
        style: _styleKey,
        size: ratio.size,
      );
      if (!mounted) return;
      final fresh = result.artworks;
      setState(() {
        _currentArtwork = fresh.first;
        _artworks = [
          ...fresh,
          ..._artworks.where((item) => !fresh.any((f) => f.id == item.id)),
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
          style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600),
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
          style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is SaveArtworkImageException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(
          message,
          style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  void _openPreview(AiArtwork artwork) {
    unawaited(
      ImagePreviewPage.openNetwork(
        context,
        urls: [artwork.imagePath],
        saveImagePath: artwork.imagePath,
      ),
    );
  }

  void _toast(String message) {
    showTopSnackBar(
      context,
      content: Text(
        message,
        style: TextStyle(fontSize: FeaturePageStyle.t(14), fontWeight: FontWeight.w600),
      ),
    );
  }

  // 进出多选模式：退出时把已勾的清空，别让勾选状态赖到下一次。
  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selectedIds.clear();
    });
  }

  void _toggleSelected(AiArtwork artwork) {
    setState(() {
      if (!_selectedIds.remove(artwork.id)) {
        _selectedIds.add(artwork.id);
      }
    });
  }

  // 批量下载选中的作品到相册：一张张存，个别失败不挡其余的，最后汇总报数；
  // 全成功才退出多选，有失败的留在多选里方便重试。
  Future<void> _downloadSelected() async {
    if (_selectedIds.isEmpty || _batchBusy) return;
    final targets = _artworks.where((a) => _selectedIds.contains(a.id)).toList();
    setState(() => _batchBusy = true);
    var saved = 0;
    String? firstError;
    for (final artwork in targets) {
      try {
        await saveArtworkImageToGallery(artwork.imagePath);
        saved += 1;
      } catch (error) {
        firstError ??= error is SaveArtworkImageException ? error.message : '$error';
      }
    }
    if (!mounted) return;
    setState(() => _batchBusy = false);
    if (saved == targets.length) {
      _toggleSelecting();
      _toast('已保存 $saved 张到相册');
    } else if (saved > 0) {
      _toast('已保存 $saved 张，${targets.length - saved} 张失败：${firstError ?? ''}');
    } else {
      _toast(firstError ?? '保存失败，请稍后重试');
    }
  }

  // 批量删除选中的作品：先弹确认，服务端删记录连磁盘文件一起清，
  // 回来把本地列表同步摘掉；正打开看的那张若被删，结果卡一并清掉。
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _batchBusy) return;
    final targets = _artworks.where((a) => _selectedIds.contains(a.id)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除作品', style: TextStyle(fontSize: FeaturePageStyle.t(16), fontWeight: FontWeight.w700)),
        content: Text(
          '确定删除选中的 ${targets.length} 张作品吗？删除后无法恢复。',
          style: TextStyle(fontSize: FeaturePageStyle.t(14), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('取消', style: TextStyle(fontSize: FeaturePageStyle.t(14))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: AppColors.priceRed, fontWeight: FontWeight.w600, fontSize: FeaturePageStyle.t(14)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _batchBusy = true);
    try {
      final deleted = await _service.deleteArtworks(targets.map((a) => a.id).toList());
      if (!mounted) return;
      final ids = targets.map((a) => a.id).toSet();
      setState(() {
        _artworks = _artworks.where((a) => !ids.contains(a.id)).toList();
        if (_currentArtwork != null && ids.contains(_currentArtwork!.id)) {
          _currentArtwork = null;
        }
        _selectedIds.clear();
        _selecting = false;
        _batchBusy = false;
      });
      if (deleted != targets.length) {
        // 服务端实际删掉的张数对不上（比如作品已被别处处理过），重拉一遍列表对齐。
        unawaited(_reloadArtworks());
      }
      _toast('已删除 $deleted 张作品');
    } catch (error) {
      if (!mounted) return;
      setState(() => _batchBusy = false);
      _toast(_formatLoadError(error));
    }
  }

  Future<void> _reloadArtworks() async {
    try {
      final rows = await _service.fetchArtworks();
      if (!mounted) return;
      setState(() => _artworks = rows);
    } catch (_) {
      // 对齐失败不打扰用户：列表下次进页面时会重新拉。
    }
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
                    AppIconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: FeaturePageStyle.iconSize),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI绘画', style: FeaturePageStyle.pageTitle()),
                          Text(
                            _quota == null ? '通义万相 · 文生图' : '今日剩余 ${_quota!.remainingToday}/${_quota!.dailyLimit} 张',
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
                          SizedBox(height: FeaturePageStyle.s(14)),
                          _RatioSection(
                            selectedKey: _ratioKey,
                            onSelected: (key) => setState(() => _ratioKey = key),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text('我的作品', style: FeaturePageStyle.sectionTitle()),
                                ),
                                TextButton(
                                  onPressed: _toggleSelecting,
                                  child: Text(
                                    _selecting ? '取消' : '多选',
                                    style: FeaturePageStyle.action(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: FeaturePageStyle.s(12)),
                            _ArtworkGrid(
                              artworks: _artworks,
                              selecting: _selecting,
                              selectedIds: _selectedIds,
                              onTap: (artwork) {
                                if (_selecting) {
                                  _toggleSelected(artwork);
                                  return;
                                }
                                setState(() => _currentArtwork = artwork);
                                _openPreview(artwork);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            if (_selecting)
              _SelectionBar(
                count: _selectedIds.length,
                busy: _batchBusy,
                onDownload: _downloadSelected,
                onDelete: _deleteSelected,
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
              '描述你想画的画面，选好风格与画幅，一次生成一张图。',
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
    return AppTextField(
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

class _RatioSection extends StatelessWidget {
  const _RatioSection({required this.selectedKey, required this.onSelected});

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('画幅', style: FeaturePageStyle.sectionTitle()),
        SizedBox(height: FeaturePageStyle.s(10)),
        Wrap(
          spacing: FeaturePageStyle.s(8),
          runSpacing: FeaturePageStyle.s(8),
          children: aiRatioPresets.map((preset) {
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
    return AppFilledButton(
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
          AppGestureDetector(
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
                // 三个按钮等宽平分：「保存到本地」是 5 个字，窄屏下会折成两行，
                // 标签一律套 FittedBox 等比缩小兜底，宁可字小一点也不换行。
                Row(
                  children: [
                    Expanded(
                      child: AppOutlinedButton(
                        onPressed: onPreview,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('查看大图', softWrap: false, style: FeaturePageStyle.action()),
                        ),
                      ),
                    ),
                    SizedBox(width: FeaturePageStyle.s(8)),
                    Expanded(
                      child: AppFilledButton(
                        onPressed: onRegenerate,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('再次生成', softWrap: false, style: FeaturePageStyle.action(color: Colors.white)),
                        ),
                      ),
                    ),
                    SizedBox(width: FeaturePageStyle.s(8)),
                    Expanded(
                      child: AppOutlinedButton(
                        onPressed: onSave,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('保存到本地', softWrap: false, style: FeaturePageStyle.action()),
                        ),
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

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.onDownload,
    required this.onDelete,
  });

  final int count;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        FeaturePageStyle.s(16),
        FeaturePageStyle.s(10),
        FeaturePageStyle.s(16),
        FeaturePageStyle.s(10) + bottomPadding,
      ),
      child: Row(
        children: [
          Text('已选 $count 张', style: FeaturePageStyle.bodyBold()),
          const Spacer(),
          AppOutlinedButton(
            onPressed: busy || count == 0 ? null : onDownload,
            child: Text('下载', style: FeaturePageStyle.action()),
          ),
          SizedBox(width: FeaturePageStyle.s(10)),
          AppFilledButton(
            onPressed: busy || count == 0 ? null : onDelete,
            style: FilledButton.styleFrom(backgroundColor: AppColors.priceRed),
            child: Text(busy ? '处理中…' : '删除', style: FeaturePageStyle.action(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({
    required this.artworks,
    required this.selecting,
    required this.selectedIds,
    required this.onTap,
  });

  final List<AiArtwork> artworks;
  final bool selecting;
  final Set<String> selectedIds;
  final ValueChanged<AiArtwork> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // 坑：GridView 不写 padding 时会自动拿状态栏高度当顶部留白，
      // 本网格又嵌在整页滚动里，作品区上方会多出一条空带，必须显式归零。
      padding: EdgeInsets.zero,
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
        final selected = selecting && selectedIds.contains(artwork.id);
        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
          clipBehavior: Clip.antiAlias,
          child: AppInkWell(
            onTap: () => onTap(artwork),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ArtworkImage(imagePath: artwork.imagePath),
                if (selected)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
                    ),
                  ),
                if (selecting)
                  Positioned(
                    right: FeaturePageStyle.s(6),
                    top: FeaturePageStyle.s(6),
                    child: Container(
                      width: FeaturePageStyle.s(22),
                      height: FeaturePageStyle.s(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primary : Colors.black.withValues(alpha: 0.35),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: FeaturePageStyle.s(14), color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
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
        return Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              url: snapshot.data!,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: AppColors.muted,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: AppColors.mutedForeground, size: FeaturePageStyle.s(28)),
              ),
            ),
            const Positioned(
              left: 8,
              top: 8,
              child: AiGeneratedBadge(compact: true),
            ),
          ],
        );
      },
    );
  }
}
