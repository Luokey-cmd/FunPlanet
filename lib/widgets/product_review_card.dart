import 'package:flutter/material.dart';

import '../services/review_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import '../widgets/user_avatar_image.dart';
import '../pages/image_preview_page.dart';

class ProductReviewCard extends StatelessWidget {
  const ProductReviewCard({super.key, required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarImage(
                path: review.userAvatarPath,
                width: AppScale.s(32),
                height: AppScale.s(32),
                borderRadius: BorderRadius.circular(AppScale.s(16)),
              ),
              SizedBox(width: AppScale.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userNickname, style: TextStyle(fontSize: AppScale.s(13), fontWeight: FontWeight.w600)),
                    Text(review.createdAt, style: TextStyle(fontSize: AppScale.s(11), color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: AppScale.s(14),
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(8)),
          Text(review.content, style: TextStyle(fontSize: AppScale.s(13), color: AppColors.foreground, height: 1.5)),
          if (review.imagePaths.isNotEmpty) ...[
            SizedBox(height: AppScale.s(8)),
            Wrap(
              spacing: AppScale.s(6),
              runSpacing: AppScale.s(6),
              children: review.imagePaths.map((path) => ProductReviewImage(path: path)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class ProductReviewImage extends StatelessWidget {
  const ProductReviewImage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: AppScale.s(72),
            height: AppScale.s(72),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final url = snapshot.data!;
        return GestureDetector(
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ImagePreviewPage(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppScale.s(8)),
            child: Image.network(
              url,
              width: AppScale.s(72),
              height: AppScale.s(72),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: AppScale.s(72),
                height: AppScale.s(72),
                color: AppColors.muted,
              ),
            ),
          ),
        );
      },
    );
  }
}
