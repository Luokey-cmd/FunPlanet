import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/review_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/media_url.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_network_image.dart';
import '../widgets/comment_thread.dart';
import '../widgets/user_avatar_image.dart';
import '../pages/image_preview_page.dart';
import '../widgets/click_effect/app_pressable.dart';

class ProductReviewCard extends StatefulWidget {
  const ProductReviewCard({super.key, required this.review});

  final ProductReview review;

  @override
  State<ProductReviewCard> createState() => _ProductReviewCardState();
}

class _ProductReviewCardState extends State<ProductReviewCard> {
  final _api = ReviewApiService();
  final _controller = TextEditingController();

  late ProductReview _review;
  ProductReviewComment? _replyTarget;
  final Set<String> _expandedRoots = {};
  bool _composerOpen = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  void didUpdateWidget(covariant ProductReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _review = widget.review;
      _composerOpen = false;
      _replyTarget = null;
      _expandedRoots.clear();
      _controller.clear();
    } else if (widget.review.comments.length > _review.comments.length) {
      _review = widget.review;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ThreadComment> get _threadComments {
    return _review.comments
        .map(
          (c) => ThreadComment(
            id: c.id,
            content: c.content,
            authorName: c.userNickname,
            authorAvatarPath: c.userAvatarPath,
            createdAtLabel: c.createdAt,
            parentId: c.parentId,
            rootId: c.rootId,
            replyToUserName: c.replyToUserName,
          ),
        )
        .toList();
  }

  void _openComposer({ProductReviewComment? replyTo}) {
    setState(() {
      _composerOpen = true;
      _replyTarget = replyTo;
      if (replyTo != null) {
        _expandedRoots.add(replyTo.threadRootId);
      }
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = await _api.addReviewComment(
        reviewId: _review.id,
        content: text,
        parentId: _replyTarget?.id ?? '0',
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _review = updated;
        _composerOpen = false;
        _replyTarget = null;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = error is ApiException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyName = _replyTarget?.userNickname;
    final hint = replyName == null || replyName.isEmpty ? '评论这条评价…' : '回复 @$replyName';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarImage(
                path: _review.userAvatarPath,
                width: AppScale.s(32),
                height: AppScale.s(32),
                borderRadius: BorderRadius.circular(AppScale.s(16)),
              ),
              SizedBox(width: AppScale.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_review.userNickname, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w600)),
                    Text(_review.createdAt, style: TextStyle(fontSize: AppScale.t(11), color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < _review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: AppScale.s(14),
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(8)),
          Text(_review.content, style: TextStyle(fontSize: AppScale.t(13), color: AppColors.foreground, height: 1.5)),
          if (_review.imagePaths.isNotEmpty) ...[
            SizedBox(height: AppScale.s(8)),
            Wrap(
              spacing: AppScale.s(6),
              runSpacing: AppScale.s(6),
              children: _review.imagePaths.map((path) => ProductReviewImage(path: path)).toList(),
            ),
          ],
          SizedBox(height: AppScale.s(10)),
          Align(
            alignment: Alignment.centerRight,
            child: AppGestureDetector(
              onTap: () => _openComposer(),
              child: Text(
                '评论 ${_review.comments.isEmpty ? '' : '(${_review.comments.length})'}'.trim(),
                style: TextStyle(fontSize: AppScale.t(12), color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_review.comments.isNotEmpty || _composerOpen) ...[
            SizedBox(height: AppScale.s(8)),
            CommentThreadList(
              comments: _threadComments,
              expandedRootIds: _expandedRoots,
              replyTargetId: _replyTarget?.id,
              emptyLabel: '还没有评论，来抢沙发',
              onReply: (thread) {
                final match = _review.comments.where((c) => c.id == thread.id);
                if (match.isEmpty) return;
                _openComposer(replyTo: match.first);
              },
              onToggleExpand: (rootId) {
                setState(() {
                  if (!_expandedRoots.add(rootId)) _expandedRoots.remove(rootId);
                });
              },
              composer: _composerOpen
                  ? CommentComposerBar(
                      controller: _controller,
                      onSubmit: _submitting ? () {} : _submit,
                      hintText: hint,
                      onCancel: () => setState(() {
                        _composerOpen = false;
                        _replyTarget = null;
                      }),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class ProductReviewImage extends StatelessWidget {
  const ProductReviewImage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: AppScale.s(72),
            height: AppScale.s(72),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final url = snapshot.data!;
        return AppGestureDetector(
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ImagePreviewPage(child: AppNetworkImage(url: url, fit: BoxFit.contain)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppScale.s(8)),
            child: AppNetworkImage(
              url: url,
              width: AppScale.s(72),
              height: AppScale.s(72),
              fit: BoxFit.cover,
              errorWidget: Container(
                width: AppScale.s(72),
                height: AppScale.s(72),
                color: AppColors.muted,
              ),
            ),
          ),
        );
      },
    );
  }
}
