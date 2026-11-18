import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../data/product_whispers.dart';
import '../pages/checkout_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import '../widgets/click_effect/app_buttons.dart';
import 'holo_card.dart';

class XiaodouFateBoard extends StatefulWidget {
  const XiaodouFateBoard({
    super.key,
    required this.products,
    required this.roles,
    this.flipped,
    this.onFlip,
  });

  final List<Product> products;
  final List<String> roles;

  /// 可选的受控翻牌状态：外部传入时由外部决定哪些牌已翻开
  /// （今日星签半屏层的「翻开这张牌」按钮用）；不传则维持原行为，
  /// 由牌板自己记状态（小豆聊天里的用法不变）。
  final Set<int>? flipped;
  final ValueChanged<int>? onFlip;

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
                flipped: (widget.flipped ?? _flipped).contains(i),
                onFlip: () {
                  if (widget.onFlip != null) {
                    widget.onFlip!(i);
                  } else {
                    setState(() => _flipped.add(i));
                  }
                },
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
        artWindow: const Rect.fromLTRB(0.05, 0.03, 0.95, 0.40),
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
      padding: EdgeInsets.all(AppScale.s(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图窗吃掉全部剩余高度：文字行按真实字号（t(v)=0.8v+5）算死，
          // 图窗弹性伸缩，所以任何字号下都不会再溢出。
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppScale.s(8)),
                    child: _artwork(),
                  ),
                ),
                Positioned(
                  left: AppScale.s(5),
                  top: AppScale.s(5),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppScale.s(7),
                      vertical: AppScale.s(2),
                    ),
                    decoration: BoxDecoration(
                      color: rarity.glow,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
              ],
            ),
          ),
          SizedBox(height: AppScale.s(5)),
          SizedBox(
            height: AppScale.s(44),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(11),
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: AppScale.s(2)),
          SizedBox(
            height: AppScale.s(40),
            child: Text(
              whisperFor(product.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(9.5),
                color: Colors.white70,
                height: 1.25,
              ),
            ),
          ),
          SizedBox(height: AppScale.s(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '¥${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppScale.t(13),
                    fontWeight: FontWeight.w800,
                    color: rarity.glow,
                  ),
                ),
              ),
              AppFilledButton(
                onPressed: () => CheckoutPage.openBuyNow(context, product),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12)),
                  minimumSize: Size(AppScale.s(52), AppScale.s(30)),
                  // 安卓默认给按钮留 48 的最小点击高（与设定的高度无关），
                  // 不关掉这一行就会比预算多占 24，光窗位置也会跟着错位。
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        ],
      ),
    );
  }

  // 图窗内容：深紫底打底，商品图裁剪填满（cover），不再露白板；
  // 无图商品用商品色块 + 图标兜底。
  Widget _artwork() {
    if (product.imagePath.isEmpty) {
      final bg = product.imageColor ?? AppColors.secondary;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Color.lerp(bg, AppColors.primaryLight, 0.3)!],
          ),
        ),
        child: product.imageIcon == null
            ? null
            : Center(
                child: Icon(
                  product.imageIcon,
                  size: AppScale.s(30),
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
      );
    }
    return Container(
      color: const Color(0xFF241B4D),
      child: LayoutBuilder(
        builder: (context, c) => ProductImage(
          image: product.imagePath,
          width: c.maxWidth,
          height: c.maxHeight,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
