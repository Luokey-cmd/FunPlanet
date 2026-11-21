import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/cart_provider.dart';
import '../providers/starwish_profile_provider.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../data/xiaodou_copy.dart';
import '../pages/xiaodou_chat_history_page.dart';
import '../services/voice_input_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/product_image.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/starwish_dossier_sheet.dart';
import '../widgets/xiaodou_fate_cards.dart';
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
  const XiaodouChatPage({super.key, this.autoDraw = false});

  /// 进来就自动抽一次命运三翻（今日星签的「再翻三张」和标题栏按钮用）。
  final bool autoDraw;

  static Future<void> open(BuildContext context, {bool autoDraw = false}) {
    final chat = context.read<XiaodouChatProvider>();
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: chat),
            ChangeNotifierProvider.value(value: context.read<StarwishProfileProvider>()),
          ],
          child: XiaodouChatPage(autoDraw: autoDraw),
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

/// 选图找同款：首页区「拍照找同款」卡和输入栏相机按钮共用这一份。
/// 输入：页面 context。输出：无返回值，选中的图直接作为一条消息发进对话。
/// 坑：原来这是输入栏的私有方法，首页区也要用才提出来共用——不许再复制一份，
/// 两份选图逻辑（大小上限、格式判断）漂移后很难查。await 之后用 context 前
/// 必须先判 mounted，页面已关时直接收手。
Future<void> _pickImageForChat(BuildContext context) async {
  final chat = context.read<XiaodouChatProvider>();
  if (chat.sending) return;
  // 必须关掉 compression：file_picker 8.x 默认会 compressImage，
  // 在华为/荣耀上往公共相册目录 createTempFile 会 Permission denied，
  // 异常抛在插件后台线程，直接把整个进程打死（表现为选图确认后退出 App）。
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowCompression: false,
    compressionQuality: 0,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  Uint8List? bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty) && file.path != null && file.path!.isNotEmpty) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (_) {
      bytes = null;
    }
  }
  if (bytes == null || bytes.isEmpty) return;
  if (!context.mounted) return;
  if (bytes.lengthInBytes > 4 * 1024 * 1024) {
    showTopSnackBar(
      context,
      content: Text('图片请小于 4MB', style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600)),
    );
    return;
  }
  final ext = (file.extension ?? '').toLowerCase();
  final mimeType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  final archive = _archiveOf(context);
  await chat.send('帮我看看店里有没有同款或同类', imageBytes: Uint8List.fromList(bytes), mimeType: mimeType, starwish: archive);
}

class _XiaodouChatPageState extends State<XiaodouChatPage> {
  // 底部真输入框的焦点节点，由页面持有：首页区的大输入框只是视觉入口，
  // 点它要把焦点交给这个节点，用户实际打字仍在底部输入栏里完成。
  // 坑：节点必须在 dispose 里释放，且只能挂给一个输入框，别多处共用。
  final _inputFocusNode = FocusNode();

  // 首页语音胶囊借用输入栏语音逻辑的通道：给输入栏挂这个 Key，
  // 首页点语音 → 页面调输入栏 State 的公开方法 startVoiceInput()。
  // 为什么用 GlobalKey 而不是在首页再封一套：语音服务、聆听状态、目标输入框
  // 只有一个主人，就是底部输入栏；首页另起一套，两边状态必然漂移。
  // 坑：GlobalKey 只能挂一个组件，本页输入栏只出现一次，满足前提；
  // currentState 可能为 null（输入栏还没挂载），调用时必须用 ?. 兜底。
  final _inputBarKey = GlobalKey<_InputBarState>();

  @override
  void initState() {
    super.initState();
    // 普通进入：什么都不自动做——不再弹星愿档案问卷，首页区就是入口。
    // 只有为抽牌而来（autoDraw）时才保留原来的自动抽三翻。
    if (!widget.autoDraw) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _drawFateCards(context);
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
                onOpenHistory: () => XiaodouChatHistoryPage.open(context),
                onOpenProfile: () => showStarwishDossierSheet(context),
                onNewChat: () => _startNewChat(context),
                onCopyChat: () => _copyCurrentChat(context),
              ),
            ),
            Divider(height: _xs(1), color: AppColors.border),
            Expanded(
              child: _MessageList(
                onDrawFate: () => _drawFateCards(context),
                onSendText: (text) => _sendHomeText(context, text),
                onPickImage: () => _pickImageForChat(context),
                onFocusInput: () => _inputFocusNode.requestFocus(),
                onOpenProfile: () => showStarwishDossierSheet(context),
                onVoice: () => _inputBarKey.currentState?.startVoiceInput(),
              ),
            ),
            const _CartConfirmBar(),
            const _GuideChips(),
            _InputBar(
              key: _inputBarKey,
              focusNode: _inputFocusNode,
              onPickImage: () => _pickImageForChat(context),
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
  if (!chat.messages.any((m) => m.role == ChatRole.user)) {
    await chat.startNewChat();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('开始新对话', style: TextStyle(fontSize: _xs(16) + AppScale.fontBump)),
      content: Text('当前对话会自动保存到聊天记录，确定开始新对话吗？', style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, height: 1.5)),
      actions: [
        AppTextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        AppTextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await chat.startNewChat();
  }
}

void _copyCurrentChat(BuildContext context) {
  final chat = context.read<XiaodouChatProvider>();
  Clipboard.setData(ClipboardData(text: chat.exportCurrentChatText()));
  showTopSnackBar(context, content: Text('当前对话已复制', style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600)));
}

