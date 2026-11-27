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
/// welcome 欢迎（已废弃，枚举保留）→ tapEntry 点小豆悬浮入口 →
/// startPick 点聊天页「挑手办」词条（真发出去）→ waitOptions 等小豆
/// 提问出现 → pickAnswer 答题步（小豆问什么指什么：分组卡按组标签
/// 指首选答案、选齐指提交按钮；平铺按钮按关键字指那枚；答完回
/// waitOptions 循环，直到牌亮出来）→ waitCards 等亮牌 →
/// pickBudgetChip 点牌面上方预算档「¥100内」（hx 2026-11-27 指明：
/// 100 元内就是牌面调档那排，点完按预算重抽再选牌；抽牌时预算
/// 已经是 100 的跳过此步）→ pickCard 点目标牌 → flipping 翻牌演出中（罩隐藏）→ detailIntro 看办事
/// 清单 → buyDemo 点立即购买（不弹面板：小豆在对话里说清地址与
/// 下单）→ done 恭喜页。idle = 引导没在跑。
/// pickRecipient/pickBudget/submitOptions/waitOptions2/pickType/
/// pickSeries/submitOptions2 是写死两轮时期的旧步，已退役，枚举
/// 保留防旧存档，advance 一律并入 pickAnswer。
enum GuideStep {
  idle,
  welcome,
  tapEntry,
  startPick,
  waitOptions,
  pickAnswer,
  pickRecipient,
  pickBudget,
  submitOptions,
  waitOptions2,
  pickType,
  pickSeries,
  submitOptions2,
  waitCards,
  pickBudgetChip,
  pickCard,
  flipping,
  detailIntro,
  buyDemo,
  demoCheckout,
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

