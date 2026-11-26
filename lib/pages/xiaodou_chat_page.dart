import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/app_log.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agent_records.dart';
import '../models/chat_message.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/starwish_profile_provider.dart';
import '../providers/user_provider.dart';
import '../providers/xiaodou_chat_provider.dart';
import 'member_benefit_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../data/xiaodou_copy.dart';
import '../pages/xiaodou_chat_history_page.dart';
import '../services/voice_input_service.dart';
import '../services/xiaodou_chat_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/product_image.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/starwish_dossier_sheet.dart';
import '../widgets/xiaodou_agent_card.dart';
import '../widgets/xiaodou_coupon_card.dart';
import '../widgets/xiaodou_fate_section.dart';
import '../widgets/xiaodou_home.dart';
import '../widgets/xiaodou_product_card.dart';

import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_buttons.dart';
import '../widgets/click_effect/app_pressable.dart';
// 2026-11-20 字体规范化：本页尺寸统一走 AppScale（字号 t = 写几号是几号，
// 布局 s = 0.8 倍）。旧版 _xs 自带 1.5 倍私自放大（实际渲染 1.2 倍），
// 与其他页不是一套规矩，已废除；本页整体会比旧版略小一圈，属预期。
double _xs(double value) => AppScale.t(value);

Map<String, dynamic> _archiveOf(BuildContext context) {
  return context.read<StarwishProfileProvider>().profile.toAgentJson();
}

class XiaodouChatPage extends StatefulWidget {
  const XiaodouChatPage({super.key, this.autoDraw = false, this.initialPrompt});

  /// 进来就自动抽一次翻牌（小豆首页「翻牌推荐」卡用）。
  final bool autoDraw;

  /// 进来就替用户问的第一句话（商品详情页「小豆点评」卡用，带着商品名来问）。
  /// 为空时什么都不自动发，和普通进入一致。
  final String? initialPrompt;

  static Future<void> open(BuildContext context, {bool autoDraw = false, String? initialPrompt}) {
    final chat = context.read<XiaodouChatProvider>();
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: chat),
            ChangeNotifierProvider.value(value: context.read<StarwishProfileProvider>()),
          ],
          child: XiaodouChatPage(autoDraw: autoDraw, initialPrompt: initialPrompt),
        ),
      ),
    );
  }

  @override
  State<XiaodouChatPage> createState() => _XiaodouChatPageState();
}

/// 自动抽三翻的定式话术：走现有对话流程，命中抽牌工具的概率最高。
void _drawFateCards(BuildContext context) {
  final chat = context.read<XiaodouChatProvider>();
  if (chat.sending) return;
  chat.send('小豆，帮我翻三张命运牌', starwish: _archiveOf(context));
}

/// 首页区统一发送入口：灵感卡、示例句、路线、快捷行都走这里。
/// 输入：页面 context + 要发出的原文。输出：无返回值，消息直接进当前对话。
/// 坑：发送必须带 starwish 档案且 sending 时拦截，和输入栏保持同一口径；
/// 首页区组件（XiaodouHome）只许调这个回调，不许自己拼发送参数。
void _sendHomeText(BuildContext context, String text) {
  final chat = context.read<XiaodouChatProvider>();
  if (chat.sending) return;
  chat.send(text, starwish: _archiveOf(context));
}

/// 选图（只选不发）：首页区「拍照找同款」卡和输入栏相机按钮共用这一份。
/// 输入：页面 context。输出：选中的图片字节 + mime 类型；取消或失败返回 null。
/// 2026-11-22 改口径：以前选完直接替用户发送、还代写一句「帮我看看店里
/// 有没有同款或同类」，但用户常常只是先放图、想问的是别的事。现在选完
/// 只把图挂到输入栏当附件（见 _InputBarState.setPendingImage），用户可以
/// 继续打字改问题，点发送才连图带字一起走；只有图没字就发，provider
/// 会补默认的找同款文案。
/// 坑：不许再复制一份选图逻辑，两份（大小上限、格式判断）漂移后很难查。
/// await 之后用 context 前必须先判 mounted，页面已关时直接收手。
Future<({Uint8List bytes, String mimeType})?> _pickImageForChat(BuildContext context) async {
  // 必须关掉 compression：file_picker 8.x 默认会 compressImage，
  // 在华为/荣耀上往公共相册目录 createTempFile 会 Permission denied，
  // 异常抛在插件后台线程，直接把整个进程打死（表现为选图确认后退出 App）。
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowCompression: false,
    compressionQuality: 0,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  Uint8List? bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty) && file.path != null && file.path!.isNotEmpty) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (_) {
      bytes = null;
    }
  }
  if (bytes == null || bytes.isEmpty) return null;
  if (!context.mounted) return null;
  if (bytes.lengthInBytes > 4 * 1024 * 1024) {
    showTopSnackBar(
      context,
      content: Text('图片请小于 4MB', style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600)),
    );
    return null;
  }
  final ext = (file.extension ?? '').toLowerCase();
  final mimeType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  return (bytes: Uint8List.fromList(bytes), mimeType: mimeType);
}

class _XiaodouChatPageState extends State<XiaodouChatPage> {
  // 底部真输入框的焦点节点，由页面持有：首页区的大输入框只是视觉入口，
  // 点它要把焦点交给这个节点，用户实际打字仍在底部输入栏里完成。
  // 坑：节点必须在 dispose 里释放，且只能挂给一个输入框，别多处共用。
  final _inputFocusNode = FocusNode();

  /// 选图后挂附件：首页区和输入栏的图片入口都走这里——先选图，
  /// 再经 GlobalKey 交给输入栏挂起来（见 _InputBarState.setPendingImage）。
  /// 输入：无（图从系统相册选）。输出：无返回值，图挂在输入框上方。
  Future<void> _attachPickedImage() async {
    final picked = await _pickImageForChat(context);
    if (picked == null || !mounted) return;
    AppLog.info('小豆', '选好了一张图片，已挂到输入框上方，等用户点发送');
    _inputBarKey.currentState?.setPendingImage(picked.bytes, picked.mimeType);
  }

  // 首页语音胶囊借用输入栏语音逻辑的通道：给输入栏挂这个 Key，
  // 首页点语音 → 页面调输入栏 State 的公开方法 startVoiceInput()。
  // 为什么用 GlobalKey 而不是在首页再封一套：语音服务、聆听状态、目标输入框
  // 只有一个主人，就是底部输入栏；首页另起一套，两边状态必然漂移。
  // 坑：GlobalKey 只能挂一个组件，本页输入栏只出现一次，满足前提；
  // currentState 可能为 null（输入栏还没挂载），调用时必须用 ?. 兜底。
  final _inputBarKey = GlobalKey<_InputBarState>();

