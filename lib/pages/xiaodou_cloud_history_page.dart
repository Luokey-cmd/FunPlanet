import 'package:flutter/material.dart';

import '../services/xiaodou_chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/sparkle_background.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_buttons.dart';

const _uiScale = 1.5;

double _xs(double value) => AppScale.s(value * _uiScale);

// 小豆「云端记录」：服务端在每次聊天时自动存的会话备份。
// 和聊天记录页里的本地记录是两套：本地的能继续聊、能改名删除；
// 云端这份只读，价值在于换手机、重装 App 后登录同一账号还能翻到以前聊过什么。
// 入口在聊天记录页右上角的云朵图标。
class XiaodouCloudHistoryPage extends StatefulWidget {
  const XiaodouCloudHistoryPage({super.key});

  static void open(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const XiaodouCloudHistoryPage()),
    );
  }

  @override
  State<XiaodouCloudHistoryPage> createState() => _XiaodouCloudHistoryPageState();
}

class _XiaodouCloudHistoryPageState extends State<XiaodouCloudHistoryPage> {
  final _service = XiaodouChatService();
  late Future<List<CloudChatConversation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchCloudConversations();
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(_xs(4), _xs(4), _xs(8), _xs(8)),
                child: Row(
                  children: [
                    AppIconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: _xs(22)),
                    ),
                    Expanded(
                      child: Text(
                        '云端记录',
                        style: TextStyle(fontSize: _xs(17) + AppScale.fontBump, fontWeight: FontWeight.bold, color: AppColors.foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(_xs(14), 0, _xs(14), _xs(8)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '这是小豆在云端自动保存的聊天备份，只读查看，换设备登录同一账号也能看到。',
                  style: TextStyle(fontSize: _xs(12) + AppScale.fontBump, color: AppColors.mutedForeground, height: 1.5),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CloudChatConversation>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snapshot.hasError) {
                    return _CenterTip(text: '云端记录加载失败\n${snapshot.error}', onRetry: () {
                      setState(() => _future = _service.fetchCloudConversations());
                    });
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return const _CenterTip(text: '还没有云端记录\n和小豆聊过之后，这里会自动出现备份');
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(_xs(14), _xs(4), _xs(14), _xs(24)),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => SizedBox(height: _xs(10)),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return AppGestureDetector(
                        onTap: () => _CloudConversationPage.open(context, item),
                        child: Container(
                          padding: EdgeInsets.all(_xs(12)),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(_xs(14)),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_outlined, size: _xs(20), color: AppColors.primary),
                              SizedBox(width: _xs(10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: _xs(14) + AppScale.fontBump, fontWeight: FontWeight.w600, color: AppColors.foreground),
                                    ),
                                    SizedBox(height: _xs(3)),
                                    Text(
                                      '${item.messageCount} 条消息 · ${_formatTime(item.updatedAt)}',
                                      style: TextStyle(fontSize: _xs(11) + AppScale.fontBump, color: AppColors.mutedForeground),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: _xs(18), color: AppColors.mutedForeground),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 云端会话详情：只读气泡列表，用户在右、小豆在左，不带任何输入框。
class _CloudConversationPage extends StatefulWidget {
  const _CloudConversationPage({required this.conversation});

  final CloudChatConversation conversation;

  static void open(BuildContext context, CloudChatConversation conversation) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _CloudConversationPage(conversation: conversation)),
    );
  }

  @override
  State<_CloudConversationPage> createState() => _CloudConversationPageState();
}

class _CloudConversationPageState extends State<_CloudConversationPage> {
  final _service = XiaodouChatService();
  late Future<List<CloudChatMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchCloudConversation(widget.conversation.id);
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(_xs(4), _xs(4), _xs(8), _xs(8)),
                child: Row(
                  children: [
                    AppIconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: _xs(22)),
                    ),
                    Expanded(
                      child: Text(
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: _xs(17) + AppScale.fontBump, fontWeight: FontWeight.bold, color: AppColors.foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CloudChatMessage>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snapshot.hasError) {
                    return _CenterTip(text: '消息加载失败\n${snapshot.error}', onRetry: () {
                      setState(() => _future = _service.fetchCloudConversation(widget.conversation.id));
                    });
                  }
                  final messages = (snapshot.data ?? []).where((m) => m.content.trim().isNotEmpty).toList();
                  if (messages.isEmpty) {
                    return const _CenterTip(text: '这段会话没有文字消息');
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(_xs(14), _xs(8), _xs(14), _xs(24)),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUser = message.isUser;
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(bottom: _xs(10)),
                          padding: EdgeInsets.symmetric(horizontal: _xs(12), vertical: _xs(9)),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(_xs(14)),
                            border: isUser ? null : Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              fontSize: _xs(13) + AppScale.fontBump,
                              height: 1.5,
                              color: isUser ? Colors.white : AppColors.foreground,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterTip extends StatelessWidget {
  const _CenterTip({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_xs(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _xs(13) + AppScale.fontBump, color: AppColors.mutedForeground, height: 1.6),
            ),
            if (onRetry != null) ...[
              SizedBox(height: _xs(12)),
              AppTextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
