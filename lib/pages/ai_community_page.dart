import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ai_friend_profiles.dart';
import '../models/ai_community.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_community_service.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/feature_page_style.dart';
import '../utils/media_url.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/user_avatar_image.dart';
import 'ai_community_compose_page.dart';
import 'image_preview_page.dart';

class AiCommunityTheme {
  static const card = AppColors.card;
  static const cardElevated = AppColors.muted;
  static const border = AppColors.border;
  static const textPrimary = AppColors.foreground;
  static const textSecondary = AppColors.mutedForeground;
  static const accent = AppColors.primary;
  static const accentBright = AppColors.primaryLight;
  static const like = AppColors.tagNew;
  static const tagBg = AppColors.secondary;
  static const tagText = AppColors.secondaryForeground;
  static const inputBg = AppColors.muted;
}

class AiCommunityPage extends StatefulWidget {
  const AiCommunityPage({super.key});

  @override
  State<AiCommunityPage> createState() => _AiCommunityPageState();
}

class _AiCommunityPageState extends State<AiCommunityPage> {
  final _service = AiCommunityService();
  final _scrollController = ScrollController();
  final Map<String, TextEditingController> _commentControllers = {};

  List<AiCommunityPost> _posts = [];
  bool _loading = true;
  String? _activeCommentPostId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await context.read<UserProvider>().refreshProfileFromRemote();
    if (mounted) _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String postId) {
    return _commentControllers.putIfAbsent(postId, TextEditingController.new);
  }

  CommunitySession _session() {
    return CommunitySession.from(
      context.read<UserProvider>(),
      context.read<AuthProvider>(),
    );
  }

  AiCommunityPost _patchPost(AiCommunityPost post) {
    return patchCommunityPost(post, _session());
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      await context.read<UserProvider>().refreshProfileFromRemote();
      final rows = await _service.fetchFeed();
      if (mounted) {
        final session = _session();
        _posts = rows.map((post) => patchCommunityPost(post, session)).toList();
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException ? error.message : '$error';
        showTopSnackBar(
          context,
          content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
        );
      }
      _posts = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCompose() async {
    final created = await Navigator.push<AiCommunityPost>(
      context,
      MaterialPageRoute(builder: (_) => const AiCommunityComposePage()),
    );
    if (created == null || !mounted) return;
    setState(() => _posts = [_patchPost(created), ..._posts.where((p) => p.id != created.id)]);
    _pollPostUpdates(created.id, expectAiReply: false);
  }

  Future<void> _toggleLike(AiCommunityPost post) async {
    try {
      final updated = await _service.toggleLike(post.id);
      _replacePost(updated);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  Future<void> _deletePost(AiCommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除动态', style: TextStyle(fontSize: FeaturePageStyle.s(16), fontWeight: FontWeight.w700)),
        content: Text('确定删除这条朋友圈吗？删除后无法恢复。', style: TextStyle(fontSize: FeaturePageStyle.s(14), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.priceRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.deletePost(post.id);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((item) => item.id != post.id).toList();
        _commentControllers.remove(post.id)?.dispose();
        if (_activeCommentPostId == post.id) _activeCommentPostId = null;
      });
      showTopSnackBar(
        context,
        content: Text('动态已删除', style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  void _toggleCommentBox(String postId) {
    setState(() {
      _activeCommentPostId = _activeCommentPostId == postId ? null : postId;
    });
  }

  Future<void> _submitComment(AiCommunityPost post) async {
    final text = _controllerFor(post.id).text.trim();
    if (text.isEmpty) return;

    try {
      final updated = await _service.addComment(post.id, text);
      _controllerFor(post.id).clear();
      _replacePost(updated);
      setState(() => _activeCommentPostId = null);
      if (post.author.isAiFriend) {
        _pollPostUpdates(post.id, expectAiReply: true);
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      showTopSnackBar(
        context,
        content: Text(message, style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  void _replacePost(AiCommunityPost post) {
    setState(() {
      _posts = _posts.map((item) => item.id == post.id ? _patchPost(post) : item).toList();
    });
  }

  Future<void> _pollPostUpdates(String postId, {required bool expectAiReply}) async {
    final baseline = _posts.firstWhere((p) => p.id == postId, orElse: () => _posts.first).comments.length;
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      try {
        final updated = await _service.fetchPost(postId);
        _replacePost(updated);
        if (expectAiReply && updated.comments.length > baseline) {
          return;
        }
        if (!expectAiReply && (updated.comments.length > baseline || updated.likeCount > 0)) {
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();
    context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SparkleBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CommunityHeader(onCompose: _openCompose),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AiCommunityTheme.accent))
                    : RefreshIndicator(
                        color: AiCommunityTheme.accent,
                        backgroundColor: AppColors.card,
                        onRefresh: _loadFeed,
                        child: _posts.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: FeaturePageStyle.s(100)),
                                  Center(
                                    child: Text(
                                      '暂无动态，发一条试试吧',
                                      style: TextStyle(color: AppColors.mutedForeground, fontSize: FeaturePageStyle.s(15)),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  FeaturePageStyle.s(14),
                                  FeaturePageStyle.s(8),
                                  FeaturePageStyle.s(14),
                                  FeaturePageStyle.s(28),
                                ),
                                itemCount: _posts.length,
                                itemBuilder: (context, index) {
                                  final user = context.watch<UserProvider>();
                                  final auth = context.read<AuthProvider>();
                                  final session = CommunitySession.from(user, auth);
                                  final post = patchCommunityPost(_posts[index], session);
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: FeaturePageStyle.s(16)),
                                    child: _FeedPostCard(
                                      post: post,
                                      profile: profileForAuthor(post.author),
                                      commentController: _controllerFor(post.id),
                                      commentBoxOpen: _activeCommentPostId == post.id,
                                      onLike: () => _toggleLike(_posts[index]),
                                      onCommentTap: () => _toggleCommentBox(post.id),
                                      onSubmitComment: () => _submitComment(_posts[index]),
                                      onDelete: isOwnCommunityPost(post, session)
                                          ? () => _deletePost(_posts[index])
                                          : null,
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(6), FeaturePageStyle.s(4), FeaturePageStyle.s(12), FeaturePageStyle.s(10)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.foreground, size: FeaturePageStyle.s(20)),
          ),
          Container(
            width: FeaturePageStyle.s(40),
            height: FeaturePageStyle.s(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C6CF0), Color(0xFFB88FE8)]),
              borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: FeaturePageStyle.s(22)),
          ),
          SizedBox(width: FeaturePageStyle.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 社区',
                  style: TextStyle(
                    fontSize: FeaturePageStyle.s(18),
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    height: 1.2,
                  ),
                ),
                Text(
                  '看看 AI 朋友们的动态',
                  style: TextStyle(fontSize: FeaturePageStyle.s(12), color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCompose,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(10), vertical: FeaturePageStyle.s(6)),
            ),
            icon: Icon(Icons.edit_rounded, size: FeaturePageStyle.s(16)),
            label: Text('发动态', style: TextStyle(fontSize: FeaturePageStyle.s(14), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.profile,
    required this.commentController,
    required this.commentBoxOpen,
    required this.onLike,
    required this.onCommentTap,
    required this.onSubmitComment,
    this.onDelete,
  });

  final AiCommunityPost post;
  final AiFriendProfile profile;
  final TextEditingController commentController;
  final bool commentBoxOpen;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;
  final VoidCallback onSubmitComment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final session = CommunitySession.from(user, auth);
    final displayAuthor = enrichAuthor(post.author, session);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(FeaturePageStyle.s(18)),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(FeaturePageStyle.s(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PostAuthorHeader(
                  author: displayAuthor,
                  profile: profile,
                  createdAt: post.createdAt,
                  onDelete: onDelete,
                ),
                SizedBox(height: FeaturePageStyle.s(12)),
                Text(
                  post.content,
                  style: TextStyle(
                    fontSize: FeaturePageStyle.s(15),
                    height: 1.65,
                    color: AiCommunityTheme.textPrimary.withValues(alpha: 0.95),
                  ),
                ),
                if (post.imagePath.isNotEmpty) ...[
                  SizedBox(height: FeaturePageStyle.s(12)),
                  _PostImage(imagePath: post.imagePath),
                ],
                SizedBox(height: FeaturePageStyle.s(12)),
                Wrap(
                  spacing: FeaturePageStyle.s(8),
                  runSpacing: FeaturePageStyle.s(8),
                  children: profile.tags
                      .map(
                        (tag) => Container(
                          padding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(10), vertical: FeaturePageStyle.s(5)),
                          decoration: BoxDecoration(
                            color: AiCommunityTheme.tagBg,
                            borderRadius: BorderRadius.circular(FeaturePageStyle.s(20)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(fontSize: FeaturePageStyle.s(12), color: AiCommunityTheme.tagText, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: FeaturePageStyle.s(14)),
                Row(
                  children: [
                    Expanded(child: _ActionPill(
                      icon: post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: '${post.likeCount}',
                      iconColor: post.likedByMe ? AiCommunityTheme.like : AiCommunityTheme.textSecondary,
                      onTap: onLike,
                    )),
                    SizedBox(width: FeaturePageStyle.s(8)),
                    Expanded(child: _ActionPill(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '评论',
                      onTap: onCommentTap,
                    )),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final displayLikers = enrichLikers(
                      resolvePostLikers(likers: post.likers, likeNames: post.likeNames),
                      session: session,
                      postAuthor: displayAuthor,
                      likedByMe: post.likedByMe,
                    );
                    if (displayLikers.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: FeaturePageStyle.s(10)),
                        _LikerAvatarRow(likers: displayLikers),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (post.comments.isNotEmpty)
            Container(
              color: AppColors.muted.withValues(alpha: 0.65),
              padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(14), FeaturePageStyle.s(10), FeaturePageStyle.s(14), FeaturePageStyle.s(12)),
              child: Column(
                children: post.comments
                    .map(
                      (c) => Padding(
                        padding: EdgeInsets.only(bottom: FeaturePageStyle.s(8)),
                        child: _CommentTile(comment: c, profile: profileForAuthor(c.author)),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (commentBoxOpen) _CommentComposer(controller: commentController, onSubmit: onSubmitComment),
        ],
      ),
    );
  }
}

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({
    required this.author,
    required this.profile,
    required this.createdAt,
    this.onDelete,
  });

  final AiCommunityAuthor author;
  final AiFriendProfile profile;
  final DateTime createdAt;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthorAvatar(author: author, radius: FeaturePageStyle.s(24)),
        SizedBox(width: FeaturePageStyle.s(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.name,
                style: TextStyle(fontSize: FeaturePageStyle.s(16), fontWeight: FontWeight.w800, color: AiCommunityTheme.textPrimary),
              ),
              SizedBox(height: FeaturePageStyle.s(2)),
              Text(profile.title, style: TextStyle(fontSize: FeaturePageStyle.s(12), color: AiCommunityTheme.textSecondary, height: 1.35)),
              SizedBox(height: FeaturePageStyle.s(4)),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: FeaturePageStyle.s(13), color: AiCommunityTheme.textSecondary),
                  SizedBox(width: FeaturePageStyle.s(2)),
                  Flexible(
                    child: Text(
                      '${profile.location} · ${_formatTime(createdAt)}',
                      style: TextStyle(fontSize: FeaturePageStyle.s(12), color: AiCommunityTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: FeaturePageStyle.s(32), minHeight: FeaturePageStyle.s(32)),
            icon: Icon(Icons.delete_outline_rounded, size: FeaturePageStyle.s(20), color: AppColors.mutedForeground),
            tooltip: '删除',
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.year}/${time.month}/${time.day}';
  }
}

class _LikerAvatarRow extends StatelessWidget {
  const _LikerAvatarRow({required this.likers});

  final List<AiCommunityAuthor> likers;

  @override
  Widget build(BuildContext context) {
    final avatarSize = FeaturePageStyle.s(28);
    return Row(
      children: [
        Icon(Icons.favorite_rounded, size: FeaturePageStyle.s(14), color: AiCommunityTheme.like),
        SizedBox(width: FeaturePageStyle.s(8)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < likers.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: FeaturePageStyle.s(6)),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AiCommunityTheme.card, width: FeaturePageStyle.s(2)),
                      ),
                      child: _AuthorAvatar(author: likers[i], radius: avatarSize / 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AiCommunityTheme.cardElevated,
      borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FeaturePageStyle.s(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: FeaturePageStyle.s(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: FeaturePageStyle.s(16), color: iconColor ?? AiCommunityTheme.textSecondary),
              SizedBox(width: FeaturePageStyle.s(5)),
              Text(
                label,
                style: TextStyle(fontSize: FeaturePageStyle.s(13), color: AiCommunityTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.profile});

  final AiCommunityComment comment;
  final AiFriendProfile profile;

  @override
  Widget build(BuildContext context) {
    final date = comment.createdAt;
    final dateLabel = '${date.year}/${date.month}/${date.day}';

    return Container(
      padding: EdgeInsets.all(FeaturePageStyle.s(12)),
      decoration: BoxDecoration(
        color: AiCommunityTheme.cardElevated,
        borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
        border: Border.all(color: AiCommunityTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(author: comment.author, radius: FeaturePageStyle.s(16)),
              SizedBox(width: FeaturePageStyle.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.author.name,
                            style: TextStyle(
                              fontSize: FeaturePageStyle.s(14),
                              fontWeight: FontWeight.w700,
                              color: comment.author.isAiFriend ? AiCommunityTheme.accentBright : AiCommunityTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(dateLabel, style: TextStyle(fontSize: FeaturePageStyle.s(11), color: AiCommunityTheme.textSecondary)),
                      ],
                    ),
                    if (comment.author.isAiFriend)
                      Text(profile.title, style: TextStyle(fontSize: FeaturePageStyle.s(11), color: AiCommunityTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: FeaturePageStyle.s(8)),
          Text(
            comment.content,
            style: TextStyle(fontSize: FeaturePageStyle.s(14), height: 1.55, color: AiCommunityTheme.textPrimary.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(FeaturePageStyle.s(12)),
      decoration: BoxDecoration(
        color: AiCommunityTheme.inputBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              maxLength: 300,
              style: TextStyle(color: AiCommunityTheme.textPrimary, fontSize: FeaturePageStyle.s(14)),
              decoration: InputDecoration(
                hintText: '写下你的评论…',
                hintStyle: TextStyle(color: AiCommunityTheme.textSecondary, fontSize: FeaturePageStyle.s(14)),
                filled: true,
                fillColor: AiCommunityTheme.cardElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
                  borderSide: BorderSide(color: AiCommunityTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
                  borderSide: BorderSide(color: AiCommunityTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
                  borderSide: const BorderSide(color: AiCommunityTheme.accent),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(12), vertical: FeaturePageStyle.s(10)),
                counterStyle: TextStyle(color: AiCommunityTheme.textSecondary, fontSize: FeaturePageStyle.s(11)),
              ),
            ),
          ),
          SizedBox(width: FeaturePageStyle.s(8)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSubmit,
              borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C6CF0), Color(0xFFB88FE8)]),
                  borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: FeaturePageStyle.s(14), vertical: FeaturePageStyle.s(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: FeaturePageStyle.s(16)),
                      SizedBox(width: FeaturePageStyle.s(4)),
                      Text('发表', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: FeaturePageStyle.s(14))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author, required this.radius});

  final AiCommunityAuthor author;
  final double radius;

  Color _colorFromHex(String hex) {
    final value = hex.replaceAll('#', '');
    if (value.length == 6) return Color(int.parse('FF$value', radix: 16));
    return AiCommunityTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final avatarPath = resolveDisplayAvatarPath(author, user, auth);
    if (avatarPath.isNotEmpty) {
      return ClipOval(
        child: UserAvatarImage(
          path: avatarPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFromHex(author.avatarColor),
      child: Text(
        author.name.isNotEmpty ? author.name[0] : '?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolveRemoteMediaUrl(imagePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: FeaturePageStyle.s(200),
            decoration: BoxDecoration(
              color: AiCommunityTheme.cardElevated,
              borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AiCommunityTheme.accent)),
          );
        }
        final url = snapshot.data!;
        return GestureDetector(
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => ImagePreviewPage(child: Image.network(url, fit: BoxFit.contain))),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FeaturePageStyle.s(14)),
            child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: FeaturePageStyle.s(220)),
          ),
        );
      },
    );
  }
}
