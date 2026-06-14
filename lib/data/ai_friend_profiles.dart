import '../models/ai_community.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class CommunitySession {
  const CommunitySession({
    required this.userId,
    required this.nickname,
    required this.avatarPath,
  });

  final String userId;
  final String nickname;
  final String avatarPath;

  factory CommunitySession.from(UserProvider user, AuthProvider auth) {
    return CommunitySession(
      userId: auth.currentUser?.id ?? '',
      nickname: user.nickname,
      avatarPath: user.avatarPath,
    );
  }
}

class AiFriendProfile {
  const AiFriendProfile({
    required this.title,
    required this.location,
    required this.tags,
  });

  final String title;
  final String location;
  final List<String> tags;
}

const aiFriendProfileMap = <String, AiFriendProfile>{
  'xiaoxing': AiFriendProfile(
    title: '二次元爱好者 · 萌系插画控',
    location: '趣玩星球 · 星光塔',
    tags: ['#二次元', '#AI绘画', '#治愈系'],
  ),
  'amu': AiFriendProfile(
    title: '视觉设计爱好者 · 构图点评师',
    location: '趣玩星球 · 创作工坊',
    tags: ['#AI绘画', '#构图', '#配色'],
  ),
  'tangtang': AiFriendProfile(
    title: '温柔治愈系 · 氛围感收藏家',
    location: '趣玩星球 · 云朵花园',
    tags: ['#温柔', '#日常', '#小确幸'],
  ),
  'tuanzi': AiFriendProfile(
    title: '趣玩种草达人 · 盲盒收藏家',
    location: '趣玩星球 · 周边市集',
    tags: ['#盲盒', '#开箱', '#趣玩推荐'],
  ),
  'kele': AiFriendProfile(
    title: '气氛组段子手 · 快乐传播员',
    location: '趣玩星球 · 欢乐广场',
    tags: ['#搞笑', '#日常', '#梗'],
  ),
  'youzi': AiFriendProfile(
    title: '文艺慢生活 · 光影记录者',
    location: '趣玩星球 · 晚风书店',
    tags: ['#慢生活', '#氛围感', '#摄影'],
  ),
  'nihong': AiFriendProfile(
    title: '赛博科幻控 · 霓虹美学党',
    location: '趣玩星球 · 未来街区',
    tags: ['#赛博朋克', '#科幻', '#霓虹'],
  ),
  'mobai': AiFriendProfile(
    title: '国风美学爱好者 · 意境派',
    location: '趣玩星球 · 水墨巷',
    tags: ['#国风', '#古风', '#留白'],
  ),
};

const defaultUserProfile = AiFriendProfile(
  title: '趣玩星球用户 · 生活分享者',
  location: '趣玩星球',
  tags: ['#日常', '#趣玩星球'],
);

const aiFriendAvatarMap = <String, String>{
  'xiaoxing': 'assets/images/小星头像.jpg',
  'amu': 'assets/images/阿木头像.jpeg',
  'tangtang': 'assets/images/糖糖头像.jpg',
  'tuanzi': 'assets/images/团子头像.png',
  'kele': 'assets/images/可乐头像.jpg',
  'youzi': 'assets/images/柚子头像.jpeg',
  'nihong': 'assets/images/霓虹头像.jpg',
  'mobai': 'assets/images/墨白头像.jpg',
};

const aiFriendColorMap = <String, String>{
  'xiaoxing': '#FF6B9D',
  'amu': '#5B8DEF',
  'tangtang': '#FFB8D0',
  'tuanzi': '#FF9F43',
  'kele': '#52C41A',
  'youzi': '#9B7FE8',
  'nihong': '#00B4D8',
  'mobai': '#8B7355',
};

const aiFriendNameToId = <String, String>{
  '小星': 'xiaoxing',
  '阿木': 'amu',
  '糖糖': 'tangtang',
  '团子': 'tuanzi',
  '可乐': 'kele',
  '柚子': 'youzi',
  '霓虹': 'nihong',
  '墨白': 'mobai',
};

AiFriendProfile profileForAuthor(AiCommunityAuthor author) {
  if (author.isAiFriend) {
    return aiFriendProfileMap[author.id] ?? defaultUserProfile;
  }
  return defaultUserProfile;
}

String avatarPathForAuthor(AiCommunityAuthor author) {
  if (author.avatarPath.isNotEmpty) return author.avatarPath;
  if (author.isAiFriend) return aiFriendAvatarMap[author.id] ?? '';
  return '';
}

bool matchesSessionUser(AiCommunityAuthor author, CommunitySession session) {
  if (author.isAiFriend) return false;
  if (session.userId.isNotEmpty && author.id.isNotEmpty && author.id == session.userId) {
    return true;
  }
  final authorName = author.name.trim().toLowerCase();
  final nickname = session.nickname.trim().toLowerCase();
  return authorName.isNotEmpty && nickname.isNotEmpty && authorName == nickname;
}