  /// 把某个目标滚动到完整可见（它若在可滚动区里且被切掉一截）。
  /// 录屏里的规矩：目标先完整出现在屏幕上，手才指过去；只露一截就
  /// 指过去，手会落在看不见的那半截上（2026-11-27 hx 截图实锤：
  /// 翻牌卡只露个头，手却落在卡中心位置的路线 chips 上）。
  static void bringToView(String id) {
    for (final state in _states.toList()) {
      if (state.widget.id == id) state.bringToView();
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

  /// 把自己滚到可见区偏上位置（alignment 0.3：上方留出气泡的空间）。
  /// 不在滚动区里的目标调用无副作用。
  void bringToView() {
    if (!mounted) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
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
        GuideStep.startPick => 'guide:pickFigure',
        GuideStep.pickAnswer => answerTarget,
        GuideStep.pickRecipient || GuideStep.pickType || GuideStep.pickSeries || GuideStep.pickBudget => 'guide:chip',
        GuideStep.submitOptions || GuideStep.submitOptions2 => 'guide:submit',
        GuideStep.pickBudgetChip => 'guide:budget100',
        GuideStep.pickCard => 'guide:card',
        GuideStep.detailIntro => 'guide:detail',
        GuideStep.buyDemo => 'guide:buy',
        GuideStep.demoCheckout => 'guide:demoOrder',
        _ => null,
      };

  /// 孔里能不能真点：detailIntro 只看不点（孔照挖、点拦住），其余有孔步可点。
  bool get holePassThrough => _step != GuideStep.detailIntro;

  /// 罩子要不要画：翻牌演出与演示表单期间藏起来，别抢戏。
  bool get overlayVisible =>
      active && _step != GuideStep.flipping && _step != GuideStep.demoSheet;

  /// 进度文案：第 X 步 · 共 7 步（欢迎与恭喜不计）。
  String? get progressLabel {
    final n = switch (_step) {
      GuideStep.tapEntry => 1,
      GuideStep.startPick => 2,
      GuideStep.pickType || GuideStep.pickSeries || GuideStep.pickBudget || GuideStep.submitOptions => 3,
      GuideStep.waitCards => 4,
      GuideStep.pickBudgetChip => 5,
      GuideStep.pickCard => 6,
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
      _begin(GuideStep.tapEntry, replay: false);
    } else if (_status == 'started') {
      _begin(GuideStep.tapEntry, replay: false);
    }
  }

  /// 「我的」页入口手动进：永远从欢迎步重走；已完成的是重玩（不发奖）。
  void startManual() {
    if (active) return;
    _begin(GuideStep.tapEntry, replay: _status == 'done');
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
      // welcome 步已废弃（2026-11-27 hx 点名删欢迎卡：开局直达 tapEntry，
      // 学录屏——没有欢迎弹窗，手直接落在第一个目标上）。枚举值留着防旧存档。
      GuideStep.welcome => GuideStep.tapEntry,
      GuideStep.tapEntry => GuideStep.startPick,
      // startPick 直接进引导自己的三问面板：翻牌推荐卡在引导模式下
      // 不发「帮我翻三张命运牌」（那句话直接抽牌、不问问题，等不到 optionSet）。
      GuideStep.startPick => GuideStep.waitOptions,
      GuideStep.waitOptions => GuideStep.pickAnswer,
      // 以下旧步（自造面板与写死两轮时期）已退役，枚举留着防旧存档，
      // 万一有残留状态一律并入 pickAnswer，不再单独走。
      GuideStep.pickRecipient || GuideStep.pickBudget || GuideStep.submitOptions || GuideStep.waitOptions2 || GuideStep.pickType || GuideStep.pickSeries || GuideStep.submitOptions2 => GuideStep.pickAnswer,
      GuideStep.waitCards => GuideStep.pickBudgetChip,
      GuideStep.pickBudgetChip => GuideStep.pickCard,
      GuideStep.pickCard => GuideStep.flipping,
      // detailIntro（看办事清单步）已删（hx 2026-11-27 点名：落回
      // 聊天后单独指着卡片讲清单没必要）：翻牌落定直达购买步。
      GuideStep.flipping => GuideStep.buyDemo,
      GuideStep.detailIntro => GuideStep.buyDemo,
      GuideStep.buyDemo => GuideStep.done,
      GuideStep.demoSheet => GuideStep.done,
      _ => _step,
    };
    if (next == _step) return;
    _step = next;
    if (next == GuideStep.waitCards || next == GuideStep.waitOptions) {
      waitTimedOut = false;
      waitFailed = false;
      _waitTimer?.cancel();
      // 等谁都一样只等 20 秒：等牌、等两轮问题都是它。到时没等到
      // 就置位 waitTimedOut，气泡给出路（结束引导、奖励照拿），
      // 不让用户干等。旧版 waitOptions 超时会强推到自造三问面板，
      // 改走真实问法后那条兜底已删（2026-11-27 hx 拍板走真实问法）。
      _waitTimer = Timer(const Duration(seconds: 20), () {
        if (_step == next) {
          waitTimedOut = true;
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

  /// 购买步收尾（点「立即购买」时调）：不弹面板、不真下单——小豆
  /// 已经在对话里把地址与下单说清（chat provider 的收尾话），这里
  /// 只把引导跳到恭喜页。detailIntro 也算：全屏详细卡上就有购买
  /// 按钮，用户在那儿点了不能让他走真下单（旧版只认 buyDemo，
  /// 在全屏卡上点会弹出真地址表单，hx 2026-11-27 截图实锤）。
  void finishBuyDemo() {
    if (_step != GuideStep.buyDemo && _step != GuideStep.detailIntro && _step != GuideStep.demoCheckout) return;
    demoOrderPlaced = true;
    _step = GuideStep.done;
    if (!replayMode) unawaited(_saveStatus('done'));
    notifyListeners();
  }

  /// 进演示下单步（点「立即购买」时调）：小豆在对话里一步步办单
  /// （整理券 → 整理地址 → 收尾卡），用户点卡上「去下单」才收尾。
  void beginDemoCheckout() {
    // flipping 也算：全屏卡落定后、飞回之前，引导步还停在 flipping
    // （notifyDetailLanded 要等全屏层关掉才报），这时点的购买必须
    // 在这里接住，不然会漏去走真代买（hx 截图里地址消息重复两条
    // 就是这么来的）。
    if (_step != GuideStep.buyDemo && _step != GuideStep.detailIntro && _step != GuideStep.flipping) return;
    _step = GuideStep.demoCheckout;
    notifyListeners();
  }

  /// 等牌阶段提前收尾（空批次/等太久）：直接进恭喜页，奖励照发——
  /// 不能因为演示数据出问题扣用户奖励（设计稿兜底口径）。
  void completeEarly() {
    if (_step != GuideStep.waitCards && _step != GuideStep.waitOptions && _step != GuideStep.pickAnswer) return;
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

  /// 问题已出现在对话里（小豆页监听到带选项的消息，分组卡与平铺
  /// 按钮都算）：从等待步进到答题步。
  void notifyOptionsReady() {
    if (_step == GuideStep.waitOptions) advance();
  }

  /// 答题步当前要指的目标 id（'guide:chip' 指选项、'guide:submit'
  /// 指提交按钮）：渲染选项的组件算出来报到这里，罩子按它挖孔。
  /// 为什么不写死：小豆问什么、问几轮由它自己定（挑手办只问一轮
  /// 平铺系列、挑礼物才是两轮分组），引导只能看屏幕上真有什么。
  String answerTarget = 'guide:chip';

  void setAnswerTarget(String id) {
    if (answerTarget == id) return;
    answerTarget = id;
    notifyListeners();
  }

  /// 一轮答案交出去了（选项 onPick 触发，分组提交与平铺点选都算）：
  /// 回等待步，看小豆下一个问题还是直接亮牌。
  void notifyAnswered() {
    if (_step == GuideStep.pickAnswer) _enterWait(GuideStep.waitOptions);
  }

  /// 进某个等待步并起 20 秒兜底定时（notifyAnswered 用；
  /// advance() 里进等待步走它自己的那段，两边口径一致）。
  void _enterWait(GuideStep step) {
    _step = step;
    waitTimedOut = false;
    waitFailed = false;
    _waitTimer?.cancel();
    _waitTimer = Timer(const Duration(seconds: 20), () {
      if (_step == step) {
        waitTimedOut = true;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// 等问题期间牌直接亮出来了（用户档案齐全、小豆跳过提问直接抽牌，
  /// 或轮次和预期错位）：从两个等待步直接进选牌步，不让引导干等。
  void notifyCardsReadyFromWait({required bool hasProducts, int? maxPrice}) {
    if (_step != GuideStep.waitOptions && _step != GuideStep.pickAnswer) return;
    if (!hasProducts) return;
    _waitTimer?.cancel();
    // 预算已经是 100（小豆记着偏好、抽牌时就带上了）：「¥100内」
    // 那枚档已经是选中态、点不动，跳过预算步直接选牌。
    _step = maxPrice == 100 ? GuideStep.pickCard : GuideStep.pickBudgetChip;
    notifyListeners();
  }

  /// 亮牌结果到了：有牌进 pickCard；空批次记 waitFailed，气泡给出路。
  void notifyCardsReady({required bool hasProducts, int? maxPrice}) {
    if (_step != GuideStep.waitCards) return;
    if (hasProducts) {
      if (maxPrice == 100) {
        _step = GuideStep.pickCard;
        notifyListeners();
      } else {
        advance();
      }
    } else {
      waitFailed = true;
      notifyListeners();
    }
  }

  /// 预算档「¥100内」被点了（牌面调档组件报的）：进选牌步。
  /// 重抽是异步的，牌板换上新一批后会自己重新登记口碑目标，
  /// 手跟着过去，不用等重抽完。
  void notifyBudgetPicked() {
    if (_step == GuideStep.pickBudgetChip) advance();
  }

  /// 目标牌被点、翻牌演出开始。
  void notifyCardTapped() {
    if (_step == GuideStep.pickCard) advance();
  }

  /// 翻牌落定、详细卡已在对话里亮出。
  void notifyDetailLanded() {
    if (_step == GuideStep.flipping) advance();
  }


}
