import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../data/product_whispers.dart';
import '../pages/checkout_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/click_effect/app_buttons.dart';
import 'holo_card.dart';

class XiaodouFateBoard extends StatefulWidget {
  const XiaodouFateBoard({
    super.key,
    required this.products,
    required this.roles,
  });

  final List<Product> products;
  final List<String> roles;

  @override
  State<XiaodouFateBoard> createState() => _XiaodouFateBoardState();
}

class _XiaodouFateBoardState extends State<XiaodouFateBoard> {
  final _flipped = <int>{};

  static const _labels = {'fate': '本命', 'encounter': '遇见', 'linger': '余韵'};

  // 角色对应稀有度：本命=鎏金光柱，遇见=银辉蚀刻，余韵=紫虹彩虹
  static const _rarities = {
    'fate': HoloRarity.gold,
    'encounter': HoloRarity.silver,
    'linger': HoloRarity.cosmos,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppScale.s(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.products.length; i++) ...[
            if (i > 0) SizedBox(width: AppScale.s(8)),
            Expanded(
              child: _FateCard(
                product: widget.products[i],
                label:
                    _labels[i < widget.roles.length ? widget.roles[i] : ''] ??
                    '星牌',
                rarity:
                    _rarities[i < widget.roles.length ? widget.roles[i] : ''] ??
                    HoloRarity.gold,
                flipped: _flipped.contains(i),
                onFlip: () => setState(() => _flipped.add(i)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FateCard extends StatelessWidget {
  const _FateCard({
    required this.product,
    required this.label,
    required this.rarity,
    required this.flipped,
    required this.onFlip,
  });

  final Product product;
  final String label;
  final HoloRarity rarity;
  final bool flipped;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppScale.s(220),
      child: HoloCard(
        rarity: rarity,
        flipped: flipped,
        onTap: onFlip,
        // 商品图窗口位置（分数）：光柱只在这个区域里流动
        artWindow: const Rect.fromLTRB(0.06, 0.14, 0.94, 0.47),
        front: _front(context),
        back: _back(),
      ),
    );
  }

  Widget _back() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF251E54), Color(0xFF171238), Color(0xFF110D2A)],
        ),
        borderRadius: BorderRadius.circular(AppScale.s(14)),
        border: Border.all(color: rarity.border, width: 1.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppScale.s(54),
                  height: AppScale.s(54),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.35, -0.35),
                      colors: [
                        Color(0xFFFDFaff),
                        Color(0xFFCDBCF7),
                        Color(0xFF8D76E8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBEA0FF).withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: const Color(0xFF3D2B6B),
                    size: AppScale.s(24),
                  ),
                ),
                SizedBox(height: AppScale.s(10)),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppScale.t(15),
                    letterSpacing: 6,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppScale.s(4)),
                Text(
                  'STARWISH',
                  style: TextStyle(
                    fontSize: AppScale.t(8),
                    letterSpacing: 3,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppScale.s(10),
            child: Text(
              '点 开',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppScale.t(10), color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _front(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2364), Color(0xFF1A1440), Color(0xFF130F30)],
        ),
        borderRadius: BorderRadius.circular(AppScale.s(14)),
        border: Border.all(color: rarity.border, width: 1.5),
      ),
      padding: EdgeInsets.all(AppScale.s(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppScale.s(7),
                vertical: AppScale.s(2),
              ),
              decoration: BoxDecoration(
                color: rarity.glow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppScale.t(10),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221638),
                ),
              ),
            ),
          ),
          SizedBox(height: AppScale.s(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppScale.s(8)),
            child: ProductThumbnail(
              product: product,
              width: double.infinity,
              height: AppScale.s(72),
            ),
          ),
          SizedBox(height: AppScale.s(6)),
          SizedBox(
            height: AppScale.s(28),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(11),
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '¥${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
            style: TextStyle(
              fontSize: AppScale.t(13),
              fontWeight: FontWeight.w800,
              color: rarity.glow,
            ),
          ),
          SizedBox(height: AppScale.s(3)),
          SizedBox(
            height: AppScale.s(26),
            child: Text(
              whisperFor(product.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(10),
                color: Colors.white70,
                height: 1.3,
              ),
            ),
          ),
          const Spacer(),
          AppFilledButton(
            onPressed: () => CheckoutPage.openBuyNow(context, product),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
              minimumSize: Size(0, AppScale.s(28)),
            ),
            child: Text(
              '带走',
              style: TextStyle(
                fontSize: AppScale.t(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