String resolveCommunityAvatarPath(AiCommunityAuthor author, CommunitySession session) {
  if (author.isAiFriend) return avatarPathForAuthor(author);

  final localAvatar = session.avatarPath.trim();
  if (localAvatar.isNotEmpty && matchesSessionUser(author, session)) {
    return localAvatar;
  }

  final remotePath = author.avatarPath.trim();
  if (remotePath.isNotEmpty) return remotePath;

  return '';
}

AiCommunityAuthor enrichAuthor(AiCommunityAuthor author, CommunitySession session) {
  if (author.isAiFriend) return author;

  final sessionAvatar = session.avatarPath.trim();
  if (sessionAvatar.isNotEmpty && matchesSessionUser(author, session)) {
    return author.copyWith(
      type: author.type == 'unknown' || author.type.isEmpty ? 'user' : author.type,
      id: author.id.isNotEmpty ? author.id : session.userId,
      avatarPath: sessionAvatar,
    );
  }

  final avatarPath = resolveCommunityAvatarPath(author, session);
  if (avatarPath.isEmpty || avatarPath == author.avatarPath) return author;

  return author.copyWith(
    type: author.type == 'unknown' ? 'user' : author.type,
    id: author.id.isNotEmpty ? author.id : session.userId,
    avatarPath: avatarPath,
  );
}

String resolveDisplayAvatarPath(
  AiCommunityAuthor author,
  UserProvider user,
  AuthProvider auth,
) {
  final session = CommunitySession.from(user, auth);

  final enriched = avatarPathForAuthor(author);
  if (enriched.isNotEmpty) return enriched;

  if (!author.isAiFriend && matchesSessionUser(author, session)) {
    final mine = user.avatarPath.trim();
    if (mine.isNotEmpty) return mine;
  }

  return resolveCommunityAvatarPath(author, session);
}

bool isOwnCommunityPost(AiCommunityPost post, CommunitySession session) {
  return post.author.isRealUser && matchesSessionUser(post.author, session);
}

List<AiCommunityAuthor> resolvePostLikers({
  required List<AiCommunityAuthor> likers,
  required List<String> likeNames,
}) {
  if (likers.isNotEmpty) return likers;
  if (likeNames.isEmpty) return const [];

  return likeNames.map((name) {
    final friendId = aiFriendNameToId[name];
    if (friendId != null) {
      return AiCommunityAuthor(
        type: 'ai_friend',
        id: friendId,
        name: name,
        avatarPath: aiFriendAvatarMap[friendId] ?? '',
        avatarColor: aiFriendColorMap[friendId] ?? '#A389F4',
      );
    }
    return AiCommunityAuthor(
      type: 'user',
      id: '',
      name: name,
      avatarPath: '',
      avatarColor: '',
    );
  }).toList();
}

List<AiCommunityAuthor> enrichLikers(
  List<AiCommunityAuthor> likers, {
  required CommunitySession session,
  AiCommunityAuthor? postAuthor,
  bool likedByMe = false,
}) {
  final authorForMatch = postAuthor != null ? enrichAuthor(postAuthor, session) : null;

  return likers.map((liker) {
    final resolved = enrichAuthor(liker, session);
    if (resolved.avatarPath.isNotEmpty) return resolved;
    if (!resolved.isRealUser) return resolved;

    var avatarPath = '';

    if (authorForMatch != null && authorForMatch.isRealUser) {
      final sameAuthor = (resolved.id.isNotEmpty && resolved.id == authorForMatch.id) ||
          resolved.name.trim().toLowerCase() == authorForMatch.name.trim().toLowerCase();
      if (sameAuthor) {
        avatarPath = resolveCommunityAvatarPath(authorForMatch, session);
      }
    }

    if (avatarPath.isEmpty &&
        likedByMe &&
        session.avatarPath.trim().isNotEmpty &&
        matchesSessionUser(resolved, session)) {
      avatarPath = session.avatarPath.trim();
    }

    if (avatarPath.isEmpty) return resolved;
    return resolved.copyWith(avatarPath: avatarPath);
  }).toList();
}

AiCommunityPost patchCommunityPost(AiCommunityPost post, CommunitySession session) {
  final author = enrichAuthor(post.author, session);
  final likers = enrichLikers(
    resolvePostLikers(likers: post.likers, likeNames: post.likeNames),
    session: session,
    postAuthor: author,
    likedByMe: post.likedByMe,
  );
  final comments = post.comments
      .map(
        (comment) => comment.copyWith(author: enrichAuthor(comment.author, session)),
      )
      .toList();

  return post.copyWith(
    author: author,
    likers: likers,
    comments: comments,
  );
}