// 顶栏（第一批瘦身后只剩 4 个元素）：返回、头像、名称区、更多菜单。
// 命运三翻改走首页区灵感卡、历史和偏好都收进 ⋯ 菜单，不再往顶栏上堆按钮——
// 旧版 7 个元素挤一行，副行签名还会被截断成「守瓶…」，是 hz 截图里点名的问题。
class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onNewChat,
    required this.onCopyChat,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final VoidCallback onNewChat;
  final VoidCallback onCopyChat;

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
                case 'copy':
                  onCopyChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'history', child: Text('聊天记录')),
              PopupMenuItem(value: 'profile', child: Text('小豆记得你')),
              PopupMenuItem(value: 'new', child: Text('新对话')),
              PopupMenuItem(value: 'copy', child: Text('复制当前对话')),
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
      _scrollToBottom();
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
              return XiaodouHome(
                onDrawFate: widget.onDrawFate,
                onSendText: widget.onSendText,
                onPickImage: widget.onPickImage,
                onFocusInput: widget.onFocusInput,
                onOpenProfile: widget.onOpenProfile,
                onVoice: widget.onVoice,
              );
            }
            final msgIndex = showHome ? index - 1 : index;
            final message = chat.messages[msgIndex];
            final showRecommend = message.hasProducts &&
                !chat.messages.skip(msgIndex + 1).any((item) => item.hasProducts);
            return _MessageBubble(message: message, showRecommendActions: showRecommend);
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.showRecommendActions = false});

  final ChatMessage message;
  final bool showRecommendActions;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final sending = context.watch<XiaodouChatProvider>().sending;

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
                  ? Row(
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
                          message.content,
                          style: TextStyle(fontSize: _xs(13) + AppScale.fontBump, color: AppColors.mutedForeground),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (message.hasProducts) ...[
                          if (message.isFate)
                            XiaodouFateBoard(products: message.products, roles: message.starRoles)
                          else ...[
                            ...message.products.map((product) => XiaodouProductCard(product: product)),
                            if (showRecommendActions) _RecommendActions(enabled: !sending),
                          ],
                        ],
                        if (message.giftNote != null && message.giftNote!.isNotEmpty)
                          _GiftNote(text: message.giftNote!),
                      ],
                    ),
            ),
          ),
        ],
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
  const _CartConfirmBar();

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
                    onPressed: chat.clearPendingCart,
                    child: Text('取消', style: TextStyle(fontSize: _xs(12) + AppScale.fontBump)),
                  ),
                ),
                SizedBox(width: _xs(8)),
                Expanded(
                  child: AppFilledButton(
                    onPressed: () {
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
  const _GuideChips();

  // 快捷词（第一批换词）：删掉「点亮星签」——它原来打开星愿档案问卷弹层，
  // 是旧问卷的另一个入口，必须一并断掉；偏好改从 ⋯ 菜单「小豆记得你」进。
  static const _chips = [
    '帮我挑礼物',
    '50元内小夜灯',
    '给同担的生日礼物',
    '今天有什么优惠',
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
                      : () => chat.send(_chips[i], starwish: _archiveOf(context)),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(7)),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(_xs(999)),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _chips[i],
                      style: TextStyle(
                        fontSize: _xs(12) + AppScale.fontBump,
                        color: AppColors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
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

class _InputBar extends StatefulWidget {
  const _InputBar({super.key, required this.focusNode, required this.onPickImage});

  /// 聊天页持有的焦点节点：首页区大输入框靠它把焦点引到这里（见页面 State 注释）。
  final FocusNode focusNode;

  /// 选图动作走页面层级的共用函数（_pickImageForChat），这里不再自备一份。
  final VoidCallback onPickImage;

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

  void _send(XiaodouChatProvider chat) {
    final text = _inputController.text;
    if (text.trim().isEmpty || chat.sending) return;
    _inputController.clear();
    chat.send(text, starwish: _archiveOf(context));
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
        setState(() => _listening = false);
        return;
      }
      // 聆听态以回调为准。Android Intent 弹窗在 await 返回时已结束；
      // iOS 连续听写若回调稍慢，这里用服务状态补一次。
      if (!_listening && _voice.isListening) {
        setState(() => _listening = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _listening = false);
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
    if (!mounted || _listening == listening) return;
    setState(() => _listening = listening);
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
        child: Row(
          children: [
            AppIconButton(
              onPressed: chat.sending ? null : widget.onPickImage,
              iconSize: _xs(22),
              tooltip: '拍图找同款',
              icon: Image.asset('assets/images/icon_xd_image.png', width: _xs(27), height: _xs(27)),
            ),
            SizedBox(width: _xs(4)),
            AppIconButton(
              onPressed: chat.sending ? null : () => startVoiceInput(),
              iconSize: _xs(22),
              tooltip: _listening ? '停止语音输入' : '语音输入',
              // 定制图标：聆听中用红色声波版，和「正在录」的常识对齐，
              // 加上输入框提示文案的变化，用户一眼能确认状态。
              icon: Image.asset(
                _listening ? 'assets/images/icon_xd_mic_on.png' : 'assets/images/icon_xd_mic.png',
                width: _xs(27),
                height: _xs(27),
              ),
            ),
            SizedBox(width: _xs(4)),
            Expanded(
              child: AppTextField(
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
      ),
    );
  }
}
