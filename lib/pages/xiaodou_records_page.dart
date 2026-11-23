import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agent_records.dart';
import '../models/chat_message.dart';
import '../providers/xiaodou_chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/xiaodou_agent_card.dart';

/// 小豆办事记录（汇总页）：把历次对话里的办事清单按时间倒序摊开，
/// 一轮对话一张卡——哪天、办了几件、省了多少，点条目跳去对应页面改。
/// 数据只来自手机本地的聊天记录（清单本来就只存本地），不查服务端。
class XiaodouRecordsPage extends StatelessWidget {
  const XiaodouRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<XiaodouChatProvider>();

    // 收集带清单的消息：已存的会话 + 当前会话（若还没落进会话列表）
    final entries = <({DateTime date, String title, ChatMessage message})>[];
    final seenSessions = <String>{};
    for (final session in chat.sessions) {
      seenSessions.add(session.id);
      for (final message in session.messages) {
        if (message.actions.isNotEmpty) {
          entries.add((date: session.updatedAt, title: session.title, message: message));
        }
      }
    }
    if (chat.currentSessionId != null && !seenSessions.contains(chat.currentSessionId)) {
      for (final message in chat.messages) {
        if (message.actions.isNotEmpty) {
          entries.add((date: DateTime.now(), title: '当前对话', message: message));
        }
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('小豆办事记录', style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(AppScale.s(32)),
                child: Text(
                  '还没有办事记录。\n你让小豆办过事（领券、加购、下单）之后，会记在这里。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppScale.t(13), height: 1.6, color: AppColors.mutedForeground),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(AppScale.s(14)),
              itemCount: entries.length,
              itemBuilder: (context, i) => _RecordCard(entry: entries[i]),
            ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({required this.entry});

  final ({DateTime date, String title, ChatMessage message}) entry;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final actions = widget.entry.message.actions;
    final doneCount = actions.where((a) => a.status == 'done').length;
    final savedTotal = actions.fold<double>(0, (sum, a) => sum + a.saved);
    final d = widget.entry.date;
    final dateText =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: AppScale.s(10)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppScale.s(12)),
            child: Padding(
              padding: EdgeInsets.all(AppScale.s(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: AppScale.t(13),
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        SizedBox(height: AppScale.s(2)),
                        Text(
                          '办了 ${actions.length} 件事 · 已办好 $doneCount 件${savedTotal > 0 ? ' · 共省 ${formatYuan(savedTotal)}' : ''}',
                          style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: AppScale.s(18),
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.only(left: AppScale.s(12), right: AppScale.s(12), bottom: AppScale.s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: AppColors.border),
                  for (final action in actions) _actionLine(context, action),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionLine(BuildContext context, AgentAction action) {
    final failed = action.status == 'failed';
    final pending = action.status == 'pending';
    return InkWell(
      onTap: action.target.isEmpty ? null : () => openAgentActionTarget(context, action),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              failed
                  ? Icons.cancel
                  : pending
                      ? Icons.schedule
                      : Icons.check_circle,
              size: AppScale.s(16),
              color: failed
                  ? const Color(0xFFDC2626)
                  : pending
                      ? const Color(0xFFD97706)
                      : const Color(0xFF16A34A),
            ),
            SizedBox(width: AppScale.s(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(fontSize: AppScale.t(12.5), fontWeight: FontWeight.w600, color: AppColors.foreground),
                  ),
                  Text(
                    failed ? (action.failReason ?? '') : action.detail,
                    style: TextStyle(
                      fontSize: AppScale.t(11.5),
                      height: 1.35,
                      color: failed ? const Color(0xFFDC2626) : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (action.target.isNotEmpty)
              Icon(Icons.chevron_right, size: AppScale.s(16), color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
