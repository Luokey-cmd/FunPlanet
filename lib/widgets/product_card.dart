import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../pages/product_detail_page.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'product_thumbnail.dart';

enum ProductCardLayout { grid, staggered, list, mall }

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.layout = ProductCardLayout.grid,
    this.imageHeight,
    this.scale = 1.0,
  });

  final Product product;
  final ProductCardLayout layout;
  final double? imageHeight;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<UserProvider>().isFavorite(product.id);

    return switch (layout) {
      ProductCardLayout.list => _ListCard(product: product, isFavorite: isFavorite),
      ProductCardLayout.staggered => _StaggeredCard(product: product, imageHeight: imageHeight, scale: scale),
      ProductCardLayout.mall => _MallCard(product: product, scale: scale),
      _ => _GridCard(product: product, isFavorite: isFavorite),
    };
  }
}

void _openDetail(BuildContext context, Product product) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)));
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.product, this.scale = 1.0});

  final Product product;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (product.tag == null) return const SizedBox.shrink();
    final style = tagStyleFromKey(product.tagColor);
    double s(double value) => AppScale.s(value * scale);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s(8), vertical: s(3)),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(s(6)),
      ),
      child: Text(
        product.tag!,
        style: TextStyle(color: style.foreground, fontSize: s(10), fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.product, required this.isFavorite});

  final Product product;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(16)),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(AppScale.s(8), AppScale.s(8), AppScale.s(8), 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppScale.s(12)),
                    child: ProductThumbnail(product: product, height: AppScale.s(112), borderRadius: AppScale.s(12)),
                  ),
                ),
                if (product.tag != null)
                  Positioned(top: AppScale.s(8), left: AppScale.s(8), child: _TagBadge(product: product)),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(AppScale.s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppScale.s(13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  if (product.spec != null) ...[
                    SizedBox(height: AppScale.s(2)),
                    Text(
                      product.spec!,
                      style: TextStyle(fontSize: AppScale.s(11), color: AppColors.mutedForeground),
                    ),
                  ],
                  SizedBox(height: AppScale.s(6)),
                  Text(
                    '¥ ${product.price.toStringAsFixed(product.price == product.price.roundToDouble() ? 0 : 2)}',
                    style: TextStyle(
                      fontSize: AppScale.s(14),
                      fontWeight: FontWeight.bold,
                      color: AppColors.priceRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredCard extends StatelessWidget {
  const _StaggeredCard({required this.product, this.imageHeight, this.scale = 1.0});

  final Product product;
  final double? imageHeight;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => AppScale.s(value * scale);
    final h = imageHeight ?? s(140);
    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(s(16)),
          boxShadow: AppColors.cardShadow,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(s(8), s(8), s(8), 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(s(12)),
                    child: ProductThumbnail(product: product, height: h - s(8), borderRadius: s(12)),
                  ),
                ),
                if (product.tag != null)
                  Positioned(top: s(8), left: s(8), child: _TagBadge(product: product, scale: scale)),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: s(12),
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: s(4)),
                  Text(
                    '¥ ${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: s(14),
                      fontWeight: FontWeight.bold,
                      color: AppColors.priceRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MallCard extends StatelessWidget {
  const _MallCard({required this.product, this.scale = 1.0});

  final Product product;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => AppScale.s(value * scale);
    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(s(16)),
            boxShadow: AppColors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(s(8), s(8), s(8), 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(s(12)),
                      child: ProductThumbnail(product: product, height: s(122), borderRadius: s(12)),
                    ),
                  ),
                  if (product.tag != null)
                    Positioned(top: s(8), left: s(8), child: _TagBadge(product: product, scale: scale)),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(s(8), s(8), s(8), s(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: s(12),
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (product.spec != null) ...[
                      SizedBox(height: s(2)),
                      Text(
                        product.subCategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: s(10), color: AppColors.mutedForeground),
                      ),
                    ],
                    SizedBox(height: s(6)),
                    Text(
                      '¥ ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.bold,
                        color: AppColors.priceRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.product, required this.isFavorite});

  final Product product;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
        padding: EdgeInsets.all(AppScale.s(12)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(16)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ProductThumbnail(
                  product: product,
                  width: AppScale.s(80),
                  height: AppScale.s(80),
                ),
                if (product.tag != null)
                  Positioned(top: AppScale.s(4), left: AppScale.s(4), child: _TagBadge(product: product)),
              ],
            ),
            SizedBox(width: AppScale.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                  SizedBox(height: AppScale.s(4)),
                  Text(
                    product.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground),
                  ),
                  SizedBox(height: AppScale.s(8)),
                  Text(
                    '¥ ${product.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: AppScale.s(16), fontWeight: FontWeight.bold, color: AppColors.priceRed),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
