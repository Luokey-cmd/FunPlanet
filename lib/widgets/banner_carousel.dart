import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/product_catalog_provider.dart';
import '../pages/product_detail_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'product_thumbnail.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    this.padding,
    this.scale = 1.0,
  });

  final EdgeInsets? padding;
  final double scale;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _current = 0;
  Timer? _autoPlayTimer;
  late PageController _pageController;

  static const _slideDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (appBanners.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 3), (_) => _animateTo((_current + 1) % appBanners.length));
  }

  void _animateTo(int index) {
    if (!mounted || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: _slideDuration,
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    _startAutoPlay();
  }

  void _goTo(int index) {
    _animateTo(index);
    _startAutoPlay();
  }

  void _prev() {
    final length = appBanners.length;
    if (length <= 1) return;
    _animateTo((_current - 1 + length) % length);
    _startAutoPlay();
  }

  void _next() {
    final length = appBanners.length;
    if (length <= 1) return;
    _animateTo((_current + 1) % length);
    _startAutoPlay();
  }

  void _openBannerProduct(BuildContext context, String productId) {
    final product = productById(productId);
    if (product == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProductCatalogProvider>();
    final items = appBanners;
    if (items.isEmpty) return const SizedBox.shrink();

    if (_current >= items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _current = 0);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }

    final scale = widget.scale;
    double s(double value) => AppScale.s(value * scale);
    final pad = widget.padding ?? EdgeInsets.symmetric(horizontal: s(16));
    final radius = BorderRadius.circular(s(20));
    final index = _current.clamp(0, items.length - 1);

    return Padding(
      padding: pad,
      child: AspectRatio(
        aspectRatio: bannerAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      onTap: () => _openBannerProduct(context, items[idx].productId),
                      child: BannerVisual(
                        banner: items[idx],
                        scale: scale,
                      ),
                    );
                  },
                ),
                if (items.length > 1) ...[
                  Positioned(
                    left: s(8),
                    top: 0,
                    bottom: 0,
                    child: Center(child: _NavButton(icon: Icons.chevron_left, onTap: _prev, scale: scale)),
                  ),
                  Positioned(
                    right: s(8),
                    top: 0,
                    bottom: 0,
                    child: Center(child: _NavButton(icon: Icons.chevron_right, onTap: _next, scale: scale)),
                  ),
                  Positioned(
                    bottom: s(12),
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(items.length, (idx) {
                        final active = idx == index;
                        return GestureDetector(
                          onTap: () => _goTo(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: s(3)),
                            width: active ? s(16) : s(6),
                            height: s(6),
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(s(999)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap, this.scale = 1.0});

  final IconData icon;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => AppScale.s(value * scale);
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: s(30),
          height: s(30),
          child: Icon(icon, color: Colors.white, size: s(18)),
        ),
      ),
    );
  }
}
