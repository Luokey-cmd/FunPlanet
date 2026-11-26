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

// 绘画风格预设（2026-11-26 加厚扩容）：每个风格带齐媒介、光影、构图、色调四类词，
// 只靠一句十来字的短前缀压不住模型的默认审美、出来的图会全长一个样。
// key 是存进作品记录的稳定标识：老 key（default/anime/cute/realistic/watercolor/scifi）
// 一个不改、只加新 key，老作品的风格回显不受影响。
const aiStylePresets = [
  AiStylePreset(key: 'default', label: '默认', prefix: ''),
  AiStylePreset(key: 'anime', label: '二次元', prefix: '二次元动漫插画，精致干净的线条，赛璐璐上色，色彩鲜明通透，人物比例协调，'),
  AiStylePreset(key: 'cute', label: '可爱', prefix: '可爱萌系插画，圆润造型，奶油色调，柔和漫射光，画面明亮轻快，'),
  AiStylePreset(key: 'realistic', label: '写实', prefix: '写实摄影，单反相机实拍质感，真实自然光影，皮肤与材质细节丰富，景深虚化，'),
  AiStylePreset(key: 'watercolor', label: '水彩', prefix: '水彩手绘，透明水痕与纸纹肌理，柔和晕染，留白构图，色调清雅，'),
  AiStylePreset(key: 'scifi', label: '科幻', prefix: '科幻概念设计，未来机械与霓虹光影，冷色调，强对比明暗，电影感构图，'),
  AiStylePreset(key: 'picturebook', label: '绘本', prefix: '儿童绘本插画，温馨治愈，手绘质感，柔和配色，故事感构图，'),
  AiStylePreset(key: 'oilpaint', label: '油画', prefix: '古典油画，厚涂笔触，厚重肌理感，深沉丰富的色调，伦勃朗式明暗，'),
  AiStylePreset(key: 'guofeng', label: '国风', prefix: '中国风工笔插画，细腻勾线，矿物色设色，东方留白构图，典雅意境，'),
  AiStylePreset(key: 'pixel', label: '像素', prefix: '像素艺术，16-bit 游戏画面质感，色块分明，细节用有限色板表现，'),
  AiStylePreset(key: 'threed', label: '3D渲染', prefix: '3D 渲染，皮克斯动画质感，柔和全局光照，圆润建模，材质细腻，'),
  AiStylePreset(key: 'film', label: '胶片', prefix: '胶片摄影，柯达 Portra 色调，细腻颗粒，柔和自然光，生活气息抓拍感，'),
  AiStylePreset(key: 'ink', label: '水墨', prefix: '水墨画，墨色浓淡干湿，宣纸肌理，大面积留白，写意构图，'),
];

// 画幅预设：key 存 App 状态，size 是发给服务端的像素尺寸（服务端还有一层白名单校验）。
class AiRatioPreset {
  const AiRatioPreset({required this.key, required this.label, required this.size});

  final String key;
  final String label;
  final String size;
}

const aiRatioPresets = [
  AiRatioPreset(key: 'square', label: '1:1 方图', size: '1280*1280'),
  AiRatioPreset(key: 'portrait', label: '3:4 竖图', size: '960*1280'),
  AiRatioPreset(key: 'landscape', label: '4:3 横图', size: '1280*960'),
  AiRatioPreset(key: 'wide', label: '16:9 宽屏', size: '1280*720'),
  AiRatioPreset(key: 'tall', label: '9:16 长图', size: '720*1280'),
];

const aiPromptSuggestions = [
  '夜空下的童话城堡与流星',
  'Q版小猫咪在窗台上晒太阳',
  '樱花树下的古风少女手持团扇',
  '未来感十足的趣玩星球商店',
  '雨后老街的咖啡馆，行人撑着伞',
  '雪山湖泊边的木屋清晨',
];

// 拼最终提示词：风格前缀 + 用户原话，仅此而已（2026-11-26 修正）。
// 旧版会给每张图强制加「儿童绘本插画，温馨治愈」前缀，结果选什么风格出来的都一个味；
// 现在想要绘本风就选「绘本」风格，安全把控交给服务端负面词与平台审核，不再写进画风。
String buildAiPaintPrompt(String rawPrompt, String styleKey) {
  final text = rawPrompt.trim();
  final preset = aiStylePresets.firstWhere(
    (item) => item.key == styleKey,
    orElse: () => aiStylePresets.first,
  );
  return preset.prefix.isEmpty ? text : '${preset.prefix}$text';
}
