import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../pages/orders_sheet.dart';
import '../pages/product_detail_page.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/guide_controller.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
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
///    镜像，hx 点名不满意），一圈半落点停在牌背（hx 00:29 换成他发来的开场同款牌背图：金边深蓝卡、四角月牙、几何星座、翅膀张开，透明底、上面没有商品），停约 0.5 秒；
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

/// 变身阶段：idle 三张小卡 / spin1 转向牌背 / hold 牌背停留 /
/// spin2 转成详细卡 / detail 详细卡落定。
enum _Phase { idle, detail }

class _XiaodouFateBoardState extends State<XiaodouFateBoard> {
  _Phase _phase = _Phase.idle;
  int _selected = -1;

  /// 聊天里详细卡落位的测量钥匙：全屏层点按落定时，先在本组件把详细卡
  /// 以透明态摆出来量出它的全局位置，全屏层再照着这个位置飞回来落位。
  final GlobalKey _detailKey = GlobalKey();

  /// 详细卡是否已正式亮出：飞回途中聊天里的那张先藏着（透明），
  /// 全屏层飞到位关掉的那一刻才亮，避免两张卡同时出现。
  bool _detailShown = true;

  Product get _selectedProduct => widget.products[_selected];

  /// 点选小卡：把变身交给全屏层（_FateFlipOverlay）演，演完落定才回 true。
  /// 输入是点中的下标；输出无（结果体现在 _phase 上）。
  /// 坑：全屏层是 rootNavigator 上的独立路由，本组件在它底下一直活着，
  /// 回来后 setState 前仍要查 mounted（用户可能在层开着时退出聊天页）。
  Future<void> _select(int index) async {
    if (_phase != _Phase.idle) return;
    // 新手引导：目标牌被点了，报控制器进翻牌演出步（罩子这段时间藏起来）。
    context.read<GuideController>().notifyCardTapped();
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
          onSettle: _prepareSettle,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted) return;
    if (settled == true) {
      // 飞回路径里 _prepareSettle 已经把详细卡摆好并量过位，这里只负责亮出；
      // 兜底路径（没量到位）则在这里直接切到详细卡。
      setState(() {
        _phase = _Phase.detail;
        _detailShown = true;
      });
      // 新手引导：详细卡落定了，报控制器进看清单步。
      context.read<GuideController>().notifyDetailLanded();
    }
  }

  /// 给全屏层的落位回调：把聊天里的详细卡以透明态先摆出来，量出全局矩形。
  /// 输入无；输出详细卡的全局位置（量不到返回 null，全屏层走直接关层兜底）。
  /// 坑：setState 后要等两帧布局才稳（一帧布局、一帧确保滚动跟随落定），
  /// 量早了飞回去的位置会偏。
  Future<Rect?> _prepareSettle() async {
    if (!mounted) return null;
    setState(() {
      _phase = _Phase.detail;
      _detailShown = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    final box = _detailKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
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
                GuideTarget(
                  id: 'guide:detail',
                  child: Opacity(
                  opacity: _detailShown ? 1 : 0,
                  child: KeyedSubtree(
                    key: _detailKey,
                    child: _DetailCard(
                      product: _selectedProduct,
                      trait: widget.traits[_selectedProduct.id],
                    ),
                  ),
                  ),
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
                // 新手引导要指的牌：带「口碑」特点的那张优先，没有就第一张；
                // 是不是口碑牌报给控制器，决定气泡文案怎么说。
                var guideTarget = 0;
                var guideIsReputation = false;
                for (var k = 0; k < widget.products.length; k++) {
                  if ((widget.traits[widget.products[k].id] ?? '').contains('口碑')) {
                    guideTarget = k;
                    guideIsReputation = true;
                    break;
                  }
                }
                final guideCtrl = context.read<GuideController>();
                if (guideCtrl.active) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    guideCtrl.cardTargetIsReputation = guideIsReputation;
                  });
                }
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
                            child: i == guideTarget
                                ? GuideTarget(
                                    id: 'guide:card',
                                    child: _MiniCard(
                                      product: widget.products[i],
                                      trait: widget.traits[widget.products[i].id],
                                      width: miniW,
                                      height: miniH,
                                      onTap: () => _select(i),
                                    ),
                                  )
                                : _MiniCard(
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
/// 时序：spin1 一圈半（小卡脸 ↔ 牌背，落点背对）1150ms → 牌背停 0.5s →
/// spin2 半转落成详细卡 880ms → 落定等点按（点任意处 pop 回 true）。
/// 输入：商品与特点句；输出：路由返回值 bool（true = 落回聊天变详细卡，
/// false = 取消回三张牌）。返回键：落定前取消、落定后等同点按落定。
class _FateFlipOverlay extends StatefulWidget {
  const _FateFlipOverlay({required this.product, this.trait, this.onSettle});

  final Product product;
  final String? trait;

  /// 落位回调（聊天里的牌板提供）：先在聊天里把详细卡透明摆好并量出
  /// 全局位置，本层再照着飞回去落位；量不到返回 null，走直接关层兜底。
  final Future<Rect?> Function()? onSettle;

  @override
  State<_FateFlipOverlay> createState() => _FateFlipOverlayState();
}

enum _FlipPhase { spin1, hold, spin2, landed }

class _FateFlipOverlayState extends State<_FateFlipOverlay>
    with TickerProviderStateMixin {
  /// 牌背美术图的宽高比（768×1376），全屏舞台尺寸按它算。
  static const double _cardAspect = 768 / 1376;

  /// 牌背图里「卡身本体」的占比（实测 fate_card_back.webp，hx 亲手抠的
  /// 透明版：卡身 x 222..545 / y 380..1015）：整图还含两侧翅膀与透明
  /// 留白，定舞台尺寸必须按卡身比对，不能按整图——按整图算，正面小卡
  /// 脸会比牌背的卡身宽出一大截，翻过去像换了张大牌（hx 截图点名）。
  static const double _bodyWidthFrac = 0.421;
  static const double _bodyAspect = 323 / 635;

  late final AnimationController _spin1 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  late final AnimationController _spin2 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 880),
  );

  /// 飞回落位动画（hx 2026-11-27 追加）：落定点按后，本层的详细卡照着
  /// 聊天里详细卡的位置飞过去缩到位，再关层，看起来是同一张卡飞回聊天。
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  final GlobalKey _landedKey = GlobalKey();
  Rect? _flyFrom;
  Rect? _flyTo;
  bool _flying = false;

  _FlipPhase _phase = _FlipPhase.spin1;

  @override
  void initState() {
    super.initState();
    _fly.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop(true);
      }
    });
    _run();
  }

  @override
  void dispose() {
    _spin1.dispose();
    _spin2.dispose();
    _fly.dispose();
    super.dispose();
  }

  /// 变身主链：转到牌背 → 停留 → 转详细卡落定。
  /// 坑：层被返回键关掉时控制器 future 抛 TickerCanceled，吞掉静默收尾。
  Future<void> _run() async {
    try {
      await _spin1.forward();
      if (!mounted) return;
      setState(() => _phase = _FlipPhase.hold);
      await Future.delayed(const Duration(milliseconds: 500));
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

  /// 点按：落定后 = 关层落回聊天；牌背停留时点按 = 跳过等待直接翻详细卡；
  /// 旋转途中不响应（防连点把时序点乱）。
  void _onTap() {
    if (_flying) return;
    if (_phase == _FlipPhase.landed) {
      _settle();
    } else if (_phase == _FlipPhase.hold) {
      _startSpin2();
    }
  }

  /// 落定后的点按：量本层详细卡与聊天里详细卡的全局位置，飞回去落位。
  /// 任一量不到就直接关层（聊天里会直接亮出详细卡，功能不受影响）。
  Future<void> _settle() async {
    final settle = widget.onSettle;
    if (settle == null) {
      Navigator.of(context).pop(true);
      return;
    }
    final box = _landedKey.currentContext?.findRenderObject() as RenderBox?;
    final target = await settle();
    if (!mounted) return;
    if (box == null || !box.hasSize || target == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _flyFrom = box.localToGlobal(Offset.zero) & box.size;
      _flyTo = target;
      _flying = true;
    });
    _fly.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 舞台定尺寸（hx 2026-11-27 修正口径）：牌背画布 backW 占屏 92% 让
    // 卡+翅膀占画面主导；正面小卡脸按画布里卡身本体的占比折算（bodyW/
    // bodyH），与牌背卡身同宽同高，翻转前后是同一张牌，不再按整图比对。
    final backW = math.min(size.width * 0.92, AppScale.s(520));
    final backH = backW / _cardAspect;
    // 正面小卡脸按卡身本体定尺寸（与牌背卡身同宽同高），不是按整图。
    final bodyW = backW * _bodyWidthFrac;
    final bodyH = bodyW / _bodyAspect;
    final detailW = backW;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _flying) return;
        // 返回键：落定后同点按（飞回落位），没落定 = 取消回三张牌。
        if (_phase == _FlipPhase.landed) {
          _settle();
        } else {
          Navigator.of(context).pop(false);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          // 背景全程透明（hx 2026-11-27 定）：不铺任何底幕，牌直接在聊天
          // 之上翻，落定点按后飞回聊天里详细卡的位置落位。
          child: Stack(
            children: [
              // 投屏模糊层（hx 2026-11-27 提议）：聊天被糊住一层当投屏背景，
              // 牌在上面翻；飞回落位时模糊同步淡出，落地那刻正好恢复清晰聊天。
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _fly,
                  builder: (_, _) {
                    final fade = _flying ? (1 - _fly.value) : 1.0;
                    return BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 9 * fade,
                        sigmaY: 9 * fade,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.14 * fade),
                      ),
                    );
                  },
                ),
              ),
              if (!_flying)
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spin1, _spin2]),
                    builder: (context, _) => _stageCard(bodyW, bodyH, backW, backH, detailW),
                  ),
                ),
              if (_phase == _FlipPhase.landed && !_flying)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppScale.s(46),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppScale.s(14),
                        vertical: AppScale.s(7),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppScale.s(20)),
                      ),
                      child: Text(
                        '点任意处回到聊天',
                        style: TextStyle(
                          fontSize: AppScale.t(12.5),
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_flying && _flyFrom != null && _flyTo != null)
                AnimatedBuilder(
                  animation: _fly,
                  builder: (_, child) {
                    final t = Curves.easeInOut.transform(_fly.value);
                    final rect = Rect.lerp(_flyFrom!, _flyTo!, t)!;
                    return Positioned(
                      left: rect.left,
                      top: rect.top,
                      width: rect.width,
                      child: child!,
                    );
                  },
                  child: _DetailCard(
                    product: widget.product,
                    trait: widget.trait,
                    interactive: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前帧的牌面：按阶段与动画进度算（角度、缩放、哪张脸）。
  /// 换脸点都卡在牌面侧对观众（90°，只剩一条线）或背对观众的时刻，观众看不见切换：
  /// spin1 正面是小卡脸、背对时是牌背，一圈半落点停在牌背；
  /// 牌背要多转半圈（π）抵消镜像，不然星座图是反的。
  Widget _stageCard(double bodyW, double bodyH, double backW, double backH, double detailW) {
    final product = widget.product;
    switch (_phase) {
      case _FlipPhase.spin1:
        // 一圈半（0 → 3π）：正面是小卡脸、背面是牌背，落点正好背对观众——
        // 照开场动画的翻法：先把牌背亮给观众，商品只在最后的详细卡里出现
        // （hx 00:29 定：背面不许有商品，原先落点是带商品的幻想脸，已废）。
        final v = Curves.easeInOut.transform(_spin1.value);
        final angle = v * math.pi * 3;
        final scale = 0.5 + 0.5 * Curves.easeOut.transform(_spin1.value);
        if (math.cos(angle) >= 0) {
          return _rotated(angle, scale, _MiniFace(product: product, trait: widget.trait, width: bodyW, height: bodyH));
        }
        // 背对观众：牌背美术图，先自转 π 抵消镜像再跟主旋转。
        return _rotated(
          angle,
          scale,
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: _BackFace(width: backW, height: backH),
          ),
        );
      case _FlipPhase.hold:
        return _BackFace(width: backW, height: backH);
      case _FlipPhase.spin2:
        final v = _spin2.value;
        if (v < 0.5) {
          // 前半：牌背从背对（π）加速转到侧面（π/2），牌背自带 π 抵消镜像。
          final angle = math.pi - Curves.easeIn.transform(v * 2) * math.pi / 2;
          return _rotated(
            angle,
            1,
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _BackFace(width: backW, height: backH),
            ),
          );
        }
        // 后半：详细卡从侧面（π/2）转回正面（0），静态版，落定后聊天里换可点版。
        final t = Curves.easeOut.transform((v - 0.5) * 2);
        return _rotated(
          math.pi / 2 * (1 - t),
          1, // 全程不缩放：0.94 的回缩会让落定前肉眼可见地缩一下（hx 点名衔接不流畅）
          SizedBox(
            width: detailW,
            child: _DetailCard(product: product, trait: widget.trait, interactive: false),
          ),
        );
      case _FlipPhase.landed:
        // 落定版必须是可点版（hx 2026-11-27 定点按分区）：点卡身（按钮外）
        // 进商品详情、点两个按钮各自办事，只有卡外才归全屏层管、飞回聊天。
        // 可点版自带的手势比全屏层的手势更靠内层，竞技场里先赢，不会误退。
        return SizedBox(
          width: detailW,
          child: KeyedSubtree(
            key: _landedKey,
            child: _DetailCard(product: product, trait: widget.trait, interactive: true),
          ),
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
/// 小卡、变身脸、详细卡三处共用，兜底口径保持一致。
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
/// 转的过程中正面始终是它，观众只会觉得同一张牌在变身。
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
                _DetailCardButtons(product: product),
              ],
            ),
          ),
          // 四角小星饰 + 顶部正中爱心宝石：只点缀边框、不碰牌面内容区。
          // 坑（v4.1 修）：这些饰件必须用 Positioned，绝不能用 Align——Align 是
          // Stack 的非定位子件、会参与定尺寸，在有界高环境（如全屏翻牌层）里
          // 它会把卡片撑满整个可用高度（真机实锤：详细卡拉成整屏奶油板）；
          // 在聊天列表的无界高里它又会塌回内容高，所以框内看着一直没事。
          Positioned(
            top: AppScale.s(4),
            left: AppScale.s(4),
            child: Icon(Icons.auto_awesome, size: AppScale.s(9), color: const Color(0xFFD9A94F)),
          ),
          Positioned(
            top: AppScale.s(4),
            right: AppScale.s(4),
            child: Icon(Icons.auto_awesome, size: AppScale.s(9), color: const Color(0xFFD9A94F)),
          ),
          Positioned(
            bottom: AppScale.s(4),
            left: AppScale.s(4),
            child: Icon(Icons.auto_awesome, size: AppScale.s(9), color: const Color(0xFFD9A94F)),
          ),
          Positioned(
            bottom: AppScale.s(4),
            right: AppScale.s(4),
            child: Icon(Icons.auto_awesome, size: AppScale.s(9), color: const Color(0xFFD9A94F)),
          ),
          Positioned(
            top: -AppScale.s(8),
            left: 0,
            right: 0,
            child: Center(
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

  // 价格文案与旧牌面同口径：整数不带小数，非整数保留两位。
  String _priceText(double price) =>
      '¥${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
}

/// 详细卡底部按钮区（独立成有状态组件，2026-11-27）：管两件事——
/// 「加入购物车」与「立即购买」=小豆代买。
/// 代买成功后**不跳页**（hx 2026-11-27 真机点名：点立即购买应该是
/// 在对话里把单下掉，不要把人甩到订单详情页）：按钮区原地变成
/// 「已下单 · 实付 ¥X」状态片 + 「去支付」按钮，用户自己点去支付
/// 时才进订单详情付款。
/// 静态版详细卡（interactive=false，全屏翻牌层里那张）也被 IgnorePointer
/// 罩着、点不动，这里的状态永远不会被触发，不用另做区分。
class _DetailCardButtons extends StatefulWidget {
  const _DetailCardButtons({required this.product});

  final Product product;

  @override
  State<_DetailCardButtons> createState() => _DetailCardButtonsState();
}

class _DetailCardButtonsState extends State<_DetailCardButtons> {
  // 代买成功后存下订单：非空 = 已下单，按钮区切换成付款形态。
  Order? _placedOrder;

  @override
  Widget build(BuildContext context) {
    // 新手引导演示下单完成：按钮区换成演示成功片（没有真订单、不给去支付）。
    final guide = context.watch<GuideController>();
    if (guide.demoOrderPlaced && _placedOrder == null) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7EE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: AppScale.s(15), color: const Color(0xFF1F9D55)),
            SizedBox(width: AppScale.s(4)),
            Text(
              '演示下单成功（未真实下单）',
              style: TextStyle(
                fontSize: AppScale.t(12.5),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F9D55),
              ),
            ),
          ],
        ),
      );
    }
    final placed = _placedOrder;
    if (placed != null) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(9)),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: AppScale.s(15), color: const Color(0xFF1F9D55)),
                  SizedBox(width: AppScale.s(4)),
                  Text(
                    '已下单 · 实付 ${_priceText(placed.total)}',
                    style: TextStyle(
                      fontSize: AppScale.t(12.5),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F9D55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: AppScale.s(9)),
          Expanded(
            child: GestureDetector(
              onTap: () => openOrderDetail(context, placed),
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
                    Icon(Icons.payments_outlined, size: AppScale.s(15), color: Colors.white),
                    SizedBox(width: AppScale.s(4)),
                    Text(
                      '去支付',
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
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CartProvider>().addItem(widget.product);
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
          child: GuideTarget(
            id: 'guide:buy',
            child: GestureDetector(
            onTap: () {
              // 新手引导的最后一步：点这里不真下单，走演示表单。
              final guide = context.read<GuideController>();
              if (guide.step == GuideStep.buyDemo) {
                guide.advance();
                showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(18))),
                  ),
                  builder: (_) => const _GuideDemoSheet(),
                ).then((_) => guide.notifyDemoSheetClosed());
              } else {
                _agentBuy(context);
              }
            },
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
        ),
      ],
    );
  }

  // 「立即购买」= 小豆代买（2026-11-27 hx 定）：点一下，小豆用默认地址
  // 直接把待付款订单办好——券由服务端自动挑最划算的一张、满减与会员
  // 95 折照算。成功后不跳页：按钮区原地变「已下单 + 去支付」（见类注释）。
  // 注意只有小豆里的卡片走代买；小豆之外（商品详情页等）的立即购买
  // 仍走正常结算页，不要把那边的入口改到这里来。
  // 没有任何地址时在对话里弹快速表单当场填（见 _QuickAddressForm），
  // 存好自动接着下单；关掉表单则停在这一步，不下单。
  Future<void> _agentBuy(BuildContext context) async {
    final product = widget.product;
    final user = context.read<UserProvider>();
    var address = user.defaultAddress;
    if (address == null) {
      // 没地址不在对话里弹通知框、更不跳填写页（hx 2026-11-27 点名）：
      // 从对话底部弹一张快速表单当场填，存好自动接着下单。
      final saved = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(18))),
        ),
        builder: (_) => const _QuickAddressForm(),
      );
      if (saved != true || !context.mounted) return;
      // saveAddress 内部已刷新地址列表，直接取默认地址接着下单。
      address = user.defaultAddress;
      if (address == null) return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Order? order;
    Object? failure;
    try {
      order = await context.read<OrderProvider>().checkoutDirect(
            [CartItem(product: product, quantity: 1, spec: product.spec)],
            addressId: address.id,
            payNow: false,
            autoCoupon: true,
          );
      await user.loadFromRemote();
    } catch (e) {
      failure = e;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (order == null) {
      showTopSnackBar(
        context,
        content: Text(
          '小豆下单没办成${failure == null ? '' : '：$failure'}',
          style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
        ),
      );
      return;
    }
    showTopSnackBar(
      context,
      content: Text(
        '小豆已帮你下单，就差付款了',
        style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
      ),
    );
    // 不跳页：把订单存进状态，按钮区原地切换成「已下单 + 去支付」。
    if (mounted) setState(() => _placedOrder = order);
  }

  // 价格文案与牌面同口径：整数不带小数，非整数保留两位。
  String _priceText(double price) =>
      '¥${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
}

