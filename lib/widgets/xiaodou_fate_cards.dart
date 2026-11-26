import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../pages/checkout_page.dart';
import '../pages/product_detail_page.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_image.dart';

/// 亮牌牌板（2026-11-26 改版 v4，hx 看真机录屏后定的形态）：
/// 三张竖版小卡并排（极简，只有商品图 + 名字）这一步不变；点中一张后的变身
/// **搬到全屏顶层**演（v3 在聊天框里转，被气泡宽高框住、还裁边，hx 点名不行）：
/// 1. 卡从小卡脸起转：整圈旋转 + 放大，转到背面时是专门的**牌背美术图**
///    （fate_card_back.webp：照开场动画翻牌那一帧做的——深紫星空、金雕花框、
///    月牙四角、中央发光星座椭圆、金翅膀放射光；v3 没有牌背、转过去是正面的
///    镜像，hx 点名不满意），一圈落回正面时已换成幻想大卡（金翅膀美术图 +
///    商品圆徽章），停约 0.95 秒；
/// 2. 再半转落成奶油底**详细卡**（价格/评分/特点/双按钮的静态版）；
/// 3. 停住等用户点任意处（点卡上、点卡外都算）才关掉全屏层，详细卡落回
///    聊天消息里变可点正式版，下方有「回到三张牌」可以重选。
/// 系统返回键在落定前 = 取消回三张牌，落定后 = 同点按落回聊天。
/// 批次切换由外层（XiaodouFateSection）换 key 重建本组件，状态自然清零。
class XiaodouFateBoard extends StatefulWidget {
  const XiaodouFateBoard({
    super.key,
    required this.products,
    this.traits = const {},
  });

  final List<Product> products;

  /// 商品 id -> 特点句（服务端按真实数据算死，如「卖得最火，已售 1200 件」）。
  final Map<String, String> traits;

  @override
  State<XiaodouFateBoard> createState() => _XiaodouFateBoardState();
}

/// 变身阶段：idle 三张小卡 / spin1 转成幻想卡 / hold 幻想卡停留 /
/// spin2 转成详细卡 / detail 详细卡落定。
enum _Phase { idle, detail }

class _XiaodouFateBoardState extends State<XiaodouFateBoard> {
  _Phase _phase = _Phase.idle;
  int _selected = -1;

  Product get _selectedProduct => widget.products[_selected];

  /// 点选小卡：把变身交给全屏层（_FateFlipOverlay）演，演完落定才回 true。
  /// 输入是点中的下标；输出无（结果体现在 _phase 上）。
  /// 坑：全屏层是 rootNavigator 上的独立路由，本组件在它底下一直活着，
  /// 回来后 setState 前仍要查 mounted（用户可能在层开着时退出聊天页）。
  Future<void> _select(int index) async {
    if (_phase != _Phase.idle) return;
    _selected = index;
    final product = widget.products[index];
    final settled = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => _FateFlipOverlay(
          product: product,
          trait: widget.traits[product.id],
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted) return;
    if (settled == true) {
      setState(() => _phase = _Phase.detail);
    }
  }