  // 是否正在录音（聆听）：主人是输入栏（语音服务在它手里），经
  // onListeningChanged 同步一份到页面——页面这边的录音守卫要用它。
  // 以前状态只锁在输入栏内部，录音时选图、商品卡、菜单照样能点，
  // 点了就会打断或干扰录音（2026-11-23 hx 点名要改）。
  bool _voiceListening = false;

  void _handleVoiceListeningChanged(bool listening) {
    if (!mounted || _voiceListening == listening) return;
    setState(() => _voiceListening = listening);
    // 录音与键盘互斥（2026-11-23 hx 定）：一开录音就收起键盘
    // （unfocus 这步真机已验生效）；录音中点输入框弹不出键盘的
    // 硬保证在输入栏那边——录音时给输入框盖透明罩物理隔断。
    // 这里关 canRequestFocus 只作辅助（挡程序性 requestFocus）：
    // 它在 hx 的荣耀机上实测没拦住手指点击聚焦，不能单独当保证。
    // 坑：unfocus 与关开关两个动作都要做，只关开关时已有的焦点
    // 不一定自动让出，键盘可能赖着不走。
    if (listening) {
      AppLog.info('小豆', '开始录音');
      _inputFocusNode.unfocus();
      _inputFocusNode.canRequestFocus = false;
    } else {
      AppLog.info('小豆', '录音结束');
      _inputFocusNode.canRequestFocus = true;
    }
  }

  /// 录音中点其他按钮（2026-11-23 hx 改口径）：不再拦下弹提示，
  /// 而是先结束录音、再照常执行那个按钮的动作——点哪个按钮，
  /// 录音就为哪个按钮让路。键盘是唯一例外：点输入框不结束录音，
  /// 只是弹不出键盘（见 _handleVoiceListeningChanged 的焦点开关）。
  /// 输入：无。输出：无。停录音经输入栏的公开方法走，聆听状态
  /// 随后由 onListeningChanged 同步回来，这里不等它。
  void _endListeningForAction() {
    if (!_voiceListening) return;
    _inputBarKey.currentState?.stopVoiceInput();
  }

