import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/save_artwork_image.dart';
import '../utils/snackbar_utils.dart';

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.closeIconColor,
    this.saveImagePath,
  });

  final Widget child;
  final Color backgroundColor;
  final Color? closeIconColor;
  final String? saveImagePath;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: child,
            ),
          ),
          Positioned(
            top: top + AppScale.s(8),
            left: AppScale.s(4),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: closeIconColor ?? AppColors.foreground, size: AppScale.s(24)),
            ),
          ),
          if (saveImagePath != null && saveImagePath!.isNotEmpty)
            Positioned(
              top: top + AppScale.s(8),
              right: AppScale.s(4),
              child: _SaveImageButton(imagePath: saveImagePath!),
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
        content: Text('已保存到相册', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is SaveArtworkImageException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
      child: InkWell(
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
                style: TextStyle(color: Colors.white, fontSize: AppScale.s(13), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
