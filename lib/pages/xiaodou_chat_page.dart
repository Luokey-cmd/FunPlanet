import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../pages/xiaodou_chat_history_page.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/product_image.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/xiaodou_product_card.dart';

const _uiScale = 1.5;

double _xs(double value) => AppScale.s(value * _uiScale);

class XiaodouChatPage extends StatelessWidget {
  const XiaodouChatPage({super.key});

  static Future<void> open(BuildContext context) {
    final chat = context.read<XiaodouChatProvider>();
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: chat,
          child: const XiaodouChatPage(),
        ),
      ),
    );
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
              ),
            ),
            Divider(height: _xs(1), color: AppColors.border),
            const Expanded(child: _MessageList()),
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
      title: Text('开始新对话', style: TextStyle(fontSize: _xs(16))),
      content: Text('当前对话会自动保存到聊天记录，确定开始新对话吗？', style: TextStyle(fontSize: _xs(14), height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
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
  showTopSnackBar(context, content: Text('当前对话已复制', style: TextStyle(fontSize: _xs(14), fontWeight: FontWeight.w600)));
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.onOpenHistory,
    required this.onNewChat,
    required this.onCopyChat,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenHistory;
  final VoidCallback onNewChat;
  final VoidCallback onCopyChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_xs(14), _xs(12), _xs(8), _xs(12)),
      child: Row(
        children: [
          IconButton(
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
                Text('小豆', style: TextStyle(fontSize: _xs(16), fontWeight: FontWeight.bold, color: AppColors.foreground)),
                Text(
                  '趣玩星球 · App 答疑助手',
                  style: TextStyle(fontSize: _xs(11), color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          IconButton(
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
          itemBuilder: (context, index) => _MessageBubble(message: chat.messages[index]),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

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
                          style: TextStyle(fontSize: _xs(13), color: AppColors.mutedForeground),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.content.trim().isNotEmpty)
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: _xs(14),
                              height: 1.45,
                              color: isUser ? Colors.white : AppColors.foreground,
                            ),
                          ),
                        if (message.hasProducts)
                          ...message.products.map((product) => XiaodouProductCard(product: product)),
                      ],
                    ),
            ),
          ),
        ],
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
    chat.send(text);
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
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(fontSize: _xs(14)),
                textInputAction: TextInputAction.send,
                onSubmitted: chat.sending ? null : (_) => _send(chat),
                decoration: InputDecoration(
                  hintText: '问问小豆…',
                  hintStyle: TextStyle(fontSize: _xs(14), color: AppColors.mutedForeground),
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
            FilledButton(
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
