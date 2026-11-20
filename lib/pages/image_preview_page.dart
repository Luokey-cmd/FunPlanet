import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import '../utils/save_artwork_image.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_network_image.dart';
import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_pressable.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    this.child,
    this.imageUrls = const [],
    this.initialIndex = 0,
    this.backgroundColor = Colors.white,
    this.closeIconColor,
    this.saveImagePath,
  }) : assert(child != null || imageUrls.length > 0, 'child 与 imageUrls 至少提供一个');

  final Widget? child;
  final List<String> imageUrls;
  final int initialIndex;
  final Color backgroundColor;
  final Color? closeIconColor;
  final String? saveImagePath;

  static Future<void> openNetwork(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    String? saveImagePath,
    Color backgroundColor = Colors.black,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          imageUrls: urls,
          initialIndex: initialIndex,
          saveImagePath: saveImagePath,
          backgroundColor: backgroundColor,
          closeIconColor: Colors.white,
        ),
      ),
    );
  }

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? get _currentSavePath {
    if (widget.saveImagePath != null && widget.saveImagePath!.isNotEmpty) {
      return widget.saveImagePath;
    }
    if (widget.imageUrls.isEmpty) return null;
    return widget.imageUrls[_index];
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final multi = widget.imageUrls.length > 1;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Stack(
        children: [
          if (widget.child != null)
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: widget.child!,
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final raw = widget.imageUrls[i];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: FutureBuilder<String>(
                      future: resolveRemoteMediaUrl(raw),
                      builder: (context, snapshot) {
                        final url = snapshot.data;
                        if (url == null || url.isEmpty) {
                          return const CircularProgressIndicator(color: Colors.white, strokeWidth: 2);
                        }
                        return AppNetworkImage(url: url, fit: BoxFit.contain);
                      },
                    ),
                  ),
                );
              },
            ),
          Positioned(
            top: top + AppScale.s(8),
            left: AppScale.s(4),
            child: AppIconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: widget.closeIconColor ?? AppColors.foreground, size: AppScale.s(24)),
            ),
          ),
          if (_currentSavePath != null && _currentSavePath!.isNotEmpty)
            Positioned(
              top: top + AppScale.s(8),
              right: AppScale.s(8),
              child: _SaveImageButton(imagePath: _currentSavePath!),
            ),
          if (multi)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + AppScale.s(20),
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppScale.s(999)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                    child: Text(
                      '${_index + 1}/${widget.imageUrls.length}',
                      style: TextStyle(color: Colors.white, fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaveImageButton extends StatefulWidget {
  const _SaveImageButton({required this.imagePath});

  final String imagePath;

  @override
  State<_SaveImageButton> createState() => _SaveImageButtonState();
}

class _SaveImageButtonState extends State<_SaveImageButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await saveArtworkImageToGallery(widget.imagePath);
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text('已保存到相册', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is SaveArtworkImageException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppScale.s(20)),
      child: AppInkWell(
        onTap: _saving ? null : _save,
        borderRadius: BorderRadius.circular(AppScale.s(20)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saving)
                SizedBox(
                  width: AppScale.s(16),
                  height: AppScale.s(16),
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(Icons.download_rounded, color: Colors.white, size: AppScale.s(18)),
              SizedBox(width: AppScale.s(4)),
              Text(
                '保存到本地',
                style: TextStyle(color: Colors.white, fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
