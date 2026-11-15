class StarwishProfile {
  const StarwishProfile({
    this.mood = '',
    this.budget = 0,
    this.purpose = '',
    this.giftFeeling = '',
  });

  /// dream / heal / cool / funny
  final String mood;

  /// 30 / 50 / 100 / 0=不限
  final int budget;

  /// self / gift / browse
  final String purpose;

  /// understood / comforted / surprised
  final String giftFeeling;

  bool get isComplete {
    if (mood.isEmpty || purpose.isEmpty || budget < 0) return false;
    if (purpose == 'gift' && giftFeeling.isEmpty) return false;
    return true;
  }

  String get moodLabel => switch (mood) {
        'dream' => '梦幻',
        'heal' => '治愈',
        'cool' => '帅气',
        'funny' => '搞怪',
        _ => '未点亮',
      };

  String get purposeLabel => switch (purpose) {
        'self' => '犒劳自己',
        'gift' => '送给别人',
        'browse' => '只是逛逛',
        _ => '尚未启程',
      };

  String get budgetLabel => budget <= 0 ? '不限' : '$budget 内';

  String get feelingLabel => switch (giftFeeling) {
        'understood' => '被懂',
        'comforted' => '被哄',
        'surprised' => '被惊到',
        _ => '',
      };

  String get signTitle => switch ((mood, purpose)) {
        ('dream', 'gift') => '云笺旅人',
        ('dream', _) => '星河拾光',
        ('heal', 'gift') => '软风信使',
        ('heal', _) => '灯下歇脚',
        ('cool', _) => '夜轨行者',
        ('funny', _) => '戏法旅人',
        _ => '未署名旅人',
      };

  String get signLine => isComplete ? '$signTitle · $moodLabel · $budgetLabel' : '守瓶精灵 · 点亮你的星签';

  StarwishProfile copyWith({
    String? mood,
    int? budget,
    String? purpose,
    String? giftFeeling,
  }) {
    return StarwishProfile(
      mood: mood ?? this.mood,
      budget: budget ?? this.budget,
      purpose: purpose ?? this.purpose,
      giftFeeling: giftFeeling ?? this.giftFeeling,
    );
  }

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'budget': budget,
        'purpose': purpose,
        'giftFeeling': giftFeeling,
      };

  Map<String, dynamic> toAgentJson() => {
        'mood': moodLabel,
        'budget': budget <= 0 ? '不限' : budget,
        'purpose': purposeLabel,
        if (feelingLabel.isNotEmpty) 'giftFeeling': feelingLabel,
        'signTitle': signTitle,
      };

  factory StarwishProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StarwishProfile();
    return StarwishProfile(
      mood: json['mood'] as String? ?? '',
      budget: (json['budget'] as num?)?.toInt() ?? 0,
      purpose: json['purpose'] as String? ?? '',
      giftFeeling: json['giftFeeling'] as String? ?? '',
    );
  }
}
