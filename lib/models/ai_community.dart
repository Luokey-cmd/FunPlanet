class AiCommunityAuthor {
  const AiCommunityAuthor({
    required this.type,
    required this.id,
    required this.name,
    required this.avatarPath,
    required this.avatarColor,
  });

  final String type;
  final String id;
  final String name;
  final String avatarPath;
  final String avatarColor;

  bool get isAiFriend => type == 'ai_friend';

  bool get isRealUser => !isAiFriend;

  AiCommunityAuthor copyWith({
    String? type,
    String? id,
    String? name,
    String? avatarPath,
    String? avatarColor,
  }) {
    return AiCommunityAuthor(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  factory AiCommunityAuthor.fromJson(Map<String, dynamic> json) {
    return AiCommunityAuthor(
      type: json['type'] as String? ?? 'unknown',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未知',
      avatarPath: json['avatarPath'] as String? ?? '',
      avatarColor: json['avatarColor'] as String? ?? '#A389F4',
    );
  }
}

class AiCommunityComment {
  const AiCommunityComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final AiCommunityAuthor author;
  final String content;
  final DateTime createdAt;

  AiCommunityComment copyWith({
    AiCommunityAuthor? author,
    String? content,
    DateTime? createdAt,
  }) {
    return AiCommunityComment(
      id: id,
      author: author ?? this.author,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AiCommunityComment.fromJson(Map<String, dynamic> json) {
    return AiCommunityComment(
      id: json['id'] as String,
      author: AiCommunityAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AiCommunityPost {
  const AiCommunityPost({
    required this.id,
    required this.author,
    required this.content,
    required this.imagePath,
    required this.createdAt,
    required this.likeCount,
    required this.likedByMe,
    required this.likeNames,
    required this.likers,
    required this.comments,
  });

  final String id;
  final AiCommunityAuthor author;
  final String content;
  final String imagePath;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;
  final List<String> likeNames;
  final List<AiCommunityAuthor> likers;
  final List<AiCommunityComment> comments;

  AiCommunityPost copyWith({
    AiCommunityAuthor? author,
    String? content,
    String? imagePath,
    DateTime? createdAt,
    int? likeCount,
    bool? likedByMe,
    List<String>? likeNames,
    List<AiCommunityAuthor>? likers,
    List<AiCommunityComment>? comments,
  }) {
    return AiCommunityPost(
      id: id,
      author: author ?? this.author,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      likeNames: likeNames ?? this.likeNames,
      likers: likers ?? this.likers,
      comments: comments ?? this.comments,
    );
  }

  factory AiCommunityPost.fromJson(Map<String, dynamic> json) {
    final likes = json['likeNames'];
    final likerRows = json['likers'];
    return AiCommunityPost(
      id: json['id'] as String,
      author: AiCommunityAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      likeNames: likes is List ? likes.map((e) => e.toString()).toList() : const [],
      likers: likerRows is List
          ? likerRows.map((item) => AiCommunityAuthor.fromJson(item as Map<String, dynamic>)).toList()
          : const [],
      comments: (json['comments'] as List? ?? [])
          .map((item) => AiCommunityComment.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
