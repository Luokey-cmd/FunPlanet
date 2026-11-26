// 小豆记得你：小豆从对话里沉淀下来的用户偏好（hx 2026-11-27 定版，
// 取代旧的星愿档案问卷）。主要来源是挑礼物问答里用户点选的选项，
// 用户也能在「小豆记得你」弹层里查看、修改、删除。
// 旧档案的「心情」与「送礼感受」已废除：心情是当次的、不进长期记忆；
// 旧存档读入时只迁移预算与用途，其余字段丢弃。
class StarwishProfile {
  const StarwishProfile({
    this.budget = 0,
    this.purpose = '',
    this.recipient = '',
    this.favoriteCategories = const [],
    this.favoriteSeries = const [],
  });

  /// 预算上限（元）：50 / 100 / 200；0 = 不限或还没记住
  final int budget;

  /// self / gift / browse（沿用旧档案编码，服务端靠它判送礼场景，别改值）
  final String purpose;

  /// 常送的对象（选项原话）：送朋友 / 送对象 / 送家人 / 送同担
  final String recipient;

  /// 喜欢的类型（大类名原话，如 玩具 / 公仔），最多记 3 个
  final List<String> favoriteCategories;

  /// 喜欢的系列（系列名原话），最多记 3 个
  final List<String> favoriteSeries;

  /// 一条都没记住时为 true，弹层据此显示空状态文案
  bool get isEmpty =>
      budget <= 0 &&
      purpose.isEmpty &&
      recipient.isEmpty &&
      favoriteCategories.isEmpty &&
      favoriteSeries.isEmpty;

  String get purposeLabel => switch (purpose) {
        'self' => '犒劳自己',
        'gift' => '送给别人',
        'browse' => '只是逛逛',
        _ => '',
      };

  String get budgetLabel => budget <= 0 ? '不限' : '$budget 内';

  StarwishProfile copyWith({
    int? budget,
    String? purpose,
    String? recipient,
    List<String>? favoriteCategories,
    List<String>? favoriteSeries,
  }) {
    return StarwishProfile(
      budget: budget ?? this.budget,
      purpose: purpose ?? this.purpose,
      recipient: recipient ?? this.recipient,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      favoriteSeries: favoriteSeries ?? this.favoriteSeries,
    );
  }

  Map<String, dynamic> toJson() => {
        'budget': budget,
        'purpose': purpose,
        'recipient': recipient,
        'favoriteCategories': favoriteCategories,
        'favoriteSeries': favoriteSeries,
      };

  // 发给小豆服务端看的版本：只带记住的项，没记住的不占地方；
  // 键名保持英文（服务端按 purpose 字段判送礼场景，别乱改键名）。
  Map<String, dynamic> toAgentJson() => {
        if (budget > 0) 'budget': budget,
        if (purpose.isNotEmpty) 'purpose': purposeLabel,
        if (recipient.isNotEmpty) 'recipient': recipient,
        if (favoriteCategories.isNotEmpty) 'favoriteCategories': favoriteCategories,
        if (favoriteSeries.isNotEmpty) 'favoriteSeries': favoriteSeries,
      };

  factory StarwishProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StarwishProfile();
    List<String> readList(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? const [];
    return StarwishProfile(
      budget: (json['budget'] as num?)?.toInt() ?? 0,
      purpose: json['purpose'] as String? ?? '',
      recipient: json['recipient'] as String? ?? '',
      favoriteCategories: readList('favoriteCategories'),
      favoriteSeries: readList('favoriteSeries'),
    );
  }
}
