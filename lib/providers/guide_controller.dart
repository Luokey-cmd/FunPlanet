import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 新手引导的全局导航钥匙：引导罩挂在 MaterialApp 的 builder 层，
/// 拿不到 Navigator 的祖先 context，凡是引导要关页面（恭喜页回首页）
/// 都走这把钥匙。main.dart 把它交给 MaterialApp.navigatorKey。
class GuideNav {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

/// 引导步骤（顺序即流程）：
/// welcome 欢迎（首页，开始/跳过）→ tapEntry 点小豆悬浮入口 →
/// startPick 点小豆首页「翻牌推荐」→ waitOptions 等服务端分组问题出现 →
/// pickType/pickSeries/pickBudget 三问点选 → submitOptions 点提交 →
/// waitCards 等功课与亮牌 → pickCard 点目标牌 → flipping 翻牌演出中（罩隐藏）→
/// detailIntro 看办事清单 → buyDemo 点立即购买 → demoSheet 演示表单（罩隐藏）→
/// done 恭喜页。idle = 引导没在跑。
enum GuideStep {
  idle,
  welcome,
  tapEntry,
  startPick,
  waitOptions,
  pickType,
  pickSeries,
  pickBudget,
  submitOptions,
  waitCards,
  pickCard,
  flipping,
  detailIntro,
  buyDemo,
  demoSheet,
  done,
}

/// 引导目标位置登记处：GuideTarget 组件把自己在屏幕上的矩形报到这里，
/// 引导罩按当前步的目标 id 来这里取矩形挖孔。静态表，不触发任何重建；
/// 罩子自己定时重测（目标会随滚动、键盘、悬浮小豆漂移而动）。
class GuideRects {
  static final Map<String, Rect> _rects = {};
  static final Set<_GuideTargetState> _states = {};

  static Rect? of(String id) => _rects[id];

  static void _register(_GuideTargetState state) => _states.add(state);

  static void _unregister(_GuideTargetState state) {
    _states.remove(state);
    _rects.remove(state.widget.id);
  }

  static void _report(String id, Rect rect) => _rects[id] = rect;

  /// 让所有活着的目标重新量一遍自己的位置（罩子定时调用）。
  static void remeasureAll() {
    for (final state in _states.toList()) {
      state.measure();
    }
  }
}

/// 引导目标包装：套在任何要被挖孔高亮的控件外面，把它的全局矩形
/// 持续报给 GuideRects。输入 id（步骤按 id 找目标）+ 子控件；
/// 输出无，纯测量。坑：id 全局唯一，同一时刻只能有一个同 id 目标活着。
class GuideTarget extends StatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    GuideRects._register(this);
  }

  @override
  void dispose() {
    GuideRects._unregister(this);
    super.dispose();
  }

  void measure() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    GuideRects._report(widget.id, box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => measure());
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// 新手引导控制器：步骤机 + 存档 + 演示开关，全 App 一份（main.dart 注入）。
///
/// 存档口径（SharedPreferences，键 guide_status_v1）：
/// 没存过 = new（首次进主界面自动跑）；start 后 = started（中途退出，
/// 下次进主界面从 tapEntry 续）；skip = skipped（不再自动弹，靠入口手动进）；
/// done = done（不再自动弹，重玩走 replay，不再发奖）。
/// 奖励防刷在服务端（UserProfile.guideRewardClaimed），本地 done 只管弹不弹。
class GuideController extends ChangeNotifier {
  static const int rewardCoins = 20;
  static const String _statusKey = 'guide_status_v1';

  GuideStep _step = GuideStep.idle;
  GuideStep get step => _step;
  bool get active => _step != GuideStep.idle;

  String _status = 'new';
  String get status => _status;
  bool get completed => _status == 'done';

  /// 重玩模式（已完成后从「我的」页再进）：流程照走，恭喜页不提奖励。
  bool replayMode = false;

  /// 演示下单已完成：详细卡按钮区据此亮「演示下单成功」片。
  bool demoOrderPlaced = false;

  /// 本批目标牌是不是「口碑最好」那张（牌板算完报上来，决定 pickCard 文案）。
  bool cardTargetIsReputation = true;

  /// waitCards 等太久（20 秒）或等到空批次：气泡给出路，不让用户干等。
  bool waitTimedOut = false;
  bool waitFailed = false;
  Timer? _waitTimer;