  @override
  void initState() {
    super.initState();
    // 进门盘点：每次打开小豆页都重新盘一遍没办完的事（待付款/将过期券）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<XiaodouChatProvider>().refreshBriefing();
    });
    // 普通进入：什么都不自动做——不再弹星愿档案问卷，首页区就是入口。
    // 只有为抽牌而来（autoDraw）时才保留原来的自动抽三翻。
    if (widget.autoDraw) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        _drawFateCards(context);
      });
      return;
    }
    // 带着问题进来（详情页小豆点评卡）：等页面站稳后替用户把这句问出去，
    // 发送口径和首页区一致（带档案、忙碌时不发），用户也可以不理它自己聊。
    final prompt = widget.initialPrompt?.trim() ?? '';
    if (prompt.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _sendHomeText(context, prompt);
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: _Header(
                onClose: () => Navigator.pop(context),
                // 顶栏菜单四项：录音中点按先结束录音、再照常执行；
                // 返回不拦——按下即离开页面，输入栏 dispose 会停掉
                // 录音，结果与先停再走一致。
                onOpenHistory: () {
                  _endListeningForAction();
                  XiaodouChatHistoryPage.open(context);
                },
                onOpenProfile: () {
                  _endListeningForAction();
                  showStarwishDossierSheet(context);
                },
                onNewChat: () {
                  _endListeningForAction();
                  _startNewChat(context);
                },
              ),
            ),
            Divider(height: _xs(1), color: AppColors.border),
            Expanded(
              child: Stack(
                children: [
                  _MessageList(
                    onDrawFate: () => _drawFateCards(context),
                    onSendText: (text) => _sendHomeText(context, text),
                    onPickImage: _attachPickedImage,
                    onFocusInput: () => _inputFocusNode.requestFocus(),
                    onOpenProfile: () => showStarwishDossierSheet(context),
                    onVoice: () => _inputBarKey.currentState?.startVoiceInput(),
                  ),
                  // 录音收尾罩：录音时在消息区上方盖一层透明罩，
                  // 区内第一下点击（灵感卡、商品卡、星牌、换一批、
                  // 识图选项等）统一被接住、只做一件事——结束录音；
                  // 罩子随聆听状态消失，第二下才点到下面的东西。
                  // 只认 tap、滚动照常（拖动会赢下手势竞争，罩子
                  // 不会把列表弄得滑不动）。
                  if (_voiceListening)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _endListeningForAction,
                      ),
                    ),
                ],
              ),
            ),
            _CartConfirmBar(onActionTap: _endListeningForAction),
            _GuideChips(onActionTap: _endListeningForAction),
            _InputBar(
              key: _inputBarKey,
              focusNode: _inputFocusNode,
              onPickImage: _attachPickedImage,
              onListeningChanged: _handleVoiceListeningChanged,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _startNewChat(BuildContext context) async {
  final chat = context.read<XiaodouChatProvider>();
  if (chat.sending) return;
  // 不再弹确认框（2026-11-23 hx 拍板）：当前对话本来就会自动存进
  // 聊天记录，点「开启新对话」就直接开，少一步摩擦。
  await chat.startNewChat();
}

// 顶栏（第一批瘦身后只剩 4 个元素）：返回、头像、名称区、更多菜单。
// 命运三翻改走首页区灵感卡、历史和偏好都收进 ⋯ 菜单，不再往顶栏上堆按钮——
// 旧版 7 个元素挤一行，副行签名还会被截断成「守瓶…」，是 hx 截图里点名的问题。
class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onNewChat,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_xs(14), _xs(12), _xs(8), _xs(12)),
      child: Row(
        children: [
          AppIconButton(
            onPressed: onClose,
            iconSize: _xs(22),
            icon: Icon(Icons.arrow_back, color: AppColors.foreground),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(_xs(12)),
            child: ProductImage(
              image: FloatingAiAssistant.assetFull,
              width: _xs(40),
              height: _xs(40),
            ),
          ),
          SizedBox(width: _xs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('小豆', style: TextStyle(fontSize: _xs(16) + AppScale.fontBump, fontWeight: FontWeight.bold, color: AppColors.foreground)),
                // 副行写死导购文案，不再读档案签名（signLine）：签名是填完问卷才有的，
                // 没填时显示「守瓶…」既截断又看不懂；这行只负责说清小豆能干什么。
                Text(
                  '说一句，我帮你挑、比、买',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _xs(11) + AppScale.fontBump, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.foreground, size: _xs(22)),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  onOpenHistory();
                case 'profile':
                  onOpenProfile();
                case 'new':
                  onNewChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'history', child: Text('聊天记录')),
              PopupMenuItem(value: 'profile', child: Text('小豆记得你')),
              PopupMenuItem(value: 'new', child: Text('新对话')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.onDrawFate,
    required this.onSendText,
    required this.onPickImage,
    required this.onFocusInput,
    required this.onOpenProfile,
    required this.onVoice,
  });

  // 以下 6 个回调原样透传给首页区（XiaodouHome），含义见聊天页 State 处的注入。
  final VoidCallback onDrawFate;
  final ValueChanged<String> onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onFocusInput;
  final VoidCallback onOpenProfile;
  final VoidCallback onVoice;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastContentLength = 0;
  // 上一帧的键盘高度：用来识别「键盘刚弹起」这一刻，触发滚到底（见 build）。
  double _lastKeyboardInset = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();
    final contentLength = chat.messages.isEmpty ? 0 : chat.messages.last.content.length;
    if (chat.messages.length != _lastMessageCount || contentLength != _lastContentLength) {
      _lastMessageCount = chat.messages.length;
      _lastContentLength = contentLength;
      // 只在真对话进行时自动滚到底：首页区还在时（没有任何用户消息），
      // 进门那条问候语也会让消息数变化，若照样滚底，用户一进门就被
      // 甩到页面最下面、看不到顶部的标题与输入区（2026-11-26 hx 报）。
      // 首页区在场时保持停在顶部，用户自己往下滑。
      if (chat.messages.any((m) => m.role == ChatRole.user)) {
        _scrollToBottom();
      }
    }
    // 键盘弹起时把对话推到键盘上方：页面布局本身会随键盘变矮（输入栏已
    // 经贴在键盘上沿），但列表的滚动位置不会自己动——视口一变矮，最新
    // 回复的下半截就掉出可视区，看着像被键盘挡住（2026-11-26 hx 截图）。
    // 所以键盘从无到有这一刻补一次滚到底，行为与微信等聊天 App 一致。
    // 守卫与上面同一条：首页区还在时（没发过消息）不滚，进门仍停在顶部。
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset != _lastKeyboardInset) {
      final keyboardOpened = keyboardInset > _lastKeyboardInset;
      _lastKeyboardInset = keyboardInset;
      if (keyboardOpened && chat.messages.any((m) => m.role == ChatRole.user)) {
        _scrollToBottom();
        // 键盘弹出动画约 300ms、视口是逐帧变矮的，第一下滚到的不是
        // 最终底部；等动画落定再补滚一次，保证停在真正的最后一行。
        Future.delayed(const Duration(milliseconds: 320), () {
          if (mounted) _scrollToBottom();
        });
      }
    }
    // 首页区显隐只看一条规则：对话里还没有任何用户消息就显示，发第一句后整体消失。
    // 历史会话打开时已有用户消息，天然不显示，不用另写分支。
    final showHome = !chat.messages.any((m) => m.role == ChatRole.user);

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.45)),
          trackColor: WidgetStateProperty.all(AppColors.border.withValues(alpha: 0.35)),
          trackBorderColor: WidgetStateProperty.all(Colors.transparent),
          thickness: WidgetStateProperty.all(_xs(3)),
          radius: Radius.circular(_xs(4)),
          crossAxisMargin: _xs(2),
        ),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: _xs(3),
        radius: Radius.circular(_xs(4)),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(_xs(14), _xs(14), _xs(10), _xs(14)),
          // 首页区占列表第 0 项时，总数 +1、消息下标整体后移一位。
          // 坑（本批最容易出 bug 的一处）：下面取消息必须用换算后的 msgIndex，
          // 直接拿 index 取会错位一条、推荐按钮的判定也会跟着错。
          itemCount: chat.messages.length + (showHome ? 1 : 0),
          itemBuilder: (context, index) {
            if (showHome && index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 进门盘点（长记性）：有没办完的事才出声，没事不占地方。
                  if (chat.briefingMatters.isNotEmpty && !chat.briefingDismissed)
                    _BriefingBanner(
                      matters: chat.briefingMatters,
                      onDismiss: chat.dismissBriefing,
                      onOpenOrder: () => openAgentActionTarget(
                        context,
                        const AgentAction(
                          id: 'briefing-order',
                          type: 'briefing',
                          title: '',
                          detail: '',
                          status: 'done',
                          target: {'page': 'order'},
                        ),
                      ),
                      onOpenCoupons: () => openAgentActionTarget(
                        context,
                        const AgentAction(
                          id: 'briefing-coupons',
                          type: 'briefing',
                          title: '',
                          detail: '',
                          status: 'done',
                          target: {'page': 'coupons'},
                        ),
                      ),
                    ),
                  XiaodouHome(
                onDrawFate: widget.onDrawFate,
                onSendText: widget.onSendText,
                onPickImage: widget.onPickImage,
                onFocusInput: widget.onFocusInput,
                onOpenProfile: widget.onOpenProfile,
                onVoice: widget.onVoice,
                  ),
                ],
              );
            }
            final msgIndex = showHome ? index - 1 : index;
            final message = chat.messages[msgIndex];
            final showRecommend = message.hasProducts &&
                !chat.messages.skip(msgIndex + 1).any((item) => item.hasProducts);
            return _MessageBubble(message: message, msgIndex: msgIndex, showRecommendActions: showRecommend);
          },
        ),
      ),
    );
  }
}