  /// 回到三张牌重选。
  void _reset() {
    setState(() {
      _phase = _Phase.idle;
      _selected = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppScale.s(12)),
      child: _phase == _Phase.detail
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailCard(
                  product: _selectedProduct,
                  trait: widget.traits[_selectedProduct.id],
                ),
                SizedBox(height: AppScale.s(10)),
                Center(
                  child: GestureDetector(
                    onTap: _reset,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppScale.s(10),
                        vertical: AppScale.s(4),
                      ),
                      child: Text(
                        '↩ 回到三张牌',
                        style: TextStyle(
                          fontSize: AppScale.t(12),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final gap = AppScale.s(10);
                final miniW = (w - gap * 2) / 3;
                final miniH = miniW * 1.46;
                // 顶部多留 s(9)：小卡的判断标签缎带半挂在卡沿外，
                // 不留这段会被上一层内容压住。
                return SizedBox(
                  height: miniH + AppScale.s(9),
                  child: Padding(
                    padding: EdgeInsets.only(top: AppScale.s(9)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < widget.products.length; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          _FadeIn(
                            delay: Duration(milliseconds: i * 70),
                            child: _MiniCard(
                              product: widget.products[i],
                              trait: widget.traits[widget.products[i].id],
                              width: miniW,
                              height: miniH,
                              onTap: () => _select(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 全屏翻牌层（v4 新增）：在 rootNavigator 顶层演完整套变身，不受聊天框约束。
/// 时序：spin1 整圈（小卡脸 → 牌背 → 幻想脸）1000ms → 幻想卡停 0.95s →
/// spin2 半转落成详细卡 880ms → 落定等点按（点任意处 pop 回 true）。
/// 输入：商品与特点句；输出：路由返回值 bool（true = 落回聊天变详细卡，
/// false = 取消回三张牌）。返回键：落定前取消、落定后等同点按落定。
class _FateFlipOverlay extends StatefulWidget {
  const _FateFlipOverlay({required this.product, this.trait});

  final Product product;
  final String? trait;

  @override
  State<_FateFlipOverlay> createState() => _FateFlipOverlayState();
}

enum _FlipPhase { spin1, hold, spin2, landed }

class _FateFlipOverlayState extends State<_FateFlipOverlay>
    with TickerProviderStateMixin {
  /// 幻想卡 / 牌背美术图的宽高比（768×1376），全屏舞台尺寸按它算。
  static const double _cardAspect = 768 / 1376;

  late final AnimationController _spin1 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final AnimationController _spin2 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 880),
  );

  _FlipPhase _phase = _FlipPhase.spin1;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _spin1.dispose();
    _spin2.dispose();
    super.dispose();
  }

  /// 变身主链：转幻想卡 → 停留 → 转详细卡落定。
  /// 坑：层被返回键关掉时控制器 future 抛 TickerCanceled，吞掉静默收尾。
  Future<void> _run() async {
    try {
      await _spin1.forward();
      if (!mounted) return;
      setState(() => _phase = _FlipPhase.hold);
      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted || _phase != _FlipPhase.hold) return;
      await _startSpin2();
    } on TickerCanceled {
      // 层已关闭，静默收尾。
    }
  }

  Future<void> _startSpin2() async {
    setState(() => _phase = _FlipPhase.spin2);
    await _spin2.forward();
    if (!mounted) return;
    setState(() => _phase = _FlipPhase.landed);
  }

  /// 点按：落定后 = 关层落回聊天；幻想卡停留时点按 = 跳过等待直接翻详细卡；
  /// 旋转途中不响应（防连点把时序点乱）。
  void _onTap() {
    if (_phase == _FlipPhase.landed) {
      Navigator.of(context).pop(true);
    } else if (_phase == _FlipPhase.hold) {
      _startSpin2();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardW = math.min(size.width * 0.62, AppScale.s(250));
    final cardH = cardW / _cardAspect;
    final detailW = math.min(size.width * 0.92, AppScale.s(520));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 返回键：落定后同点按（落回聊天），没落定 = 取消回三张牌。
        Navigator.of(context).pop(_phase == _FlipPhase.landed);
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Container(
            // 深紫星空底：盖住整个屏幕（含状态栏与输入框），翻牌只在这块舞台上演。
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 1.1,
                colors: [Color(0xF22E1158), Color(0xF7150529), Color(0xFA0D0218)],
                stops: [0, 0.55, 1],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // 卡背后的光晕：跟着卡一起居中，衬托放射光感。
                  Center(
                    child: Container(
                      width: cardW * 1.9,
                      height: cardH * 1.15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFB78CFF).withValues(alpha: 0.30),
                            const Color(0xFFB78CFF).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_spin1, _spin2]),
                      builder: (context, _) => _stageCard(cardW, cardH, detailW),
                    ),
                  ),
                  if (_phase == _FlipPhase.landed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppScale.s(46),
                      child: Center(
                        child: Text(
                          '点任意处回到聊天',
                          style: TextStyle(
                            fontSize: AppScale.t(12.5),
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 当前帧的牌面：按阶段与动画进度算（角度、缩放、哪张脸）。
  /// 换脸点都卡在牌面侧对观众（90°，只剩一条线）或背对观众的时刻，观众看不见切换：
  /// spin1 前半正面是小卡脸、背对时是牌背、后半正面换成幻想脸；
  /// 牌背要多转半圈（π）抵消镜像，不然星座图是反的。
  Widget _stageCard(double cardW, double cardH, double detailW) {
    final product = widget.product;
    switch (_phase) {
      case _FlipPhase.spin1:
        final v = Curves.easeInOut.transform(_spin1.value);
        final angle = v * math.pi * 2;
        final scale = 0.5 + 0.5 * Curves.easeOut.transform(_spin1.value);
        final cos = math.cos(angle);
        if (cos >= 0) {
          // 正对观众：前段是小卡脸，后段（背对过一轮后）是幻想脸。
          final face = angle < math.pi * 1.5
              ? _MiniFace(product: product, trait: widget.trait, width: cardW, height: cardH)
              : _FantasyFace(product: product, width: cardW, height: cardH);
          return _rotated(angle, scale, face);
        }
        // 背对观众：牌背美术图，先自转 π 抵消镜像再跟主旋转。
        return _rotated(
          angle,
          scale,
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: _BackFace(width: cardW, height: cardH),
          ),
        );
      case _FlipPhase.hold:
        return _FantasyFace(product: product, width: cardW, height: cardH);
      case _FlipPhase.spin2:
        final v = _spin2.value;
        if (v < 0.5) {
          // 前半：幻想卡加速转到侧面。
          final angle = Curves.easeIn.transform(v * 2) * math.pi / 2;
          return _rotated(angle, 1, _FantasyFace(product: product, width: cardW, height: cardH));
        }
        // 后半：详细卡从侧面转回正面（静态版，落定后聊天里换可点版）。
        final t = Curves.easeOut.transform((v - 0.5) * 2);
        return _rotated(
          -math.pi / 2 * (1 - t),
          0.94 + 0.06 * t,
          SizedBox(
            width: detailW,
            child: _DetailCard(product: product, trait: widget.trait, interactive: false),
          ),
        );
      case _FlipPhase.landed:
        return SizedBox(
          width: detailW,
          child: _DetailCard(product: product, trait: widget.trait, interactive: false),
        );
    }
  }

  /// 给牌面套 Y 轴旋转 + 缩放：带透视（setEntry 3,2），转起来才有立体感。
  Widget _rotated(double angle, double scale, Widget child) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle)
        ..scaleByDouble(scale, scale, scale, 1),
      child: child,
    );
  }
}

/// 牌背（v4 新增）：照开场动画翻牌帧做的美术图——深紫星空牌背、金雕花框、
/// 月牙四角、中央发光星座椭圆，背后一对金翅膀。
/// 坑：美术图本身**没有背景**（透明底，hx 23:33 定稿：不要紫云、不要放射光、
/// 连纯色底都不要，只要翅膀 + 卡片 + 小星星），所以这里绝不能套圆角裁剪或
/// 矩形阴影——那会把透明区框出一块假底色；整图按原画幅 contain 摆正即可，
/// 透明处直接透出全屏层的深紫舞台底。
class _BackFace extends StatelessWidget {
  const _BackFace({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset('assets/images/fate_card_back.webp', fit: BoxFit.contain),
    );
  }
}

/// 入场淡入（不是翻牌）：透明度 0→1 + 上移 6px 收住，200ms。
/// 只做防硬闪的抛光，小卡从第一帧就是明牌。
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = Curves.easeOut.transform(_ctrl.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// 商品图（含无图兜底）：有图按 fit 填，没有图用商品色块 + 图标。
/// 小卡、变身脸、幻想卡、详细卡四处共用，兜底口径保持一致。
Widget _productArt(Product product, {required BoxFit fit}) {
  if (product.imagePath.isEmpty) {
    final base = product.imageColor ?? AppColors.secondary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.lerp(base, AppColors.primaryLight, 0.3) ?? AppColors.primaryLight,
          ],
        ),
      ),
      child: product.imageIcon == null
          ? null
          : Center(
              child: Icon(
                product.imageIcon,
                size: AppScale.s(34),
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
    );
  }
  return ProductImage(image: product.imagePath, fit: fit);
}

/// 第一阶段的小卡：竖版，淡紫牌框 + 内圈细线 + 角上小星，
/// 牌面只有商品图和名字（hx 口径：纯粹展示商品，不堆细节）。
/// 判断标签的短词：服务端特点句格式是「短词，整句」（如「口碑最好，评分 4.8」），
/// 逗号前不超过 5 个字才算短词；没有短词（空特点）就不挂缎带。
/// 与 _DetailCard 的拆分口径保持一致。
String? _traitPill(String? trait) {
  final t = trait;
  if (t == null || t.isEmpty) return null;
  final idx = t.indexOf('，');
  if (idx > 0 && idx <= 5) return t.substring(0, idx);
  return null;
}

/// 卡面顶部中央的判断标签缎带：深紫胶囊 + 金边，半挂在卡沿上。
/// 输入短词与字号（小卡和全屏小卡脸共用，字号不同）；输出胶囊组件。
Widget _traitRibbon(String text, {required double fontSize}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: AppScale.s(8),
      vertical: AppScale.s(2.5),
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6E46C8), Color(0xFF8F66E0)],
      ),
      borderRadius: BorderRadius.circular(AppScale.s(999)),
      border: Border.all(color: const Color(0xFFE9CE8C), width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6E46C8).withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: AppScale.t(fontSize),
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.product,
    this.trait,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Product product;

  /// 服务端算好的特点句；短词部分挂成卡面顶部的判断标签缎带。
  final String? trait;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = _traitPill(trait);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(AppScale.s(6)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0E8FF), Color(0xFFDCCDFB), Color(0xFFC9B2F5)],
          ),
          borderRadius: BorderRadius.circular(AppScale.s(13)),
          border: Border.all(color: const Color(0xFFA887E8), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6E46C8).withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppScale.s(9)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.2),
          ),
          padding: EdgeInsets.all(AppScale.s(4)),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppScale.s(7)),
                  child: SizedBox.expand(
                    child: _productArt(product, fit: BoxFit.cover),
                  ),
                ),
              ),
              SizedBox(height: AppScale.s(4)),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppScale.t(10.5),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4C3673),
                ),
              ),
            ],
          ),
        ),
          ),
          if (pill != null)
            Positioned(
              top: -AppScale.s(9),
              left: 0,
              right: 0,
              child: Center(child: _traitRibbon(pill, fontSize: 9.5)),
            ),
        ],
      ),
    );
  }
}

