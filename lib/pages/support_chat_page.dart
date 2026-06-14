import 'package:file_picker/file_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/support_stickers.dart';
import '../models/support_message.dart';
import '../providers/support_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../utils/media_url.dart';
import '../widgets/sparkle_background.dart';
import 'image_preview_page.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  static void openGeneral(BuildContext context) {
    final provider = context.read<SupportChatProvider>();
    unawaited(provider.openGeneral());
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SupportChatPage(),
        ),
      ),
    );
  }

  static void openForProduct(
    BuildContext context, {
    required String productId,
    required String productName,
  }) {
    final provider = context.read<SupportChatProvider>();
    unawaited(provider.openForProduct(productId: productId, productName: productName));
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SupportChatPage(),
        ),
      ),
    );
  }

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  int _lastCount = 0;
  bool _showStickers = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
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

  void _send(SupportChatProvider chat) {
    FocusScope.of(context).unfocus();
    final text = _inputController.text;
    if (text.trim().isEmpty || chat.sending) return;
    _inputController.clear();
    setState(() => _showStickers = false);
    chat.send(text);
  }

  Future<void> _pickImage(SupportChatProvider chat) async {
    if (chat.sending) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    setState(() => _showStickers = false);
    await chat.sendImage(bytes, mimeType);
  }

  void _insertEmoji(String stickerId) {
    final sticker = findSupportSticker(stickerId);
    if (sticker == null) return;

    final controller = _inputController;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final emoji = sticker.emoji;
    final newText = text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<SupportChatProvider>();
    if (chat.messages.length != _lastCount) {
      _lastCount = chat.messages.length;
      _scrollToBottom();
    }

    final subtitle = chat.conversation?.productName != null
        ? '商品咨询 · ${chat.conversation!.productName}'
        : '在线人工客服 · 工作时间 9:00-22:00';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: _Header(
                subtitle: subtitle,
                onClose: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: chat.loading
                  ? const Center(child: CircularProgressIndicator())
                  : chat.error != null && chat.messages.isEmpty
                      ? _ErrorState(message: chat.error!)
                      : _MessageList(
                          controller: _scrollController,
                          messages: chat.messages,
                        ),
            ),
            if (_showStickers)
              _StickerPanel(
                onPick: _insertEmoji,
              ),
            _InputBar(
              controller: _inputController,
              sending: chat.sending,
              stickersOpen: _showStickers,
              onToggleStickers: chat.sending
                  ? null
                  : () => setState(() {
                        _showStickers = !_showStickers;
                        if (_showStickers) FocusScope.of(context).unfocus();
                      }),
              onPickImage: chat.sending ? null : () => _pickImage(chat),
              onSend: () => _send(chat),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.onClose});

  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(8), FeaturePageStyle.s(8), FeaturePageStyle.s(4), FeaturePageStyle.s(8)),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: FeaturePageStyle.iconSize),
          ),
          Container(
            width: FeaturePageStyle.s(48),
            height: FeaturePageStyle.s(48),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
            ),
            child: Icon(Icons.headset_mic_rounded, color: Colors.white, size: FeaturePageStyle.iconSize),
          ),
          SizedBox(width: FeaturePageStyle.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('趣玩客服', style: FeaturePageStyle.pageTitle()),
                Text(
                  subtitle,
                  style: FeaturePageStyle.secondary(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(FeaturePageStyle.s(24)),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: FeaturePageStyle.empty().copyWith(height: 1.5),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.controller, required this.messages});

  final ScrollController controller;
  final List<SupportMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(FeaturePageStyle.s(24)),
          child: Text(
            '您好，我是趣玩星球客服，有什么可以帮您？',
            textAlign: TextAlign.center,
            style: FeaturePageStyle.empty().copyWith(height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.all(FeaturePageStyle.s(16)),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.senderRole == SupportSenderRole.user;

    return Padding(
      padding: EdgeInsets.only(bottom: FeaturePageStyle.s(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: FeaturePageStyle.s(40),
              height: FeaturePageStyle.s(40),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(FeaturePageStyle.s(999)),
              ),
              child: Icon(Icons.support_agent, size: FeaturePageStyle.s(22), color: Colors.white),
            ),
            SizedBox(width: FeaturePageStyle.s(10)),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: message.messageType == SupportMessageType.sticker ? FeaturePageStyle.s(8) : FeaturePageStyle.s(14),
                vertical: message.messageType == SupportMessageType.sticker ? FeaturePageStyle.s(6) : FeaturePageStyle.s(12),
              ),
              decoration: BoxDecoration(
                color: message.messageType == SupportMessageType.sticker
                    ? Colors.transparent
                    : (isUser ? AppColors.primary : AppColors.muted),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(FeaturePageStyle.s(16)),
                  topRight: Radius.circular(FeaturePageStyle.s(16)),
                  bottomLeft: Radius.circular(isUser ? FeaturePageStyle.s(16) : FeaturePageStyle.s(4)),
                  bottomRight: Radius.circular(isUser ? FeaturePageStyle.s(4) : FeaturePageStyle.s(16)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.messageType != SupportMessageType.sticker)
                    Text(message.senderName ?? '趣玩客服', style: FeaturePageStyle.caption()),
                  _MessageContent(message: message, isUser: isUser),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.isUser});

  final SupportMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    switch (message.messageType) {
      case SupportMessageType.image:
        return _ChatImage(mediaUrl: message.mediaUrl);
      case SupportMessageType.sticker:
        final emoji = findSupportSticker(message.stickerId)?.emoji ?? message.content;
        return Text(emoji, style: TextStyle(fontSize: FeaturePageStyle.s(48), height: 1.1));
      case SupportMessageType.text:
        return Text(
          message.content,
          style: FeaturePageStyle.body(
            color: isUser ? Colors.white : AppColors.foreground,
          ),
        );
    }
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    if (mediaUrl == null || mediaUrl!.isEmpty) {
      return Text('[图片]', style: FeaturePageStyle.body(color: AppColors.mutedForeground));
    }

    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(mediaUrl),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: FeaturePageStyle.s(140),
            height: FeaturePageStyle.s(105),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
          child: GestureDetector(
            onTap: () => _openImagePreview(context, snapshot.data!),
            child: Image.network(
              snapshot.data!,
              width: FeaturePageStyle.s(220),
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: FeaturePageStyle.s(140),
                  height: FeaturePageStyle.s(105),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (_, __, ___) => Text(
                '[图片加载失败]',
                style: FeaturePageStyle.secondary(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImagePreview(BuildContext context, String url) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) {
          final size = MediaQuery.sizeOf(ctx);
          return ImagePreviewPage(
            backgroundColor: Colors.black,
            closeIconColor: Colors.white,
            child: Image.network(
              url,
              width: size.width,
              height: size.height,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
              },
              errorBuilder: (_, __, ___) => Text(
                '图片加载失败',
                style: FeaturePageStyle.body(color: Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StickerPanel extends StatelessWidget {
  const _StickerPanel({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: FeaturePageStyle.s(210),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GridView.builder(
        padding: EdgeInsets.all(FeaturePageStyle.s(14)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: FeaturePageStyle.s(10),
          crossAxisSpacing: FeaturePageStyle.s(10),
        ),
        itemCount: supportStickers.length,
        itemBuilder: (context, index) {
          final sticker = supportStickers[index];
          return Material(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
            child: InkWell(
              onTap: () => onPick(sticker.id),
              borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
              child: Center(
                child: Text(sticker.emoji, style: TextStyle(fontSize: FeaturePageStyle.s(34))),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.stickersOpen,
    required this.onSend,
    this.onToggleStickers,
    this.onPickImage,
  });

  final TextEditingController controller;
  final bool sending;
  final bool stickersOpen;
  final VoidCallback onSend;
  final VoidCallback? onToggleStickers;
  final VoidCallback? onPickImage;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(12), FeaturePageStyle.s(10), FeaturePageStyle.s(12), FeaturePageStyle.s(14)),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          color: AppColors.card,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: sending ? null : onPickImage,
              icon: Icon(Icons.image_outlined, size: FeaturePageStyle.iconSize, color: AppColors.primary),
              tooltip: '发送图片',
            ),
            IconButton(
              onPressed: sending ? null : onToggleStickers,
              icon: Icon(
                stickersOpen ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                size: FeaturePageStyle.iconSize,
                color: stickersOpen ? AppColors.foreground : AppColors.primary,
              ),
              tooltip: stickersOpen ? '键盘' : '表情',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                enabled: !sending,
                keyboardType: TextInputType.multiline,
                style: FeaturePageStyle.body(),
                textInputAction: TextInputAction.send,
                onSubmitted: sending ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '描述您的问题…',
                  hintStyle: FeaturePageStyle.secondary(),
                  filled: true,
                  fillColor: AppColors.muted,
                  contentPadding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(16), vertical: FeaturePageStyle.s(14)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FeaturePageStyle.s(999)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: FeaturePageStyle.s(10)),
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(FeaturePageStyle.buttonHeight, FeaturePageStyle.buttonHeight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FeaturePageStyle.s(999))),
              ),
              child: Icon(Icons.send_rounded, size: FeaturePageStyle.s(22), color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