/// 清单卡里点「确认下单」：走订单原有的支付接口，付成后把清单
/// 那条翻成已办好；付不成把原因如实弹给用户，订单仍是待付款、
/// 可以去订单页再付。返回是否付成（卡片据此收起付款闸）。
Future<bool> _payAgentOrder(BuildContext context, int msgIndex, AgentAction action) async {
  final orderId = action.target['id'];
  if (orderId == null || orderId.isEmpty) return false;
  try {
    await context.read<OrderProvider>().payOrder(orderId);
    if (!context.mounted) return true;
    context.read<XiaodouChatProvider>().markActionPaid(msgIndex, action.id);
    showTopSnackBar(
      context,
      content: Text(
        '付款成功，订单备货中',
        style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      showTopSnackBar(
        context,
        backgroundColor: const Color(0xFFDC2626),
        content: Text(
          '付款没成：${e.toString().replaceFirst('Exception: ', '')}',
          style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    }
    return false;
  }
}

// 思考直播只看尾巴：全文可能很长，气泡里滚动显示最后一段即可，
// 用户要的是「它在动、在想」，不是把思考全文摊开。
String _thinkingTail(String thinking) {
  const maxChars = 240;
  if (thinking.length <= maxChars) return thinking;
  return '…${thinking.substring(thinking.length - maxChars)}';
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.msgIndex, this.showRecommendActions = false});

  final ChatMessage message;

  /// 这条消息在会话里的下标（不是列表下标，首页占位时差一位，
  /// 由列表构建处换算好传进来）；亮牌翻页与清单付款都按它定位。
  final int msgIndex;
  final bool showRecommendActions;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final chat = context.watch<XiaodouChatProvider>();
    final sending = chat.sending;
    // 正在生成中的就是会话里最后一条助手消息：它没说完之前，
    // 气泡尾巴要挂会动的省略号（问题四，2026-11-23 hx 报）。
    final isStreamingTail = !isUser && sending && msgIndex == chat.messages.length - 1;
    // 提问选项只挂在最后一条消息上：对话往下走了，旧问题的选项
    // 不再冒出来挡路。
    final isLastMessage = msgIndex == chat.messages.length - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: _xs(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(_xs(999)),
              child: ProductImage(
                image: FloatingAiAssistant.assetFull,
                width: _xs(28),
                height: _xs(28),
              ),
            ),
            SizedBox(width: _xs(8)),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(10)),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_xs(14)),
                  topRight: Radius.circular(_xs(14)),
                  bottomLeft: Radius.circular(isUser ? _xs(14) : _xs(4)),
                  bottomRight: Radius.circular(isUser ? _xs(4) : _xs(14)),
                ),
              ),
              child: message.isLoading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _xs(14),
                              height: _xs(14),
                              child: CircularProgressIndicator(
                                strokeWidth: _xs(2),
                                color: isUser ? Colors.white : AppColors.primary,
                              ),
                            ),
                            SizedBox(width: _xs(8)),
                            Text(
                              // 有思考在流时，状态行固定说「思考中…」，
                              // 具体内容看下面滚动的思考原文。
                              message.thinking.isNotEmpty ? '思考中…' : message.content,
                              style: TextStyle(fontSize: _xs(13) + AppScale.fontBump, color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                        if (message.thinking.isNotEmpty) ...[
                          SizedBox(height: _xs(6)),
                          Text(
                            _thinkingTail(message.thinking),
                            style: TextStyle(
                              fontSize: _xs(12) + AppScale.fontBump,
                              height: 1.45,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.thinking.isNotEmpty) ...[
                          Text(
                            message.thinking,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _xs(12) + AppScale.fontBump,
                              height: 1.45,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          if (message.content.trim().isNotEmpty) SizedBox(height: _xs(8)),
                        ],
                        if (message.hasImage) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(_xs(10)),
                            child: Image.memory(
                              message.imageBytes!,
                              width: _xs(168),
                              height: _xs(168),
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (message.content.trim().isNotEmpty) SizedBox(height: _xs(8)),
                        ],
                        if (message.content.trim().isNotEmpty)
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: _xs(14) + AppScale.fontBump,
                              height: 1.45,
                              color: isUser ? Colors.white : AppColors.foreground,
                            ),
                          ),
                        if (message.awaitVisionChoice) _VisionChoice(message: message, enabled: !sending),
                        // 功课段排在亮牌/商品上方（hx 2026-11-23 口径：先亮功课
                        // 再亮牌）；办事段还在下方，所以清单卡拆成两张渲染——
                        // XiaodouAgentCard 对空段自动不画，上方只传功课、下方
                        // 只传办事，互不影响。
                        if (message.homework.isNotEmpty)
                          XiaodouAgentCard(
                            homework: message.homework,
                            actions: const [],
                            onTarget: (action) => openAgentActionTarget(context, action),
                            onPay: (action) => _payAgentOrder(context, msgIndex, action),
                          ),
                        if (message.hasProducts) ...[
                          if (message.isFate)
                            XiaodouFateSection(
                              message: message,
                              loadingBatch: context.watch<XiaodouChatProvider>().isBatchLoading(msgIndex),
                              onPrev: () => context
                                  .read<XiaodouChatProvider>()
                                  .setFateBatchIndex(msgIndex, message.fateIndex - 1),
                              onNext: () {
                                final chat = context.read<XiaodouChatProvider>();
                                final batchCount = message.fateBatches.isNotEmpty
                                    ? message.fateBatches.length
                                    : 1;
                                if (message.fateIndex < batchCount - 1) {
                                  chat.setFateBatchIndex(msgIndex, message.fateIndex + 1);
                                } else {
                                  chat.nextFateBatch(msgIndex);
                                }
                              },
                              onRefilter: ({int? maxPrice, String? sort}) => context
                                  .read<XiaodouChatProvider>()
                                  .refilterFate(msgIndex, maxPrice: maxPrice, sort: sort),
                            )
                          else ...[
                            ...message.products.map((product) => XiaodouProductCard(product: product)),
                            if (showRecommendActions) _RecommendActions(enabled: !sending),
                          ],
                        ],
                        if (message.giftNote != null && message.giftNote!.isNotEmpty)
                          _GiftNote(text: message.giftNote!),
                        if (message.actions.isNotEmpty)
                          XiaodouAgentCard(
                            homework: const [],
                            actions: message.actions,
                            onTarget: (action) => openAgentActionTarget(context, action),
                            onPay: (action) => _payAgentOrder(context, msgIndex, action),
                          ),
                        // 可领券清单卡（找优惠时下发）：只列不代领，
                        // 每行一个领取按钮，点了才真领这一组。
                        if (message.couponChoices.isNotEmpty)
                          XiaodouCouponCard(
                            choices: message.couponChoices,
                            onClaim: (choice) async {
                              final ok = await context
                                  .read<XiaodouChatProvider>()
                                  .claimCouponChoice(msgIndex, choice.group);
                              if (ok && context.mounted) {
                                context.read<UserProvider>().refreshProfileFromRemote();
                              }
                            },
                            onMember: () => MemberBenefitPage.open(context, MemberBenefitKind.monthlyCoupon),
                          ),
                        // 提问选项：小豆问了问题、服务端随信给了短回答
                        // 选项时，气泡下挂一排按钮，点一下就替用户把
                        // 这句发出去（hx 2026-11-23 定，省得打字）。
                        // 分组选项（挑礼物两步问法）优先渲染成分组多选。
                        if (message.optionSet != null && !message.optionsUsed && isLastMessage && !sending)
                          _GroupedQuestionOptions(
                            optionSet: message.optionSet!,
                            onPick: (text) =>
                                context.read<XiaodouChatProvider>().chooseOption(msgIndex, text),
                          )
                        else if (message.options.isNotEmpty && !message.optionsUsed && isLastMessage && !sending)
                          _QuestionOptions(
                            options: message.options,
                            onPick: (text) =>
                                context.read<XiaodouChatProvider>().chooseOption(msgIndex, text),
                          ),
                        // 说了一半停住（在想下一段、查工具、联网搜）时
                        // 最容易被误以为已经说完——尾巴挂上会动的省略号，
                        // 流一结束就自动消失。
                        if (isStreamingTail) const _TypingDots(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 进门盘点卡（长记性）：小豆进门先替用户盘一遍没办完的事——
/// 待付款订单、快过期的券，每条带一个能直接去办的按钮；点叉关掉
/// 就不再打扰。没事时这张卡根本不出现，不许拿它刷存在感。
class _BriefingBanner extends StatelessWidget {
  const _BriefingBanner({
    required this.matters,
    required this.onDismiss,
    required this.onOpenOrder,
    required this.onOpenCoupons,
  });

  final List<BriefingMatter> matters;
  final VoidCallback onDismiss;
  final VoidCallback onOpenOrder;
  final VoidCallback onOpenCoupons;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: _xs(12)),
      padding: EdgeInsets.fromLTRB(_xs(14), _xs(10), _xs(8), _xs(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(_xs(14)),
        border: Border.all(color: const Color(0xFFE8CF9A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '先帮你盘了盘，有几件事还没办完',
                  style: TextStyle(
                    fontSize: _xs(13) + AppScale.fontBump,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              AppIconButton(
                onPressed: onDismiss,
                iconSize: _xs(16),
                icon: Icon(Icons.close, color: AppColors.mutedForeground),
              ),
            ],
          ),
          for (final matter in matters) _row(matter),
        ],
      ),
    );
  }

  Widget _row(BriefingMatter matter) {
    final isOrder = matter.isPendingOrder;
    final expire = matter.expireAt?.toLocal();
    final text = isOrder
        ? '订单还没付款：${matter.summary} · 应付 ${formatYuan(matter.total)}'
        : '「${matter.title}」${matter.condition}，'
            '${expire == null ? '快到期了' : '${expire.month}月${expire.day}日到期'}，别浪费';
    return Padding(
      padding: EdgeInsets.only(top: _xs(6)),
      child: Row(
        children: [
          Icon(
            isOrder ? Icons.receipt_long_outlined : Icons.local_offer_outlined,
            size: _xs(16),
            color: const Color(0xFFB98A2F),
          ),
          SizedBox(width: _xs(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: _xs(12) + AppScale.fontBump,
                color: AppColors.foreground,
              ),
            ),
          ),
          TextButton(
            onPressed: isOrder ? onOpenOrder : onOpenCoupons,
            child: Text(isOrder ? '去付款' : '去看看'),
          ),
        ],
      ),
    );
  }
}

/// 会动的省略号：三个小点错峰呼吸（相位各差 1/3 圈），表示
/// 「还在想、还在写，后面还有」。只在流式生成中出现，组件
/// 销毁时停掉动画控制器，别留野动画（问题四）。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _xs(8)),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: _xs(4)),
                Opacity(
                  opacity: 0.25 + 0.75 * (0.5 + 0.5 * math.sin((_controller.value - i / 3) * 2 * math.pi)),
                  child: Container(
                    width: _xs(6),
                    height: _xs(6),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GiftNote extends StatelessWidget {
  const _GiftNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: _xs(10)),
      padding: EdgeInsets.all(_xs(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(_xs(10)),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        '礼赠寄语\n$text',
        style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, height: 1.45, color: AppColors.foreground),
      ),
    );
  }
}