/// 变身第一转的前半张脸：小卡脸的放大版（与小卡同款式），
/// 转过半圈后换成幻想脸，观众只会觉得同一张牌在变身。
class _MiniFace extends StatelessWidget {
  const _MiniFace({required this.product, this.trait, required this.width, required this.height});

  final Product product;

  /// 与小卡同一条特点句：变身第一张脸继续挂缎带，免得标签凭空消失。
  final String? trait;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pill = _traitPill(trait);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0E8FF), Color(0xFFDCCDFB), Color(0xFFC9B2F5)],
        ),
        borderRadius: BorderRadius.circular(AppScale.s(16)),
        border: Border.all(color: const Color(0xFFA887E8), width: 2),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppScale.s(12)),
              child: SizedBox.expand(child: _productArt(product, fit: BoxFit.cover)),
            ),
          ),
          SizedBox(height: AppScale.s(8)),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppScale.t(13),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4C3673),
            ),
          ),
        ],
      ),
        ),
        if (pill != null)
          Positioned(
            top: -AppScale.s(11),
            left: 0,
            right: 0,
            child: Center(child: _traitRibbon(pill, fontSize: 12)),
          ),
      ],
    );
  }
}

/// 第二阶段的幻想大卡：整张牌面是 AI 生成的美术图（金翅膀 + 雕花金框 + 紫星空），
/// 商品图剪成圆徽章落在正中发光月圆上，底部一条名字牌。
/// 坑：美术图的月圆中心在图高约 46.5% 处、直径约占图宽 47%，
/// 商品圆的位置按这个比例算，换图时要重新量。
class _FantasyFace extends StatelessWidget {
  const _FantasyFace({required this.product, required this.width, required this.height});