  bool _loaded = false;

  /// 当前步要挖孔的目标 id；null = 不挖孔（欢迎/等待/恭喜）。
  String? get targetId => switch (_step) {
        GuideStep.tapEntry => 'guide:xiaodouEntry',
        GuideStep.startPick => 'guide:fateEntry',
        GuideStep.pickType || GuideStep.pickSeries || GuideStep.pickBudget => 'guide:chip',
        GuideStep.submitOptions => 'guide:submit',
        GuideStep.pickCard => 'guide:card',
        GuideStep.detailIntro => 'guide:detail',
        GuideStep.buyDemo => 'guide:buy',
        _ => null,
      };

  /// 孔里能不能真点：detailIntro 只看不点（孔照挖、点拦住），其余有孔步可点。
  bool get holePassThrough => _step != GuideStep.detailIntro;

  /// 罩子要不要画：翻牌演出与演示表单期间藏起来，别抢戏。
  bool get overlayVisible =>
      active && _step != GuideStep.flipping && _step != GuideStep.demoSheet;

  /// 三问步要找的选项关键字：分组选项组件按它定位要挖孔的那枚 chip。
  String? get chipNeed => switch (_step) {
        GuideStep.pickType => '手办',
        GuideStep.pickSeries => '月光马戏团',
        GuideStep.pickBudget => '50到100元',
        _ => null,
      };

  /// 进度文案：第 X 步 · 共 7 步（欢迎与恭喜不计）。
  String? get progressLabel {
    final n = switch (_step) {
      GuideStep.tapEntry => 1,
      GuideStep.startPick => 2,
      GuideStep.pickType || GuideStep.pickSeries || GuideStep.pickBudget || GuideStep.submitOptions => 3,
      GuideStep.waitCards => 4,
      GuideStep.pickCard => 5,
      GuideStep.detailIntro => 6,
      GuideStep.buyDemo => 7,
      _ => null,
    };
    return n == null ? null : '第 $n 步 · 共 7 步';
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _status = prefs.getString(_statusKey) ?? 'new';
    notifyListeners();
  }