class _VisionChoice extends StatelessWidget {
  const _VisionChoice({required this.message, required this.enabled});

  final ChatMessage message;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _xs(10)),
      child: Wrap(
        spacing: _xs(8),
        runSpacing: _xs(8),
        children: [
          _chip(context, XiaodouCopy.visionSame),
          _chip(context, XiaodouCopy.visionVibe),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return GestureDetector(
      onTap: enabled
          ? () => context.read<XiaodouChatProvider>().send(
                label,
                starwish: _archiveOf(context),
                vision: message.visionPayload,
              )
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_xs(999)),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// 提问选项按钮排：照 _VisionChoice 的胶囊样式，文字换成服务端随
/// 问题下发的短回答；点哪个就把哪个当用户回复发出去，整组随即撤掉。
class _QuestionOptions extends StatelessWidget {
  const _QuestionOptions({required this.options, required this.onPick});

  final List<String> options;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _xs(10)),
      child: Wrap(
        spacing: _xs(8),
        runSpacing: _xs(8),
        children: [
          for (final option in options)
            GestureDetector(
              onTap: () => onPick(option),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(_xs(999)),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: _xs(12) + AppScale.fontBump,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 分组提问选项（挑礼物两步问法，2026-11-26 hx 定）：
/// · mode=each（送给谁+预算）：每组点一个，两组都选齐后「选好了」
///   按钮点亮，点它把两个答案拼成一句发出去；
/// · mode=multi（类型+系列）：每组最多选一个、两组共选 1~2 个，
///   选满或只选一个都行，点提交按钮发送；
/// · anyOption（你帮我定）：单独一颗，点它直接发送、不等选组。
/// 选中态是实心紫，未选是白底紫边（与单组 _QuestionOptions 同款）。
class _GroupedQuestionOptions extends StatefulWidget {
  const _GroupedQuestionOptions({required this.optionSet, required this.onPick});

  final XiaodouOptionSet optionSet;
  final ValueChanged<String> onPick;

  @override
  State<_GroupedQuestionOptions> createState() => _GroupedQuestionOptionsState();
}

class _GroupedQuestionOptionsState extends State<_GroupedQuestionOptions> {
  // 组下标 -> 选中的选项文字；每组最多一个（点同组另一个自动换选，
  // 再点已选的取消）。each 靠「每组都有」判齐，multi 靠总数判 1~2。
  final Map<int, String> _picked = {};

  bool get _isEach => widget.optionSet.mode == 'each';

  bool get _canSubmit {
    if (_isEach) return _picked.length == widget.optionSet.groups.length;
    return _picked.isNotEmpty && _picked.length <= 2;
  }

  void _toggle(int groupIndex, String option) {
    setState(() {
      if (_picked[groupIndex] == option) {
        _picked.remove(groupIndex);
      } else {
        // multi 总数上限 2：已选满两组时，点未选组的选项不响应
        // （同组内换选不受限，因为总数不变）。
        if (!_isEach && !_picked.containsKey(groupIndex) && _picked.length >= 2) return;
        _picked[groupIndex] = option;
      }
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final parts = <String>[
      for (var i = 0; i < widget.optionSet.groups.length; i++)
        if (_picked[i] != null) _picked[i]!,
    ];
    widget.onPick(parts.join('，'));
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.optionSet;
    return Padding(
      padding: EdgeInsets.only(top: _xs(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < set.groups.length; i++) ...[
            Text(
              set.groups[i].label,
              style: TextStyle(
                fontSize: _xs(11) + AppScale.fontBump,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            SizedBox(height: _xs(6)),
            Wrap(
              spacing: _xs(8),
              runSpacing: _xs(8),
              children: [
                for (final option in set.groups[i].options)
                  GestureDetector(
                    onTap: () => _toggle(i, option),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
                      decoration: BoxDecoration(
                        color: _picked[i] == option ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(_xs(999)),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: _xs(12) + AppScale.fontBump,
                          fontWeight: FontWeight.w600,
                          color: _picked[i] == option ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: _xs(10)),
          ],
          Row(
            children: [
              GestureDetector(
                onTap: _canSubmit ? _submit : null,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: _xs(16), vertical: _xs(8)),
                  decoration: BoxDecoration(
                    color: _canSubmit ? AppColors.primary : AppColors.muted,
                    borderRadius: BorderRadius.circular(_xs(999)),
                  ),
                  child: Text(
                    _isEach ? '选好了' : '就这样，帮我挑',
                    style: TextStyle(
                      fontSize: _xs(12) + AppScale.fontBump,
                      fontWeight: FontWeight.w700,
                      color: _canSubmit ? Colors.white : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              if (set.anyOption != null) ...[
                SizedBox(width: _xs(8)),
                GestureDetector(
                  onTap: () => widget.onPick(set.anyOption!),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(_xs(999)),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Text(
                      set.anyOption!,
                      style: TextStyle(
                        fontSize: _xs(12) + AppScale.fontBump,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
              if (!_isEach) ...[
                SizedBox(width: _xs(8)),
                Text(
                  '选 1~2 个',
                  style: TextStyle(
                    fontSize: _xs(11) + AppScale.fontBump,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendActions extends StatelessWidget {
  const _RecommendActions({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _xs(10)),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => context.read<XiaodouChatProvider>().requestAnotherBatch() : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: _xs(8)),
              ),
              child: Text('换一批', style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: _xs(8)),
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => context.read<XiaodouChatProvider>().requestSimilar() : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.foreground,
                padding: EdgeInsets.symmetric(vertical: _xs(8)),
              ),
              child: Text('看同类', style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartConfirmBar extends StatelessWidget {
  const _CartConfirmBar({required this.onActionTap});

  /// 按钮被点时先喊一声（页面传进来）：录音中会先结束录音，
  /// 然后按钮动作照常执行；没在录音时是空操作。
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();
    final pending = chat.pendingCartProducts;
    if (pending.isEmpty) return const SizedBox.shrink();
    final names = pending.map((p) => p.name).join('、');

    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: EdgeInsets.fromLTRB(_xs(12), _xs(10), _xs(12), _xs(4)),
      child: Container(
        padding: EdgeInsets.all(_xs(10)),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(_xs(12)),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              XiaodouCopy.confirmCart,
              style: TextStyle(fontSize: _xs(13) + AppScale.fontBump, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: _xs(4)),
            Text(
              names,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, color: AppColors.mutedForeground),
            ),
            SizedBox(height: _xs(8)),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    onPressed: () {
                      onActionTap();
                      chat.clearPendingCart();
                    },
                    child: Text('取消', style: TextStyle(fontSize: _xs(12) + AppScale.fontBump)),
                  ),
                ),
                SizedBox(width: _xs(8)),
                Expanded(
                  child: AppFilledButton(
                    onPressed: () {
                      onActionTap();
                      final cart = context.read<CartProvider>();
                      for (final product in pending) {
                        cart.addItem(product);
                      }
                      chat.clearPendingCart();
                      showTopSnackBar(
                        context,
                        content: Text('已放进旅途背包', style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600)),
                      );
                    },
                    child: Text('放进背包', style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, fontWeight: FontWeight.w600)),
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

class _GuideChips extends StatelessWidget {
  const _GuideChips({required this.onActionTap});

  /// 词条被点时先喊一声（页面传进来）：录音中会先结束录音，
  /// 然后这条快捷话照常发出去；没在录音时是空操作。
  final VoidCallback onActionTap;

  // 快捷词（第二批换词，2026-11-23 hx 对着千问定的形态）：学淘宝
  // 闪购那排——按钮上只放 2~4 字的场景名配小图标，是「入口」不是
  // 「例句」；点下去发的话也短，场景名本身就是一句完整需求。
  // 六个入口各通一种导购动作：找优惠（领券办事）、挑手办（手办
  // 直挑）、挑礼物（送礼流程）、翻三张牌（亮牌）、本周热卖（销量
  // 搜）、50 元内（预算搜）。
  // （第一批的「点亮星签」是旧问卷入口，早已删掉，别再加回来。）
  static const _chips = <(IconData, String, String)>[
    (Icons.local_offer_outlined, '找优惠', '找优惠'),
    (Icons.toys_outlined, '挑手办', '帮我挑手办'),
    (Icons.card_giftcard, '挑礼物', '帮我挑礼物'),
    (Icons.style_outlined, '翻牌推荐', '翻三张牌'),
    (Icons.whatshot_outlined, '本周热卖', '本周热卖'),
    (Icons.savings_outlined, '平价好物', '50元内好物'),
  ];

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();
    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: EdgeInsets.fromLTRB(_xs(12), _xs(8), _xs(12), _xs(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _chips.length; i++) ...[
              if (i > 0) SizedBox(width: _xs(8)),
              AppPressable(
                enabled: !chat.sending,
                child: GestureDetector(
                  onTap: chat.sending
                      ? null
                      : () {
                          onActionTap();
                          chat.send(_chips[i].$3, starwish: _archiveOf(context));
                        },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(_xs(999)),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_chips[i].$1, size: _xs(14), color: AppColors.primary),
                        SizedBox(width: _xs(4)),
                        Text(
                          _chips[i].$2,
                          style: TextStyle(
                            fontSize: _xs(12) + AppScale.fontBump,
                            color: AppColors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 聆听中麦克风图标的呼吸脉动：录音时图标若一动不动，用户会怀疑
// 到底录没录（hx 2026-11-22 真机反馈）。这里让红色声波图标自己
// 一缩一放地动——不读真实音量，纯循环动画，900ms 一个来回；
// 停录时本组件直接不在树上，控制器随之释放，不留后台开销。
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon({required this.size});

  final double size;

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset('assets/images/icon_xd_mic_on.png', width: widget.size, height: widget.size),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    super.key,
    required this.focusNode,
    required this.onPickImage,
    this.onListeningChanged,
  });

  /// 聊天页持有的焦点节点：首页区大输入框靠它把焦点引到这里（见页面 State 注释）。
  final FocusNode focusNode;

  /// 选图动作走页面层级的共用函数（_pickImageForChat），这里不再自备一份。
  final VoidCallback onPickImage;

  /// 聆听状态往页面同步一份：页面的录音守卫（拦其他按钮）要用，
  /// 状态主人仍是本栏，页面只读不写。
  final ValueChanged<bool>? onListeningChanged;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _inputController = TextEditingController();

  // 语音输入（手机系统识别）：服务全页只有这一份，首页胶囊经 GlobalKey
  // 也调到这里开听——识别文字的目标输入框在这里，主人只能是输入栏。
  final VoiceInputService _voice = VoiceInputService();

  // 是否正在聆听：决定麦克风图标颜色和输入框提示文案。
  // 只认语音服务的回调，不在点击里乐观乱改：说满时长、停顿收尾、出错，
  // 插件都会自己停，UI 必须跟着回调切回来，否则会留一个假装在听的状态。
  bool _listening = false;

  // 本段语音开听前，输入框里已有的文字。识别结果是「本段累计文字」，
  // 每次回调用「这段底子 + 本段累计」整体重写输入框，中间结果才会
  // 原地变长，而不是每来一句就往后新拼一段、越拼越乱。
  String _voiceBaseText = '';

  @override
  void dispose() {
    // 页面关了不能还占着麦克风；dispose 里不能 await，直接调用收口即可。
    _voice.stopListening();
    _inputController.dispose();
    super.dispose();
  }

  // 待发送的图片附件：选图后先挂在这里（输入框上方有预览），
  // 用户可以继续打字改问题，点发送才连图带字一起发出（2026-11-22 改）。
  // 只有图没字直接发也行，provider 会补「找同款」的默认文案。
  Uint8List? _pendingImageBytes;
  String? _pendingMimeType;

  /// 挂上一张待发送图片（公开方法）：首页区选图经页面 GlobalKey 调进来，
  /// 和语音的 startVoiceInput 一个路数。挂上后把焦点给输入框，
  /// 邀请用户补一句想问的——不补也能直接发。
  void setPendingImage(Uint8List bytes, String mimeType) {
    if (!mounted) return;
    setState(() {
      _pendingImageBytes = bytes;
      _pendingMimeType = mimeType;
    });
    widget.focusNode.requestFocus();
  }

  void _clearPendingImage() {
    if (_pendingImageBytes == null) return;
    setState(() {
      _pendingImageBytes = null;
      _pendingMimeType = null;
    });
  }

  // 聆听状态的唯一写入口：本地 UI 与通知页面必须同一步调，
  // 漏掉哪一处，页面那边的录音守卫就会认错状态（该拦的没拦、
  // 不该拦的乱拦）。所有改 _listening 的地方都走这里。
  void _setListening(bool listening) {
    if (!mounted) return;
    if (_listening != listening) {
      setState(() => _listening = listening);
    }
    widget.onListeningChanged?.call(listening);
  }

  /// 输入栏内部按钮的录音口径（与页面同一个，2026-11-23 hx 定）：
  /// 录音中点发送/选图/移除附件，先结束录音、再照常执行那个动作。
  /// 输出：true = 刚结束了一段录音。发送必须 await 它——结束录音
  /// 会把最后一段识别定稿进输入框，等落定再读文字，发出去的
  /// 才是完整一句话（旧口径是直接拦下不许发，已被 hx 改掉）。
  Future<bool> _endListeningForAction() async {
    if (!_listening) return false;
    await _voice.stopListening();
    return true;
  }

  /// 结束录音（公开方法）：页面那边「录音中点了其他按钮」时经
  /// GlobalKey 调进来，先把录音收尾。只停录音，不动输入框里
  /// 已识别的文字——接下来是发送还是改字，都接着这份文字走。
  Future<void> stopVoiceInput() async {
    if (!_listening) return;
    await _voice.stopListening();
  }

  Future<void> _send(XiaodouChatProvider chat) async {
    await _endListeningForAction();
    if (!mounted) return;
    final text = _inputController.text;
    final imageBytes = _pendingImageBytes;
    final mimeType = _pendingMimeType;
    // 没字又没图才拦；只有图没字也放行，provider 会补默认文案。
    if ((text.trim().isEmpty && imageBytes == null) || chat.sending) return;
    _inputController.clear();
    _clearPendingImage();
    chat.send(text, imageBytes: imageBytes, mimeType: mimeType, starwish: _archiveOf(context));
  }

  /// 语音输入开关（公开方法）：本栏麦克风按钮和首页语音胶囊共用这一个入口，
  /// 首页那边是经页面持有的 GlobalKey 调进来的，所以方法不能带下划线。
  /// 输入：无，文字来自系统识别。输出：无返回值，识别文字只落进输入框，
  /// 绝不自动发送——用户看一眼再自己点发送，这是定死的口径。
  /// 行为：没在听 → 先体检（服务可用？有麦克风权限？）再开听；正在听 → 停。
  /// 坑：sending 时直接收手，和本栏其他按钮一致；体检三态里「不可用」和
  /// 「没权限」是两回事，必须给两句不同的提示，别混成一句让用户白忙。
  Future<void> startVoiceInput() async {
    // 整段包 try：插件/系统识别在部分国产机上会抛平台异常，
    // 绝不能让未捕获异常把页面甚至进程打崩。
    try {
      if (_listening) {
        await _voice.stopListening();
        return;
      }
      final chat = context.read<XiaodouChatProvider>();
      if (chat.sending) return;
      final availability = await _voice.prepare();
      if (!mounted) return;
      if (availability == VoiceAvailability.unavailable) {
        _voiceSnack('这台手机的自带语音识别不可用，可以先打字');
        return;
      }
      if (availability == VoiceAvailability.permissionDenied) {
        _voiceSnack('还没给麦克风权限，允许后就能说话输入；也可以先打字');
        return;
      }
      _voiceBaseText = _inputController.text;
      final started = await _voice.startListening(
        onResult: _handleVoiceResult,
        onListeningChanged: _handleListeningChanged,
        onError: _handleVoiceError,
      );
      if (!mounted) return;
      if (!started) {
        _voiceSnack('这台手机的自带语音识别不可用，可以先打字');
        _setListening(false);
        return;
      }
      // 聆听态以回调为准。Android Intent 弹窗在 await 返回时已结束；
      // iOS 连续听写若回调稍慢，这里用服务状态补一次。
      if (!_listening && _voice.isListening) {
        _setListening(true);
      }
    } catch (_) {
      if (!mounted) return;
      _setListening(false);
      _voiceSnack('语音识别暂时不可用，可以先打字');
    }
  }

  // 识别结果回调：words 是本段累计文字（中间结果越来越完整），
  // 用「底子 + 累计」整体重写输入框、光标钉在末尾；最终结果到达后把底子
  // 更新成全文，这样用户紧接着再说一段时，两段顺接而不是互相覆盖。
  void _handleVoiceResult(String words, bool isFinal) {
    if (!mounted) return;
    final merged = _voiceBaseText + words;
    _inputController.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );
    if (isFinal) _voiceBaseText = merged;
  }

  // 聆听状态回调：图标和提示文案只认这里的通知（理由见 _listening 注释）。
  void _handleListeningChanged(bool listening) {
    _setListening(listening);
  }

  // 识别出错回调：权限类错误给权限口径，其余诚实收口提示重试或打字。
  // 状态切回由服务的 onListeningChanged(false) 负责，这里只管提示文案。
  void _handleVoiceError(String errorCode) {
    if (!mounted) return;
    if (errorCode.contains('permission')) {
      _voiceSnack('还没给麦克风权限，允许后就能说话输入；也可以先打字');
    } else if (errorCode.contains('unavailable') || errorCode.contains('record')) {
      _voiceSnack('语音识别暂时不可用，可以先打字');
    } else {
      _voiceSnack('语音识别没听清，可以再说一次或先打字');
    }
  }

  void _voiceSnack(String message) {
    showTopSnackBar(
      context,
      content: Text(message, style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final chat = context.watch<XiaodouChatProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(_xs(12), _xs(8), _xs(12), _xs(12)),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          color: AppColors.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingImageBytes != null)
              Padding(
                padding: EdgeInsets.only(left: _xs(4), bottom: _xs(8)),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(_xs(10)),
                          child: Image.memory(_pendingImageBytes!, width: _xs(56), height: _xs(56), fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              await _endListeningForAction();
                              if (!mounted) return;
                              _clearPendingImage();
                            },
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: EdgeInsets.all(_xs(2)),
                              child: Icon(Icons.close, size: _xs(12), color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: _xs(8)),
                    Expanded(
                      child: Text(
                        '图片先放这儿，想问什么打在下面；什么都不打直接发，就是帮你找同款。',
                        style: TextStyle(fontSize: _xs(11) + AppScale.fontBump, color: AppColors.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                AppIconButton(
                  onPressed: chat.sending
                      ? null
                      : () async {
                          // 录音中点选图：先结束录音、再照常开相册
                          // （旧口径是拦下不许选，hx 2026-11-23 改的）。
                          await _endListeningForAction();
                          if (!mounted) return;
                          widget.onPickImage();
                        },
              iconSize: _xs(22),
              tooltip: '拍图找同款',
              icon: Image.asset('assets/images/icon_xd_image.png', width: _xs(27), height: _xs(27)),
            ),
            SizedBox(width: _xs(4)),
            AppIconButton(
              onPressed: chat.sending ? null : () => startVoiceInput(),
              iconSize: _xs(22),
              tooltip: _listening ? '停止语音输入' : '语音输入',
              // 定制图标：聆听中用红色声波版并带呼吸脉动（_PulsingMicIcon），
              // 和「正在录」的常识对齐；加上输入框提示文案的变化，
              // 用户一眼能确认状态。
              icon: _listening
                  ? _PulsingMicIcon(size: _xs(27))
                  : Image.asset('assets/images/icon_xd_mic.png', width: _xs(27), height: _xs(27)),
            ),
            SizedBox(width: _xs(4)),
            Expanded(
              child: Stack(
                children: [
                  AppTextField(
                    controller: _inputController,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(fontSize: _xs(14) + AppScale.fontBump),
                    textInputAction: TextInputAction.send,
                    onSubmitted: chat.sending ? null : (_) => _send(chat),
                    decoration: InputDecoration(
                      hintText: _listening ? '正在听…说完再点一下麦克风' : '说你想要的…',
                      hintStyle: TextStyle(fontSize: _xs(14) + AppScale.fontBump, color: AppColors.mutedForeground),
                      filled: true,
                      fillColor: AppColors.muted,
                      contentPadding: EdgeInsets.symmetric(horizontal: _xs(14), vertical: _xs(10)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_xs(999)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  // 录音中给输入框盖一层透明罩：点输入框的手势全被
                  // 罩子吃掉，输入框根本收不到点击，键盘绝无可能弹
                  // 起，录音也不受影响（hx 的口径：点输入框不结束
                  // 录音、只是弹不出键盘）。为什么不用焦点开关做
                  // 硬保证：canRequestFocus 在 hx 的荣耀机上实测没
                  // 拦住点击聚焦（2026-11-23 真机回报），罩子是物
                  // 理隔断，不挑机型不挑版本。罩子只盖输入框本身，
                  // 麦克风/发送/选图按钮各有各的让路逻辑、不受影响。
                  if (_listening)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: _xs(8)),
            AppFilledButton(
              onPressed: chat.sending ? null : () => _send(chat),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(_xs(44), _xs(44)),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_xs(999))),
              ),
              child: Icon(Icons.send_rounded, size: _xs(18), color: Colors.white),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }
}