/// 对话内快速地址表单（2026-11-27，hx 点名）：代买时没地址就从对话底部
/// 弹出来，当场填、当场存，不跳地址编辑页。
/// 预填口径与地址编辑页完全一致：收货人先写昵称加「（可修改）」后缀
/// （保存时自动摘掉）、手机号先写注册号；存的时候直接设为默认地址，
/// 回到 _agentBuy 就能拿它下单。
/// 输出：保存成功返回 true；取消或关掉返回 null，_agentBuy 就停手。
class _QuickAddressForm extends StatefulWidget {
  const _QuickAddressForm();

  @override
  State<_QuickAddressForm> createState() => _QuickAddressFormState();
}

class _QuickAddressFormState extends State<_QuickAddressForm> {
  // 与地址编辑页同名的预填后缀，保存时摘掉、不存进地址。
  static const _prefillHint = '（可修改）';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailController = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (user.nickname.isNotEmpty) {
      _nameController.text = '${user.nickname}$_prefillHint';
    }
    if (user.phone.isNotEmpty) {
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var name = _nameController.text.trim();
    if (name.endsWith(_prefillHint)) {
      name = name.substring(0, name.length - _prefillHint.length).trim();
    }
    final phone = _phoneController.text.trim();
    final detail = _detailController.text.trim();
    if (name.isEmpty || phone.isEmpty || detail.isEmpty) {
      showTopSnackBar(
        context,
        content: Text(
          '请把收货人、手机号和详细地址填完整',
          style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final error = await context.read<UserProvider>().saveAddress(
          name: name,
          phone: phone,
          detail: detail,
          isDefault: true,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      showTopSnackBar(
        context,
        content: Text(error, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // 表单在键盘上方：底部让出键盘高度，键盘弹起时字段不被挡。
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(18), AppScale.s(20), AppScale.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '填个收货地址',
              style: TextStyle(fontSize: AppScale.t(17), fontWeight: FontWeight.w700, color: AppColors.foreground),
            ),
            SizedBox(height: AppScale.s(4)),
            Text(
              '小豆用这个地址帮你下单，填一次，以后自动就用它。',
              style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground),
            ),
            SizedBox(height: AppScale.s(14)),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '收货人'),
            ),
            SizedBox(height: AppScale.s(10)),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            SizedBox(height: AppScale.s(10)),
            TextField(
              controller: _detailController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '详细地址'),
            ),
            SizedBox(height: AppScale.s(18)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                SizedBox(width: AppScale.s(12)),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text(_saving ? '保存中…' : '保存并下单'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 新手引导的演示地址表单：长相和对话内快速地址表单（_QuickAddressForm）
/// 一套，但整张都是假的——预填演示数据、顶部挂演示横幅、主按钮叫
/// 「完成演示」，点了只报引导控制器收尾，不调任何下单/存地址接口。
/// 输入无；输出无（完成与否经 GuideController.notifyDemoPlaced /
/// notifyDemoSheetClosed 回报）。坑：真表单上线后若改版式，这张演示的
/// 跟着改，两张脸要保持一致，用户看的就是「真下单长这样」。
class _GuideDemoSheet extends StatefulWidget {
  const _GuideDemoSheet();

  @override
  State<_GuideDemoSheet> createState() => _GuideDemoSheetState();
}

class _GuideDemoSheetState extends State<_GuideDemoSheet> {
  final _nameController = TextEditingController(text: '小豆演示');
  final _phoneController = TextEditingController(text: '138 0000 0000');
  final _detailController = TextEditingController(text: '星屿邮局 1 号（演示地址）');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(18), AppScale.s(20), AppScale.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(8)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D6),
                borderRadius: BorderRadius.circular(AppScale.s(10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: AppScale.s(16), color: const Color(0xFFB07D10)),
                  SizedBox(width: AppScale.s(6)),
                  Expanded(
                    child: Text(
                      '演示模式 · 不会真的下单、不扣款',
                      style: TextStyle(
                        fontSize: AppScale.t(12.5),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB07D10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.s(14)),
            Text(
              '填个收货地址（演示）',
              style: TextStyle(fontSize: AppScale.t(17), fontWeight: FontWeight.w700, color: AppColors.foreground),
            ),
            SizedBox(height: AppScale.s(4)),
            Text(
              '真买的时候，小豆就用这个地址帮你下单，填一次，以后自动就用它。',
              style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground),
            ),
            SizedBox(height: AppScale.s(14)),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '收货人'),
            ),
            SizedBox(height: AppScale.s(10)),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            SizedBox(height: AppScale.s(10)),
            TextField(
              controller: _detailController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '详细地址'),
            ),
            SizedBox(height: AppScale.s(18)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                SizedBox(width: AppScale.s(12)),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      context.read<GuideController>().notifyDemoPlaced();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('完成演示'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
