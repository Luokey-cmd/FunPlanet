import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../data/product_whispers.dart';
import '../pages/checkout_page.dart';
import '../pages/product_detail_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import '../widgets/click_effect/app_buttons.dart';
import 'holo_card.dart';

/// 亮牌牌板（导购全流程拍 4/5）：三张牌翻着入场、明着亮出，
/// 每张牌带一句按真实数据算好的特点；点一张牌先转牌再进详情页——
/// 与开场动画最后一格的动作同一套语言，动画不能骗人。
/// 批次切换由外层（XiaodouFateSection）换 key 重建本组件，
/// 每换一批都会重新翻着入场。
class XiaodouFateBoard extends StatefulWidget {
  const XiaodouFateBoard({
    super.key,
    required this.products,
    required this.roles,
    this.traits = const {},
  });

  final List<Product> products;
  final List<String> roles;

  /// 商品 id -> 特点句（服务端算好）；没有时退回旧的星语小句。
  final Map<String, String> traits;

  @override
  State<XiaodouFateBoard> createState() => _XiaodouFateBoardState();
}

class _XiaodouFateBoardState extends State<XiaodouFateBoard> {
  final _flipped = <int>{};
  final List<Timer> _timers = [];

  static const _labels = {'fate': '本命', 'encounter': '遇见', 'linger': '余韵'};

  // 角色对应稀有度：本命=鎏金光柱，遇见=银辉蚀刻，余韵=紫虹彩虹
  static const _rarities = {
    'fate': HoloRarity.gold,
    'encounter': HoloRarity.silver,
    'linger': HoloRarity.cosmos,
  };

  @override
  void initState() {
    super.initState();
    // 入场动效：三张牌依次翻着亮相（间隔 140ms），对齐转牌改版
    // 「快旋入场」的节奏；定时器在组件销毁时全部取消，别留野回调。
    for (var i = 0; i < widget.products.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 120 + i * 140), () {
          if (mounted) setState(() => _flipped.add(i));
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

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
                trait: widget.traits[widget.products[i].id],
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

class _FateCard extends StatefulWidget {
  const _FateCard({
    required this.product,
    required this.label,
    required this.rarity,
    required this.flipped,
    required this.onFlip,
    this.trait,
  });

  final Product product;
  final String label;
  final HoloRarity rarity;
  final bool flipped;
  final VoidCallback onFlip;
  final String? trait;

  @override
  State<_FateCard> createState() => _FateCardState();
}

class _FateCardState extends State<_FateCard> with SingleTickerProviderStateMixin {
  // 转牌：点中已亮出的牌，先 0.35 秒转到侧面（微微放大），再进详情页；
  // 节奏对齐转牌改版 v2 的「约 0.6 秒快旋」前半段，详情页接住后半段。
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _turning = false;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _turnAndOpen() async {
    if (_turning) return;
    _turning = true;
    await _turn.forward();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: widget.product)),
    );
    if (mounted) {
      _turn.reset();
      _turning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, child) {
        final angle = _turn.value * math.pi * 0.5;
        final scale = 1 + 0.05 * math.sin(_turn.value * math.pi);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle)
            ..scaleByDouble(scale, scale, scale, 1),
          child: child,
        );
      },
      child: SizedBox(
        height: AppScale.s(220),
        child: HoloCard(
          rarity: widget.rarity,
          flipped: widget.flipped,
          // 还没翻开（入场动画没轮到）时点它 = 提前翻开；
          // 已亮出时点它 = 转牌进详情。
          onTap: widget.flipped ? _turnAndOpen : widget.onFlip,
          // 商品图窗口位置（分数）：光柱只在这个区域里流动
          artWindow: const Rect.fromLTRB(0.05, 0.03, 0.95, 0.40),
          front: _front(context),
          back: _back(),
        ),
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
        border: Border.all(color: widget.rarity.border, width: 1.5),
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
                  widget.label,
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
        border: Border.all(color: widget.rarity.border, width: 1.5),
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
                      color: widget.rarity.glow,
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
                      widget.label,
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
              widget.product.name,
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
              // 特点句优先：服务端按真实数据算好的那句（口碑最好/价格最低…）；
              // 老消息没有特点句时退回原来的星语小句。
              (widget.trait != null && widget.trait!.isNotEmpty)
                  ? widget.trait!
                  : whisperFor(widget.product.id),
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
                  '¥${widget.product.price.toStringAsFixed(widget.product.price.truncateToDouble() == widget.product.price ? 0 : 2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppScale.t(13),
                    fontWeight: FontWeight.w800,
                    color: widget.rarity.glow,
                  ),
                ),
              ),
              AppFilledButton(
                onPressed: () => CheckoutPage.openBuyNow(context, widget.product),
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
    final product = widget.product;
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
