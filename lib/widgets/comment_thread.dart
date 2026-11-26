import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/click_effect/app_pressable.dart';
import '../widgets/user_avatar_image.dart';

/// 通用楼中楼评论条目（AI 社区 / 商品评价共用结构）。
class ThreadComment {
  const ThreadComment({
    required this.id,
    required this.content,
    required this.authorName,
    required this.createdAtLabel,
    this.authorAvatarPath = '',
    this.parentId = '0',
    this.rootId = '0',
    this.replyToUserName = '',
    this.isAi = false,
  });

  final String id;
  final String content;
  final String authorName;
  final String authorAvatarPath;
  final String createdAtLabel;
  final String parentId;
  final String rootId;
  final String replyToUserName;
  final bool isAi;

  bool get isRoot => parentId == '0' || parentId.isEmpty;
}

/// 参考 peduliAI：一级评论 + 展开二级 + 「回复 @xxx」缩进。
class CommentThreadList extends StatelessWidget {
  const CommentThreadList({
    super.key,
    required this.comments,
    required this.onReply,
    this.expandedRootIds = const {},
    this.onToggleExpand,
    this.replyTargetId,
    this.composer,
    this.emptyLabel = '暂无评论',
  });

  final List<ThreadComment> comments;
  final void Function(ThreadComment comment) onReply;
  final Set<String> expandedRootIds;
  final void Function(String rootId)? onToggleExpand;
  final String? replyTargetId;
  final Widget? composer;
  final String emptyLabel;

  List<ThreadComment> get _roots => comments.where((c) => c.isRoot).toList();

  List<ThreadComment> _repliesOf(String rootId) {
    return comments.where((c) {
      if (c.isRoot) return false;
      final rid = c.rootId == '0' || c.rootId.isEmpty ? c.parentId : c.rootId;
      return rid == rootId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots;
    if (roots.isEmpty && composer == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppScale.s(8)),
        child: Text(emptyLabel, style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final root in roots) ...[
          CommentTile(
            comment: root,
            onReply: () => onReply(root),
          ),
          Builder(
            builder: (context) {
              final replies = _repliesOf(root.id);
              final expanded = expandedRootIds.contains(root.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (replies.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: AppScale.s(40), top: AppScale.s(4), bottom: AppScale.s(4)),
                      child: AppGestureDetector(
                        onTap: onToggleExpand == null ? null : () => onToggleExpand!(root.id),
                        child: Text(
                          expanded ? '收起回复' : '展开 ${replies.length} 条回复',
                          style: TextStyle(
                            fontSize: AppScale.t(12),
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (expanded)
                    ...replies.map(
                      (reply) => Padding(
                        padding: EdgeInsets.only(left: AppScale.s(40), top: AppScale.s(6)),
                        child: CommentTile(
                          comment: reply,
                          compact: true,
                          onReply: () => onReply(reply),
                        ),
                      ),
                    ),
                  if (replyTargetId == root.id || replies.any((r) => r.id == replyTargetId))
                    if (composer != null)
                      Padding(
                        padding: EdgeInsets.only(left: AppScale.s(40), top: AppScale.s(8)),
                        child: composer!,
                      ),
                ],
              );
            },
          ),
          SizedBox(height: AppScale.s(10)),
        ],
        if (replyTargetId == null && composer != null) ...[
          SizedBox(height: AppScale.s(4)),
          composer!,
        ],
      ],
    );
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    this.compact = false,
  });

  final ThreadComment comment;
  final VoidCallback onReply;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatar = compact ? AppScale.s(28) : AppScale.s(32);
    return Container(
      padding: EdgeInsets.all(AppScale.s(compact ? 10 : 12)),
      decoration: BoxDecoration(
        color: compact ? AppColors.muted.withValues(alpha: 0.65) : AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarImage(
                path: comment.authorAvatarPath,
                width: avatar,
                height: avatar,
                borderRadius: BorderRadius.circular(avatar / 2),
              ),
              SizedBox(width: AppScale.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            style: TextStyle(
                              fontSize: AppScale.t(13),
                              fontWeight: FontWeight.w700,
                              color: comment.isAi ? AppColors.primary : AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(comment.createdAtLabel, style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              AppGestureDetector(
                onTap: onReply,
                child: Text('回复', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(8)),
          if (comment.replyToUserName.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: AppScale.s(4)),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '回复 ', style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground)),
                    TextSpan(
                      text: '@${comment.replyToUserName}',
                      style: TextStyle(fontSize: AppScale.t(13), color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            comment.content,
            style: TextStyle(fontSize: AppScale.t(13), height: 1.5, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }
}

class CommentComposerBar extends StatelessWidget {
  const CommentComposerBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hintText = '写下你的评论…',
    this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String hintText;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppScale.s(10)),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: AppGestureDetector(
                onTap: onCancel,
                child: Text('取消回复', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              AppGestureDetector(
                onTap: onSubmit,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(8)),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppScale.s(10)),
                  ),
                  child: Text('发送', style: TextStyle(color: Colors.white, fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