  Future<void> _saveStatus(String value) async {
    _status = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, value);
  }

  /// 主界面站稳后调：第一次进来（new）自动开跑；中途退出过（started）
  /// 从点小豆入口那步续。skipped/done 不自动弹。
  Future<void> maybeAutoStart() async {
    await _load();
    if (active) return;
    if (_status == 'new') {
      _begin(GuideStep.welcome, replay: false);
    } else if (_status == 'started') {
      _begin(GuideStep.tapEntry, replay: false);
    }
  }

  /// 「我的」页入口手动进：永远从欢迎步重走；已完成的是重玩（不发奖）。
  void startManual() {
    if (active) return;
    _begin(GuideStep.welcome, replay: _status == 'done');
  }

  void _begin(GuideStep from, {required bool replay}) {
    replayMode = replay;
    demoOrderPlaced = false;
    waitTimedOut = false;
    waitFailed = false;
    _step = from;
    if (!replay) unawaited(_saveStatus('started'));
    notifyListeners();
  }

  /// 推进一步（按当前步的固定次序）。三问点选、提交、翻牌落定等
  /// 事件点都调它，各组件不用知道下一步是什么。
  void advance() {
    final next = switch (_step) {
      GuideStep.welcome => GuideStep.tapEntry,
      GuideStep.tapEntry => GuideStep.startPick,
      // startPick 直接进引导自己的三问面板：翻牌推荐卡在引导模式下
      // 不发「帮我翻三张命运牌」（那句话直接抽牌、不问问题，等不到 optionSet）。
      GuideStep.startPick => GuideStep.pickType,
      GuideStep.waitOptions => GuideStep.pickType,
      GuideStep.pickType => GuideStep.pickSeries,
      GuideStep.pickSeries => GuideStep.pickBudget,
      GuideStep.pickBudget => GuideStep.submitOptions,
      GuideStep.submitOptions => GuideStep.waitCards,
      GuideStep.waitCards => GuideStep.pickCard,
      GuideStep.pickCard => GuideStep.flipping,
      GuideStep.flipping => GuideStep.detailIntro,
      GuideStep.detailIntro => GuideStep.buyDemo,
      GuideStep.buyDemo => GuideStep.demoSheet,
      GuideStep.demoSheet => GuideStep.done,
      _ => _step,
    };
    if (next == _step) return;
    _step = next;
    if (next == GuideStep.waitCards || next == GuideStep.waitOptions) {
      waitTimedOut = false;
      waitFailed = false;
      _waitTimer?.cancel();
      // 等谁都一样只等 20 秒：waitCards 等牌、waitOptions 等问题，
      // 到时没等到就给气泡出路，不让用户干等（2026-11-27 主聊复核补的兜底）。
      _waitTimer = Timer(const Duration(seconds: 20), () {
        if (_step == GuideStep.waitCards) {
          waitTimedOut = true;
          notifyListeners();
        } else if (_step == GuideStep.waitOptions) {
          // 兜底：服务端问题没来，直接亮引导自己的三问面板。
          _step = GuideStep.pickType;
          notifyListeners();
        }
      });
    } else {
      _waitTimer?.cancel();
    }
    if (next == GuideStep.done && !replayMode) {
      unawaited(_saveStatus('done'));
    }
    notifyListeners();
  }

  /// 等牌阶段提前收尾（空批次/等太久）：直接进恭喜页，奖励照发——
  /// 不能因为演示数据出问题扣用户奖励（设计稿兜底口径）。
  void completeEarly() {
    if (_step != GuideStep.waitCards) return;
    _waitTimer?.cancel();
    _step = GuideStep.done;
    if (!replayMode) unawaited(_saveStatus('done'));
    notifyListeners();
  }

  /// 跳过：停在当前步不走了，状态记 skipped（首次）——之后不再自动弹，
  /// 「我的」页入口还在。重玩时跳过不改 done 状态。
  void skip() {
    _waitTimer?.cancel();
    _step = GuideStep.idle;
    if (!replayMode && _status != 'done') unawaited(_saveStatus('skipped'));
    notifyListeners();
  }

  /// 正常收尾（恭喜页按钮）：状态落 done，罩子撤下。
  void finish() {
    _waitTimer?.cancel();
    _step = GuideStep.idle;
    if (!replayMode) unawaited(_saveStatus('done'));
    notifyListeners();
  }

  // ---------- 各接线点的事件回报（组件只报事实，推步在这里判） ----------

  /// 分组问题已出现在对话里（小豆页监听到带 optionSet 的消息）。
  void notifyOptionsReady() {
    if (_step == GuideStep.waitOptions) advance();
  }

  /// 三问提交了（onPick 触发）：三问任一步都算——用户可能在某步改选后
  /// 直接点提交，步数未必正好停在 submitOptions。进等牌步并起 20 秒定时。
  void notifyOptionsSubmitted() {
    if (_step == GuideStep.pickType ||
        _step == GuideStep.pickSeries ||
        _step == GuideStep.pickBudget ||
        _step == GuideStep.submitOptions) {
      _step = GuideStep.waitCards;
      waitTimedOut = false;
      waitFailed = false;
      _waitTimer?.cancel();
      _waitTimer = Timer(const Duration(seconds: 20), () {
        if (_step == GuideStep.waitCards) {
          waitTimedOut = true;
          notifyListeners();
        }
      });
      notifyListeners();
    }
  }

  /// 亮牌结果到了：有牌进 pickCard；空批次记 waitFailed，气泡给出路。
  void notifyCardsReady({required bool hasProducts}) {
    if (_step != GuideStep.waitCards) return;
    if (hasProducts) {
      advance();
    } else {
      waitFailed = true;
      notifyListeners();
    }
  }

  /// 目标牌被点、翻牌演出开始。
  void notifyCardTapped() {
    if (_step == GuideStep.pickCard) advance();
  }

  /// 翻牌落定、详细卡已在对话里亮出。
  void notifyDetailLanded() {
    if (_step == GuideStep.flipping) advance();
  }

  /// 演示表单被关掉但没完成（取消/划掉）：从 demoSheet 退回 buyDemo。
  void notifyDemoSheetClosed() {
    if (_step == GuideStep.demoSheet) {
      _step = GuideStep.buyDemo;
      notifyListeners();
    }
  }

  /// 演示表单点了「完成演示」。
  void notifyDemoPlaced() {
    demoOrderPlaced = true;
    if (_step == GuideStep.demoSheet) advance();
    notifyListeners();
  }
}
