import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../services/review_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/feature_page_scaffold.dart';
import 'image_preview_page.dart';

class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  final String orderId;
  final String productId;
  final String productName;

  static void open(
    BuildContext context, {
    required String orderId,
    required String productId,
    required String productName,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderReviewPage(
          orderId: orderId,
          productId: productId,
          productName: productName,
        ),
      ),
    );
  }

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  final _contentController = TextEditingController();
  final _api = ReviewApiService();
  int _rating = 5;
  bool _submitting = false;
  final List<_LocalImage> _images = [];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 6) {
      showTopSnackBar(
        context,
        content: Text('最多上传 6 张图片', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
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

    setState(() => _images.add(_LocalImage(bytes: bytes, mimeType: mimeType)));
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.length < 2) {
      showTopSnackBar(
        context,
        content: Text('评价内容至少 2 个字', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final imagePaths = <String>[];
      for (final img in _images) {
        final path = await _api.uploadImage(img.bytes, img.mimeType);
        imagePaths.add(path);
      }

      await _api.submitReview(
        orderId: widget.orderId,
        productId: widget.productId,
        content: content,
        rating: _rating,
        imagePaths: imagePaths,
      );

      if (!mounted) return;
      await context.read<OrderProvider>().loadFromRemote();
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text('评价成功', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text('$e', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: '发表评价',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.productName, style: FeaturePageStyle.body()),
          SizedBox(height: AppScale.s(16)),
          Text('评分', style: FeaturePageStyle.caption()),
          SizedBox(height: AppScale.s(8)),
          Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.primary,
                  size: AppScale.s(32),
                ),
              );
            }),
          ),
          SizedBox(height: AppScale.s(12)),
          Text('评价内容', style: FeaturePageStyle.caption()),
          SizedBox(height: AppScale.s(8)),
          TextField(
            controller: _contentController,
            maxLines: 5,
            maxLength: 500,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: '分享你的使用感受吧～',
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
              ),
            ),
          ),
          SizedBox(height: AppScale.s(12)),
          Text('上传图片（可选）', style: FeaturePageStyle.caption()),
          SizedBox(height: AppScale.s(8)),
          Wrap(
            spacing: AppScale.s(8),
            runSpacing: AppScale.s(8),
            children: [
              ..._images.asMap().entries.map((entry) {
                final index = entry.key;
                final img = entry.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImagePreviewPage(child: Image.memory(img.bytes, fit: BoxFit.contain)),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppScale.s(8)),
                        child: Image.memory(
                          img.bytes,
                          width: AppScale.s(72),
                          height: AppScale.s(72),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -AppScale.s(6),
                      right: -AppScale.s(6),
                      child: GestureDetector(
                        onTap: _submitting ? null : () => setState(() => _images.removeAt(index)),
                        child: Container(
                          padding: EdgeInsets.all(AppScale.s(2)),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: Icon(Icons.close, size: AppScale.s(14), color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_images.length < 6)
                GestureDetector(
                  onTap: _submitting ? null : _pickImage,
                  child: Container(
                    width: AppScale.s(72),
                    height: AppScale.s(72),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppScale.s(8)),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.mutedForeground),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppScale.s(24)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: AppScale.s(14)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppScale.s(999))),
              ),
              child: _submitting
                  ? SizedBox(
                      width: AppScale.s(20),
                      height: AppScale.s(20),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('提交评价', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalImage {
  const _LocalImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
