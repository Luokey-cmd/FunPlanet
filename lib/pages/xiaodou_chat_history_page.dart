import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/xiaodou_chat_session.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/sparkle_background.dart';

const _uiScale = 1.5;

double _xs(double value) => AppScale.s(value * _uiScale);

class XiaodouChatHistoryPage extends StatefulWidget {
  const XiaodouChatHistoryPage({super.key});

  static Future<bool?> open(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const XiaodouChatHistoryPage()),
    );
  }

  @override
  State<XiaodouChatHistoryPage> createState() => _XiaodouChatHistoryPageState();
}

class _XiaodouChatHistoryPageState extends State<XiaodouChatHistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<XiaodouChatProvider>().refreshHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmClearAll(XiaodouChatProvider chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清空全部记录', style: TextStyle(fontSize: _xs(16))),
        content: Text('确定删除所有与小豆的聊天记录吗？此操作不可恢复。', style: TextStyle(fontSize: _xs(14), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('清空', style: TextStyle(color: AppColors.priceRed)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await chat.clearAllSessions();
      if (!mounted) return;
      showTopSnackBar(context, content: Text('已清空全部记录', style: TextStyle(fontSize: _xs(14), fontWeight: FontWeight.w600)));
    }
  }

  Future<void> _renameSession(XiaodouChatProvider chat, XiaodouChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('重命名对话', style: TextStyle(fontSize: _xs(16))),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '输入对话标题'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await chat.renameSession(session.id, newTitle);
    }
  }

  Future<void> _deleteSession(XiaodouChatProvider chat, XiaodouChatSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除对话', style: TextStyle(fontSize: _xs(16))),
        content: Text('确定删除「${session.title}」吗？', style: TextStyle(fontSize: _xs(14))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.priceRed)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await chat.deleteSession(session.id);
    }
  }

  void _copySession(XiaodouChatProvider chat, XiaodouChatSession session) {
    Clipboard.setData(ClipboardData(text: chat.exportSessionText(session.id)));
    showTopSnackBar(context, content: Text('对话内容已复制', style: TextStyle(fontSize: _xs(14), fontWeight: FontWeight.w600)));
  }

  Future<void> _startNewChat(XiaodouChatProvider chat) async {
    if (chat.sending) return;
    if (!chat.messages.any((m) => m.role == ChatRole.user)) {
      await chat.startNewChat();
      if (mounted) Navigator.pop(context, true);
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
    if (ok == true && mounted) {
      await chat.startNewChat();
      Navigator.pop(context, true);
    }
  }

  Future<void> _resumeSession(XiaodouChatProvider chat, XiaodouChatSession session) async {
    await chat.openSession(session.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();
    final sessions = chat.searchSessions(_query);
    final groups = _groupSessions(sessions);

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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: _xs(22)),
                    ),
                    Expanded(
                      child: Text(
                        '聊天记录',
                        style: TextStyle(fontSize: _xs(17), fontWeight: FontWeight.bold, color: AppColors.foreground),
                      ),
                    ),
                    if (sessions.isNotEmpty)
                      TextButton(
                        onPressed: chat.sending ? null : () => _confirmClearAll(chat),
                        child: Text('清空', style: TextStyle(fontSize: _xs(13), color: AppColors.priceRed)),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _xs(14)),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: '搜索对话标题或内容…',
                  prefixIcon: Icon(Icons.search, size: _xs(20), color: AppColors.mutedForeground),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(Icons.close, size: _xs(18)),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: EdgeInsets.symmetric(vertical: _xs(10)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_xs(14)),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_xs(14)),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(_xs(14), _xs(10), _xs(14), 0),
              child: SizedBox(
                width: double.infinity,
                height: _xs(44),
                child: FilledButton.icon(
                  onPressed: chat.sending ? null : () => _startNewChat(chat),
                  icon: Icon(Icons.add_rounded, size: _xs(20)),
                  label: Text('新建聊天', style: TextStyle(fontSize: _xs(14), fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_xs(14))),
                  ),
                ),
              ),
            ),
            SizedBox(height: _xs(10)),
            Expanded(
              child: sessions.isEmpty
                  ? _EmptyState(hasQuery: _query.isNotEmpty)
                  : ListView(
                      padding: EdgeInsets.fromLTRB(_xs(14), 0, _xs(14), _xs(24)),
                      children: [
                        for (final group in groups) ...[
                          Padding(
                            padding: EdgeInsets.only(top: _xs(14), bottom: _xs(8)),
                            child: Text(
                              group.label,
                              style: TextStyle(fontSize: _xs(12), fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
                            ),
                          ),
                          ...group.sessions.map(
                            (session) => _SessionTile(
                              session: session,
                              isActive: chat.currentSessionId == session.id,
                              onTap: chat.sending ? null : () => _resumeSession(chat, session),
                              onPin: () => chat.togglePin(session.id),
                              onRename: () => _renameSession(chat, session),
                              onCopy: () => _copySession(chat, session),
                              onDelete: () => _deleteSession(chat, session),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_xs(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: _xs(48), color: AppColors.mutedForeground),
            SizedBox(height: _xs(12)),
            Text(
              hasQuery ? '没有找到匹配的对话' : '还没有聊天记录',
              style: TextStyle(fontSize: _xs(15), fontWeight: FontWeight.w600, color: AppColors.foreground),
            ),
            SizedBox(height: _xs(6)),
            Text(
              hasQuery ? '换个关键词试试' : '和小豆聊几句，记录会自动保存在这里',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _xs(13), color: AppColors.mutedForeground, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onPin,
    required this.onRename,
    required this.onCopy,
    required this.onDelete,
  });

  final XiaodouChatSession session;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onPin;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _xs(10)),
      child: Material(
        color: isActive ? AppColors.secondary : AppColors.card,
        borderRadius: BorderRadius.circular(_xs(14)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_xs(14)),
          child: Container(
            padding: EdgeInsets.all(_xs(14)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_xs(14)),
              border: Border.all(color: isActive ? AppColors.primaryLight : AppColors.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (session.pinned)
                            Padding(
                              padding: EdgeInsets.only(right: _xs(4)),
                              child: Icon(Icons.push_pin, size: _xs(14), color: AppColors.primary),
                            ),
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: _xs(15), fontWeight: FontWeight.w600, color: AppColors.foreground),
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: EdgeInsets.only(left: _xs(6)),
                              padding: EdgeInsets.symmetric(horizontal: _xs(8), vertical: _xs(2)),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(_xs(999)),
                              ),
                              child: Text('当前', style: TextStyle(fontSize: _xs(10), color: Colors.white)),
                            ),
                        ],
                      ),
                      SizedBox(height: _xs(6)),
                      Text(
                        session.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: _xs(13), color: AppColors.mutedForeground, height: 1.4),
                      ),
                      SizedBox(height: _xs(8)),
                      Row(
                        children: [
                          Text(_formatTime(session.updatedAt), style: TextStyle(fontSize: _xs(11), color: AppColors.mutedForeground)),
                          SizedBox(width: _xs(10)),
                          Text('${session.messageCount} 条消息', style: TextStyle(fontSize: _xs(11), color: AppColors.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: AppColors.mutedForeground, size: _xs(20)),
                  onSelected: (value) {
                    switch (value) {
                      case 'pin':
                        onPin();
                      case 'rename':
                        onRename();
                      case 'copy':
                        onCopy();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(session.pinned ? '取消置顶' : '置顶对话'),
                    ),
                    const PopupMenuItem(value: 'rename', child: Text('重命名')),
                    const PopupMenuItem(value: 'copy', child: Text('复制全文')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除', style: TextStyle(color: AppColors.priceRed)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionGroup {
  const _SessionGroup({required this.label, required this.sessions});

  final String label;
  final List<XiaodouChatSession> sessions;
}

List<_SessionGroup> _groupSessions(List<XiaodouChatSession> sessions) {
  if (sessions.isEmpty) return [];

  final pinned = sessions.where((s) => s.pinned).toList();
  final rest = sessions.where((s) => !s.pinned).toList();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));

  final groups = <_SessionGroup>[];
  if (pinned.isNotEmpty) {
    groups.add(_SessionGroup(label: '置顶', sessions: pinned));
  }

  void addBucket(String label, bool Function(DateTime dt) match) {
    final bucket = rest.where((s) => match(s.updatedAt)).toList();
    if (bucket.isNotEmpty) groups.add(_SessionGroup(label: label, sessions: bucket));
  }

  addBucket('今天', (dt) => !dt.isBefore(today));
  addBucket('昨天', (dt) => dt.isAfter(yesterday) && dt.isBefore(today));
  addBucket('近 7 天', (dt) => dt.isAfter(weekAgo) && !dt.isAfter(yesterday));
  addBucket('更早', (dt) => !dt.isAfter(weekAgo));

  return groups;
}

String _formatTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(time.year, time.month, time.day);
  final hm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (!date.isBefore(today)) return '今天 $hm';
  if (date == today.subtract(const Duration(days: 1))) return '昨天 $hm';
  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $hm';
}