  final Product product;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final badge = width * 0.42;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppScale.s(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA06EFF).withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppScale.s(16)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/fate_fantasy_card.webp',
                fit: BoxFit.cover,
              ),
            ),
            // 商品圆徽章：落在月圆正中（图宽 50%、图高 46.5%）。
            Positioned(
              left: (width - badge) / 2,
              top: height * 0.465 - badge / 2,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE9C766), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.55),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipOval(child: _productArt(product, fit: BoxFit.cover)),
              ),
            ),
            // 底部名字牌：深紫半透底 + 金边，和美术图自带的底框呼应。
            Positioned(
              left: 0,
              right: 0,
              bottom: AppScale.s(16),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppScale.s(13),
                    vertical: AppScale.s(4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E0E40).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFE9C766).withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppScale.t(11.5),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: const Color(0xFFFFE9A8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 第三阶段的详细卡：即 v2 宽卡牌面（奶油底、金边、价格缎带、星星、
/// 特点句、规格行、双按钮）。interactive=false 是变身后半段的静态版，
/// 按钮与点选都不响应，落定后由牌板换成可点的正式版。
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.product, this.trait, this.interactive = true});

  final Product product;

  /// 服务端算好的特点句（可空：老消息没有时用商品字段现拼事实行）。
  final String? trait;

  final bool interactive;

  /// 特点句拆分：服务端格式是「短词，整句」（如「口碑最好，评分 4.8」），
  /// 短词进胶囊、整句作事实行；没有逗号的（兜底格式）不挂胶囊、整句照用。
  (String?, String) _splitTrait() {
    final t = trait;
    if (t == null || t.isEmpty) {
      return (null, '已售 ${product.sales} 件 · 评分 ${product.rating.toStringAsFixed(1)}');
    }
    final idx = t.indexOf('，');
    if (idx > 0 && idx <= 5) {
      return (t.substring(0, idx), t);
    }
    return (null, t);
  }

  @override
  Widget build(BuildContext context) {
    final (pill, fact) = _splitTrait();
    final card = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFAF0), Color(0xFFFFF5E2)],
        ),
        borderRadius: BorderRadius.circular(AppScale.s(18)),
        border: Border.all(color: const Color(0xFFD9A94F), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF966E1E).withValues(alpha: 0.13),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.all(AppScale.s(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _framedArtwork(),
                    SizedBox(width: AppScale.s(11)),
                    Expanded(child: _infoColumn(pill, fact)),
                  ],
                ),
                SizedBox(height: AppScale.s(11)),
                _buttons(context),
              ],
            ),
          ),
          // 四角小星饰 + 顶部正中爱心宝石：只点缀边框、不碰牌面内容区。
          for (final align in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: align,
              child: Padding(
                padding: EdgeInsets.all(AppScale.s(4)),
                child: Icon(
                  Icons.auto_awesome,
                  size: AppScale.s(9),
                  color: const Color(0xFFD9A94F),
                ),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -AppScale.s(8)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppScale.s(7),
                  vertical: AppScale.s(1),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD9A94F), width: 1.5),
                ),
                child: Icon(
                  Icons.favorite,
                  size: AppScale.s(10),
                  color: const Color(0xFF8A5FD6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!interactive) {
      return IgnorePointer(child: card);
    }
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 140),
            pageBuilder: (_, _, _) => ProductDetailPage(product: product),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: card,
    );
  }

  // 商品图装进金色画框：有图裁剪填满，无图用商品色块 + 图标兜底。
  Widget _framedArtwork() {
    return Container(
      width: AppScale.s(102),
      height: AppScale.s(102),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: const Color(0xFFE7C87E), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppScale.s(10)),
        child: SizedBox.expand(child: _productArt(product, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _infoColumn(String? pill, String fact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 价格缎带（照动画那张的粉红缎带）：现价粗体 + 原价划线。
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppScale.s(10),
                vertical: AppScale.s(3),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7D9C), Color(0xFFFF5F8F)],
                ),
                borderRadius: BorderRadius.circular(AppScale.s(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _priceText(product.price),
                    style: TextStyle(
                      fontSize: AppScale.t(15),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (product.originalPrice != null &&
                      product.originalPrice! > product.price) ...[
                    SizedBox(width: AppScale.s(4)),
                    Text(
                      _priceText(product.originalPrice!),
                      style: TextStyle(
                        fontSize: AppScale.t(10),
                        color: Colors.white.withValues(alpha: 0.85),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (pill != null) ...[
              SizedBox(width: AppScale.s(7)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppScale.s(8),
                  vertical: AppScale.s(3),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFCDBCF5)),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    fontSize: AppScale.t(10.5),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: AppScale.s(5)),
        // 星星评分行：实星/半星/空星按评分画，后跟「评分 · 已售」。
        Row(
          children: [
            ..._stars(product.rating),
            SizedBox(width: AppScale.s(5)),
            Text(
              '${product.rating.toStringAsFixed(1)} · 已售 ${product.sales}',
              style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground),
            ),
          ],
        ),
        SizedBox(height: AppScale.s(3)),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppScale.t(14.5),
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: AppScale.s(2)),
        Text(
          fact,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppScale.t(11),
            height: 1.35,
            color: AppColors.mutedForeground,
          ),
        ),
        if (product.spec != null && product.spec!.isNotEmpty) ...[
          SizedBox(height: AppScale.s(2)),
          Text(
            '规格：${product.spec}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }

  // 评分画星：满 1 分一颗实星，零头 ≥0.3 给半星，其余空星；输出 5 颗。
  List<Widget> _stars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.3;
    return [
      for (var i = 0; i < 5; i++)
        Icon(
          i < full
              ? Icons.star
              : (i == full && half ? Icons.star_half : Icons.star_border),
          size: AppScale.s(13),
          color: const Color(0xFFF5A623),
        ),
    ];
  }

  // 底部双按钮（照动画那张）：加购走购物车 + 顶部提示，购买走快捷结算。
  // 按钮是牌身 GestureDetector 的子手势，点击会先命中按钮、不会触发进详情。
  Widget _buttons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CartProvider>().addItem(product);
              showTopSnackBar(
                context,
                content: Text(
                  '已加入购物车',
                  style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD9E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: AppScale.s(15),
                    color: const Color(0xFFD6336C),
                  ),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '加入购物车',
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD6336C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: AppScale.s(9)),
        Expanded(
          child: GestureDetector(
            onTap: () => CheckoutPage.openBuyNow(context, product),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A5FD6), AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: AppScale.s(15), color: Colors.white),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '立即购买',
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 价格文案与旧牌面同口径：整数不带小数，非整数保留两位。
  String _priceText(double price) =>
      '¥${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
}
