class AiArtwork {
  const AiArtwork({
    required this.id,
    required this.prompt,
    required this.style,
    required this.imagePath,
    required this.model,
    required this.createdAt,
  });

  final String id;
  final String prompt;
  final String style;
  final String imagePath;
  final String model;
  final DateTime createdAt;

  factory AiArtwork.fromJson(Map<String, dynamic> json) {
    return AiArtwork(
      id: json['id'] as String,
      prompt: json['prompt'] as String? ?? '',
      style: json['style'] as String? ?? '',
      imagePath: json['imagePath'] as String,
      model: json['model'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AiPaintQuota {
  const AiPaintQuota({
    required this.dailyLimit,
    required this.usedToday,
    required this.remainingToday,
  });

  final int dailyLimit;
  final int usedToday;
  final int remainingToday;

  factory AiPaintQuota.fromJson(Map<String, dynamic> json) {
    return AiPaintQuota(
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 0,
      usedToday: (json['usedToday'] as num?)?.toInt() ?? 0,
      remainingToday: (json['remainingToday'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiStylePreset {
  const AiStylePreset({required this.key, required this.label, required this.prefix});

  final String key;
  final String label;
  final String prefix;
}

const aiStylePresets = [
  AiStylePreset(key: 'default', label: '默认', prefix: ''),
  AiStylePreset(key: 'anime', label: '二次元', prefix: '二次元动漫插画风格，精致线条，'),
  AiStylePreset(key: 'cute', label: '可爱', prefix: '可爱萌系风格，明亮色彩，'),
  AiStylePreset(key: 'realistic', label: '写实', prefix: '写实摄影风格，高清细节，'),
  AiStylePreset(key: 'watercolor', label: '水彩', prefix: '水彩手绘风格，柔和笔触，'),
  AiStylePreset(key: 'scifi', label: '科幻', prefix: '科幻未来风格，霓虹光影，'),
];

const aiPromptSuggestions = [
  '夜空下的童话城堡与流星',
  'Q版小猫咪在窗台上晒太阳',
  '樱花树下的古风少女手持团扇',
  '未来感十足的趣玩星球商店',
];

String buildAiPaintPrompt(String rawPrompt, String styleKey) {
  final text = rawPrompt.trim();
  final preset = aiStylePresets.firstWhere(
    (item) => item.key == styleKey,
    orElse: () => aiStylePresets.first,
  );
  final styled = preset.prefix.isEmpty ? text : '${preset.prefix}$text';
  if (styled.startsWith('儿童绘本插画')) return styled;
  return '儿童绘本插画，画面温馨治愈、健康积极，$styled';
}
