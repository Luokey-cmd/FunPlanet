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
import '../utils/snackbar_utils.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/product_image.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/starwish_dossier_sheet.dart';
import '../widgets/xiaodou_fate_cards.dart';
import '../widgets/xiaodou_product_card.dart';

import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_buttons.dart';
import '../widgets/click_effect/app_pressable.dart';
const _uiScale = 1.5;

double _xs(double value) => AppScale.s(value * _uiScale);

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

class _XiaodouChatPageState extends State<XiaodouChatPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.autoDraw) {
        // 为抽牌而来：这次不弹星愿档案，稍等半拍直接抽。
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        _drawFateCards(context);
        return;
      }
      if (!context.read<StarwishProfileProvider>().isComplete) {
        showStarwishDossierSheet(context);
      }
    });
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
                onNewChat: () => _startNewChat(context),
                onCopyChat: () => _copyCurrentChat(context),
                onDrawFate: () => _drawFateCards(context),
              ),
            ),
            Divider(height: _xs(1), color: AppColors.border),
            const Expanded(child: _MessageList()),
            const _CartConfirmBar(),
            const _GuideChips(),
            const _InputBar(),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.onOpenHistory,
    required this.onNewChat,
    required this.onCopyChat,
    required this.onDrawFate,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenHistory;
  final VoidCallback onNewChat;
  final VoidCallback onCopyChat;
  final VoidCallback onDrawFate;

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
                Text(
                  context.watch<StarwishProfileProvider>().profile.signLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _xs(11) + AppScale.fontBump, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final sending = context.watch<XiaodouChatProvider>().sending;
              return AppPressable(
                enabled: !sending,
                child: GestureDetector(
                  onTap: sending ? null : onDrawFate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: _xs(9), vertical: _xs(5)),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(_xs(999)),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Text(
                      '✦ 命运三翻',
                      style: TextStyle(
                        fontSize: _xs(9) + AppScale.fontBump,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryForeground,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AppIconButton(
            onPressed: () => showStarwishDossierSheet(context),
            iconSize: _xs(22),
            tooltip: '星愿档案',
            icon: Icon(Icons.auto_awesome, color: AppColors.gold),
          ),
          AppIconButton(
            onPressed: onOpenHistory,
            iconSize: _xs(22),
            tooltip: '聊天记录',
            icon: Icon(Icons.history_rounded, color: AppColors.foreground),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.foreground, size: _xs(22)),
            onSelected: (value) {
              switch (value) {
                case 'new':
                  onNewChat();
                case 'copy':
                  onCopyChat();
              }
            },
            itemBuilder: (context) => const [
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
  const _MessageList();

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
          itemCount: chat.messages.length,
          itemBuilder: (context, index) {
            final message = chat.messages[index];
            final showRecommend = message.hasProducts &&
                !chat.messages.skip(index + 1).any((item) => item.hasProducts);
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

  static const _chips = [
    '点亮星签',
    '帮我挑礼物',
    '50元内小夜灯',
    '谷子推荐',
  ];

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();
    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: EdgeInsets.fromLTRB(_xs(12), _xs(8), _xs(12), 0),
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
                          if (_chips[i] == '点亮星签') {
                            showStarwishDossierSheet(context);
                            return;
                          }
                          chat.send(_chips[i], starwish: _archiveOf(context));
                        },
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
  const _InputBar();

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _send(XiaodouChatProvider chat) {
    final text = _inputController.text;
    if (text.trim().isEmpty || chat.sending) return;
    _inputController.clear();
    chat.send(text, starwish: _archiveOf(context));
  }

  Future<void> _pickImage(XiaodouChatProvider chat) async {
    if (chat.sending) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (!mounted) return;
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
              onPressed: chat.sending ? null : () => _pickImage(chat),
              iconSize: _xs(22),
              tooltip: '拍图找同款',
              icon: Icon(Icons.photo_outlined, color: AppColors.foreground),
            ),
            SizedBox(width: _xs(4)),
            Expanded(
              child: AppTextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(fontSize: _xs(14) + AppScale.fontBump),
                textInputAction: TextInputAction.send,
                onSubmitted: chat.sending ? null : (_) => _send(chat),
                decoration: InputDecoration(
                  hintText: '说说今晚想寻什么，或让光落进瓶子',
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
