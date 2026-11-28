import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/guide_controller.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'floating_ai_assistant.dart';

/// 新手引导罩：挂在 MaterialApp 最顶层（builder 里）。学小游戏引导
/// 的做法（hx 2026-11-27 录屏参考）：指向目标的步不压暗背景——目标
/// 本人带呼吸光晕圈 + AI 生成的白手套大手戳在正中心，气泡贴着目标
/// 说一句话；只有欢迎/恭喜两张模态卡才压暗。顶部只留「跳过引导」。
/// 孔外点击由透明拦截层挡住（只许点目标），孔里就是真控件本人。
/// 输入无（状态全在 GuideController）；输出是用户的点选经真控件
/// 回到各业务组件，推进由组件回报控制器。
class GuideOverlay extends StatefulWidget {
  const GuideOverlay({super.key});

  @override
  State<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<GuideOverlay> {
  Timer? _ticker;

  /// 已经为哪一步滚过目标了：换步时先把目标滚到完整可见再指，
  /// 同一步不重复滚（用户手动滚动后不跟他抢）。
  GuideStep? _broughtStep;

  /// 目标丢失计时（步 + 起点）：同一步的目标持续查不到超过 4 秒，
  /// 气泡换成出路，免得用户对着全屏拦截层卡死。
  GuideStep? _missingStep;
  DateTime? _missingSince;
  int _tick = 0;
  bool _rewardClaimed = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 罩子活着时每 120ms 重测一遍目标位置并重画：目标会随列表滚动、
  /// 键盘起落、悬浮小豆吸附等动作漂移，孔必须跟着走。
  void _syncTicker(bool running) {
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted) return;
        GuideRects.remeasureAll();
        setState(() => _tick++);
      });
    } else if (!running && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
      _rewardClaimed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = context.watch<GuideController>();
    _syncTicker(guide.overlayVisible);
    if (!guide.overlayVisible) return const SizedBox.shrink();

    // 进恭喜页就把奖励领掉（服务端判重，领过不会再发）：
    // 只领一次，用本地旗子挡住重建重复触发。
    if (guide.step == GuideStep.done && !guide.replayMode && !_rewardClaimed) {
      _rewardClaimed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<UserProvider>().claimGuideReward();
      });
    }

    final size = MediaQuery.sizeOf(context);
    final targetId = guide.targetId;
    // 换步先把目标滚到完整可见：目标只露一截时，孔按整卡矩形画、
    // 手落在整卡中心，就会指到看不见的那半截上（2026-11-27 hx
    // 截图实锤：翻牌卡只露个头，手压在下面一排路线 chips 上）。
    // 录屏里的规矩是目标先完整出现、手才指过去，这里照做。
    if (targetId != null && _broughtStep != guide.step) {
      _broughtStep = guide.step;
      WidgetsBinding.instance.addPostFrameCallback((_) => GuideRects.bringToView(targetId));
    }
    final rawRect = targetId == null ? null : GuideRects.of(targetId);
    // 孔只按屏幕上真正看得见的部分算：被滚动区切掉的部分不算数；
    // 可见不足六成时先不画孔与手（阻挡层照常全屏挡），等滚到位。
    Rect? hole;
    if (rawRect != null && rawRect.width > 0 && rawRect.height > 0) {
      final visible = rawRect.intersect(Rect.fromLTWH(0, 0, size.width, size.height));
      if (visible.width >= rawRect.width * 0.6 && visible.height >= rawRect.height * 0.6) {
        hole = Rect.fromLTRB(
          (visible.left - 6).clamp(0, size.width),
          (visible.top - 6).clamp(0, size.height),
          (visible.right + 6).clamp(0, size.width),
          (visible.bottom + 6).clamp(0, size.height),
        );
      }
    }

    // 目标丢失判定：当前步有目标、但登记处查无此控件（被列表滚
    // 出销毁、页面内容换了等）。持续丢超过 4 秒算「丢久了」，
    // _bubble 会换上出路气泡；目标一回来计时清掉、接着走。
    final targetGone = targetId != null && GuideRects.of(targetId) == null;
    if (targetGone) {
      if (_missingStep != guide.step) {
        _missingStep = guide.step;
        _missingSince = DateTime.now();
      }
    } else {
      _missingStep = null;
      _missingSince = null;
    }
    final targetLost = _missingSince != null &&
        DateTime.now().difference(_missingSince!) >= const Duration(seconds: 4);

    // 整个罩子必须包一层透明 Material：罩子挂在页面层之上（MaterialApp
    // builder），里面的 Text 没有 Material 祖先时，Flutter 会按「缺
    // Material」的默认样式给文字加双黄下划线（hx 14:38 截图点名：
    // 「跳过引导」和气泡文字下面那两条黄线）。包上后全部消失。
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
        // 黑罩（带孔）：必须 IgnorePointer 包住——CustomPainter 的
        // hitTest 默认整屏 true，不包的话画笔层会把孔里的点击也吸掉，
        // 用户点小豆永远点不动（2026-11-27 hx 真机实锤的卡点）。
        IgnorePointer(
          child: CustomPaint(
            painter: _HoleMaskPainter(
              hole,
              _tick,
              dimmed: guide.step == GuideStep.done,
            ),
          ),
        ),
        // 拦截层：孔外四块 + （不可点步）孔本身
        ..._blockers(size, hole, guide.holePassThrough),
        // 目标边上的脉冲圈 + 小手
        if (hole != null) _pointer(hole),
        // 顶部：只留「跳过引导」。必须用 Positioned 钉在顶部——它原来是
        // Stack 的非定位子级，被 expand 撑成全屏高，Row 又默认垂直居中，
        // 按钮实际渲染在屏幕正中（hx 截图实锤：压在小豆头上）。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(8)),
            child: Row(
              children: [
                // 步数片已去掉（hx 2026-11-27 点名）：录屏里的引导全程
                // 没有计数，顶部只留「跳过引导」，其余靠手和气泡说话。
                const Spacer(),
                if (guide.step != GuideStep.done)
                  GestureDetector(
                    onTap: () => guide.askSkip(),
                    child: Container(
                      // 按钮放大约 3 倍（hx 2026-11-28 点名）：字号 12→17、
                      // 内边距横 12→24 / 竖 6→14，整体面积约 3 倍、更好点。
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(24), vertical: AppScale.s(14)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '跳过引导',
                        style: TextStyle(fontSize: AppScale.t(17), fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
        // 气泡 / 恭喜卡
        _bubble(context, guide, size, hole, targetLost: targetLost),
        // 跳过确认层（最顶）：罩子自己画的模态卡，见 _skipConfirmLayer。
        if (guide.confirmingSkip) _skipConfirmLayer(guide),
        ],
      ),
    );
  }

  /// 跳过确认层：罩子自己画的模态卡（hx 2026-11-27 点名要的确认
  /// 窗，文案沿用已定稿的那版）。为什么不用 showDialog：罩子挂在
  /// MaterialApp 的 builder 层、位于导航之上，真弹窗开在导航里，
  /// 会被罩子的全屏拦截层挡住点击——两个按钮点不动、窗还关不掉
  /// （hx 实锤）。画在罩子内部、垫在所有层最上方，点击才通。
  /// 「接着看」关层、引导停在当前步不动；「还是跳过」才真跳过
  /// （记 skipped、不发奖，之后走完照常能领）。点层外不关，必须二选一。
  Widget _skipConfirmLayer(GuideController guide) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: AppScale.s(28)),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(18), AppScale.s(20), AppScale.s(16)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppScale.s(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '跳过新手引导？',
                    style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.w700, color: AppColors.foreground),
                  ),
                  SizedBox(height: AppScale.s(9)),
                  Text(
                    '这一步步的教学就先到这儿啦。想再看，去『我的』页点『新手引导』就能重新开始。走完全程有 20 趣玩币奖励，跳过的话这次就没有了；不过以后把引导走完，奖励照样能领。',
                    style: TextStyle(fontSize: AppScale.t(13), height: 1.55, color: AppColors.foreground),
                  ),
                  SizedBox(height: AppScale.s(16)),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: guide.cancelSkip,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: AppScale.s(10)),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '接着看',
                              style: TextStyle(fontSize: AppScale.t(13.5), fontWeight: FontWeight.w600, color: AppColors.foreground),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppScale.s(10)),
                      Expanded(
                        child: GestureDetector(
                          onTap: guide.skip,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: AppScale.s(10)),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '还是跳过',
                              style: TextStyle(fontSize: AppScale.t(13.5), fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _blockers(Size size, Rect? hole, bool passThrough) {
    Widget block(Rect r) => Positioned.fromRect(
          rect: r,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        );
    if (hole == null) {
      return [Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}))];
    }
    final widgets = <Widget>[
      if (hole.top > 0) block(Rect.fromLTRB(0, 0, size.width, hole.top)),
      if (hole.bottom < size.height) block(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
      if (hole.left > 0) block(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
      if (hole.right < size.width) block(Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom)),
    ];
    if (!passThrough) widgets.add(block(hole));
    return widgets;
  }

  Widget _pointer(Rect hole) {
    // 指引手是 AI 生成图（assets/images/guide_hand.png，透明底），照
    // hx 的录屏参考重生：浅肤色卡通手、食指朝左上伸、腕上古铜护腕，
    // 跟录屏里那只几乎一样（不用代码画形，hx 点名）。指尖在图的左上
    // 角（图宽 0.071 处、贴图顶，抠图时按 alpha 实测并画点验过），
    // 摆位让指尖正落目标中心、手身顺指头方向垂在目标右下方，和录屏
    // 里手压在按钮右下角的姿势一致；戳动 = 整只手沿指头方向（左上）
    // 小幅探压 + 微缩。手是 IgnorePointer，绝不挡点击。
    final phase = (_tick % 8) / 8; // 0→1 循环（ticker 120ms 一跳）
    final bob = phase < 0.5 ? phase * 2 : (1 - phase) * 2; // 0→1→0
    final w = AppScale.s(64);
    final h = w * 536 / 440; // 与资产图同宽高比，别拉变形
    final press = AppScale.s(5) * bob;
    return Positioned(
      left: hole.center.dx - w * 0.071 + press,
      top: hole.center.dy - h * 0.01 + press,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 - 0.05 * bob,
          child: Image.asset(
            'assets/images/guide_hand.png',
            width: w,
            height: h,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, GuideController guide, Size size, Rect? hole, {bool targetLost = false}) {
    if (guide.step == GuideStep.done) return _doneCard(context, guide, size);
    // 目标丢久了：不管本步原本说什么，都换成出路——把页面翻回
    // 刚才那儿就能接着走，或者结束引导（奖励照拿，不让用户
    // 因为演示数据/滚动位置卡死在这一屏）。
    if (targetLost) {
      return Positioned(
        left: AppScale.s(16),
        right: AppScale.s(16),
        bottom: AppScale.s(110),
        child: _bubbleCard(guide, (
          title: null,
          body: '要指的东西不在这屏上了。把页面翻回刚才那儿，我就接着带你走；不想走了也可以结束，奖励照拿。',
          buttons: [('结束引导，奖励照拿', guide.completeEarly)],
        )),
      );
    }
    final data = _bubbleData(guide);
    // 纯指引步（有目标、无按钮）：学录屏里的小气泡——一句话、白底、
    // 带小尾巴贴在目标旁边，不用整张大卡（欢迎/恭喜/带按钮的步才用卡）。
    if (hole != null && data.buttons.isEmpty) {
      // body 留空 = 纯手步（录屏里多数步只有手没有字）：目标自带
      // 文字标签时不再念一遍，气泡只留给真带信息的步。
      if (data.body.isEmpty) return const SizedBox.shrink();
      return _miniBubble(guide, data.body, size, hole);
    }
    // 无目标、无文案、无按钮的步（如等提问）：整张气泡都不出，
    // 别留一张只剩头像的空卡在屏上。
    if (hole == null && data.title == null && data.body.isEmpty && data.buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    final card = _bubbleCard(guide, data);
    if (hole == null) {
      // 无目标步：贴底卡片（避开底部导航/输入栏）
      return Positioned(
        left: AppScale.s(16),
        right: AppScale.s(16),
        bottom: AppScale.s(110),
        child: card,
      );
    }
    // 有目标：孔下方放得下就放下方，放不下放上方
    const bubbleH = 150.0;
    final below = hole.bottom + AppScale.s(14);
    final top = below + bubbleH < size.height - AppScale.s(80)
        ? below
        : (hole.top - AppScale.s(14) - bubbleH).clamp(AppScale.s(70), size.height);
    return Positioned(left: AppScale.s(16), right: AppScale.s(16), top: top, child: card);
  }

  ({String? title, String body, List<(String, VoidCallback)> buttons}) _bubbleData(GuideController guide) {
    switch (guide.step) {
      case GuideStep.welcome:
        return (
          title: '我是小豆，你的 AI 导购',
          body: guide.replayMode ? '再过一遍流程？这次没有奖励啦，就是复习。' : '花 1 分钟，我带你把买东西这件事过一遍——完成有 20 趣玩币奖励。',
          buttons: [('开始体验', guide.advance), ('先逛逛', guide.skip)],
        );
      case GuideStep.tapEntry:
        return (title: null, body: '我是小豆，你的 AI 导购。点我，花 1 分钟带你买一遍东西——完成有 20 趣玩币奖励。', buttons: const []);
      case GuideStep.startPick:
        return (title: null, body: '', buttons: const []);
      case GuideStep.waitOptions:
        // 等提问这段不给任何引导解说（hx 2026-11-27 16:49 定）：
        // 就按平时正常对话的样子走——聊天里自有「思考中…」，小豆
        // 把问题正常发出来，引导只在答题时多做指引动作，不预告、
        // 不解说。只有等太久（waitTimedOut）才出声给条出路，那是
        // 故障兜底、不是解说。
        return (
          title: null,
          body: guide.waitTimedOut ? '小豆还没问出来，可能网络在忙。' : '',
          buttons: guide.waitTimedOut ? [('太久了？结束引导，奖励照拿', guide.completeEarly)] : const [],
        );
      case GuideStep.pickAnswer:
        // 指提交按钮时给一句话；指选项时只用手（body 空）；屏幕上
        // 找不到引导想教的那枚（小豆问了没预设答案的问题）时，
        // 给一句兜底，别让用户对着空气猜。
        if (guide.answerTarget == 'guide:submit' && GuideRects.of('guide:submit') != null) {
          return (title: null, body: '选好了，点那个紫色按钮。', buttons: const []);
        }
        if (GuideRects.of('guide:chip') == null) {
          return (title: null, body: '这题没有标准答案，点一个你想要的就行。', buttons: const []);
        }
        return (title: null, body: '', buttons: const []);
      case GuideStep.waitCards:
        if (guide.waitFailed) {
          return (
            title: null,
            body: '这一类刚好没货，演示先到这儿——流程你已经看明白啦，奖励照样发。',
            buttons: [('结束引导', guide.completeEarly)],
          );
        }
        return (
          title: null,
          body: '这一步不用点。我在替你翻数据：销量、口碑、价格，一件件比给你看。',
          buttons: guide.waitTimedOut ? [('太久了？结束引导，奖励照拿', guide.completeEarly)] : const [],
        );
      case GuideStep.pickBudgetChip:
        return (title: null, body: '再点一下牌面上方的「¥100内」，把预算卡住。', buttons: const []);
      case GuideStep.pickCard:
        return (
          title: null,
          body: guide.cardTargetIsReputation
              ? '三张都是按你的条件挑的，每张头上写着它的长处。点带「口碑最好」的那张，翻个牌看看。'
              : '三张都是按你的条件挑的。点一张你顺眼的，翻个牌看看。',
          buttons: const [],
        );
      case GuideStep.demoCheckout:
        return (title: null, body: '都替你办好了，点卡片上的「去下单」。', buttons: const []);
      case GuideStep.buyDemo:
        return (title: null, body: '最后一步，点「立即购买」——放心，这是演示，不会真下单。', buttons: const []);
      default:
        return (title: null, body: '', buttons: const []);
    }
  }

  /// 贴目标小气泡：白底圆角 + 朝向目标的小三角尾巴，横向尽量对准
  /// 目标中心（clamp 在屏内），纵向按目标在上半屏还是下半屏决定
  /// 贴上方还是下方。整件 IgnorePointer，不挡任何点击。
  Widget _miniBubble(GuideController guide, String body, Size size, Rect hole) {
    const bubbleMaxW = 250.0;
    final left = (hole.center.dx - bubbleMaxW / 2).clamp(
      AppScale.s(16),
      size.width - bubbleMaxW - AppScale.s(16),
    );
    final tailDx = (hole.center.dx - left - AppScale.s(6)).clamp(AppScale.s(14), bubbleMaxW - AppScale.s(26));
    final tail = Transform.rotate(
      angle: 0.7853981633974483, // 45°：正方形转成菱形当尾巴尖
      child: Container(width: AppScale.s(12), height: AppScale.s(12), color: Colors.white),
    );
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: bubbleMaxW),
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(9)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 10)],
      ),
      child: Text(
        body,
        style: TextStyle(fontSize: AppScale.t(13), height: 1.45, color: AppColors.foreground),
      ),
    );
    final above = hole.center.dy > size.height / 2;
    final stack = SizedBox(
      width: bubbleMaxW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          Positioned(
            left: tailDx,
            top: above ? null : -AppScale.s(5),
            bottom: above ? -AppScale.s(5) : null,
            child: tail,
          ),
        ],
      ),
    );
    return Positioned(
      left: left,
      top: above ? null : hole.bottom + AppScale.s(16),
      bottom: above ? size.height - hole.top + AppScale.s(16) : null,
      child: IgnorePointer(child: stack),
    );
  }

  Widget _bubbleCard(
    GuideController guide,
    ({String? title, String body, List<(String, VoidCallback)> buttons}) data,
  ) {
    return Container(
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppScale.s(16)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Image.asset(FloatingAiAssistant.assetFull, width: AppScale.s(36), height: AppScale.s(36), fit: BoxFit.cover),
          ),
          SizedBox(width: AppScale.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.title != null) ...[
                  Text(data.title!, style: TextStyle(fontSize: AppScale.t(14.5), fontWeight: FontWeight.w800, color: AppColors.foreground)),
                  SizedBox(height: AppScale.s(3)),
                ],
                Text(data.body, style: TextStyle(fontSize: AppScale.t(13), height: 1.5, color: AppColors.foreground)),
                if (data.buttons.isNotEmpty) ...[
                  SizedBox(height: AppScale.s(10)),
                  Row(
                    children: [
                      for (var i = 0; i < data.buttons.length; i++) ...[
                        if (i > 0) SizedBox(width: AppScale.s(8)),
                        GestureDetector(
                          onTap: data.buttons[i].$2,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(7)),
                            decoration: BoxDecoration(
                              color: i == 0 ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: i == 0 ? null : Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              data.buttons[i].$1,
                              style: TextStyle(
                                fontSize: AppScale.t(12.5),
                                fontWeight: FontWeight.w700,
                                color: i == 0 ? Colors.white : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneCard(BuildContext context, GuideController guide, Size size) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: AppScale.s(28)),
        padding: EdgeInsets.fromLTRB(AppScale.s(20), AppScale.s(22), AppScale.s(20), AppScale.s(18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppScale.s(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: AppScale.s(40), color: AppColors.primary),
            SizedBox(height: AppScale.s(10)),
            Text('演示完成！', style: TextStyle(fontSize: AppScale.t(18), fontWeight: FontWeight.w800, color: AppColors.foreground)),
            SizedBox(height: AppScale.s(6)),
            Text(
              guide.replayMode
                  ? '又过了一遍，流程都熟了吧。以后买东西，就照刚才这样跟我说。'
                  : '以后买东西，就照刚才这样跟我说。20 趣玩币已经放进你的钱包。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppScale.t(13), height: 1.55, color: AppColors.mutedForeground),
            ),
            SizedBox(height: AppScale.s(16)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      guide.finish();
                      GuideNav.navigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                    child: const Text('回到首页'),
                  ),
                ),
                SizedBox(width: AppScale.s(10)),
                Expanded(
                  child: FilledButton(
                    onPressed: guide.finish,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('继续问小豆'),
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

/// 黑罩画笔：整屏半透明黑，目标处挖一个圆角孔（even-odd 两圈路径）。
class _HoleMaskPainter extends CustomPainter {
  _HoleMaskPainter(this.hole, this.tick, {required this.dimmed});

  final Rect? hole;

  /// 重画节拍（罩子的 120ms ticker）：光晕圈的呼吸相位跟着它走。
  final int tick;

  /// 是否压暗背景：只有欢迎/恭喜两张模态卡压暗；指向目标的步不压暗
  /// （学小游戏录屏里没压暗的那些步——靠发光圈+大手+任务条指引）。
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    if (dimmed) {
      final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
      if (hole == null) {
        canvas.drawRect(Offset.zero & size, paint);
      } else {
        final path = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRRect(RRect.fromRectAndRadius(hole!, Radius.circular(AppScale.s(14))));
        canvas.drawPath(path, paint);
      }
    }
    if (hole == null) return;
    // 目标强调（学小游戏录屏）：录屏里目标几乎不套框，最多一层若有
    // 若无的柔光，存在感全靠手。这里只留两层低透明呼吸光晕，硬实
    // 线圈删掉——太「设计稿」了，不像游戏里的引导。
    final phase = (tick % 8) / 8;
    final breath = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    for (final (inflate, width, alpha) in [(3.0, 4.0, 0.30), (8.0, 8.0, 0.16)]) {
      final layer = Paint()
        ..color = AppColors.primary.withValues(alpha: alpha * (0.75 + 0.25 * breath))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!.inflate(inflate), Radius.circular(AppScale.s(16))),
        layer,
      );
    }
  }

  @override
  bool shouldRepaint(_HoleMaskPainter oldDelegate) => oldDelegate.hole != hole || oldDelegate.tick != tick || oldDelegate.dimmed != dimmed;
}
