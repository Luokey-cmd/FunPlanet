import 'dart:typed_data';

import '../data/product_data.dart';
import 'agent_records.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
    this.products = const [],
    this.pendingCart = const [],
    this.imageBytes,
    this.starRoles = const [],
    this.giftNote,
    this.isAppraisal = false,
    this.visionPayload,
    this.thinking = '',
    this.actions = const [],
    this.homework = const [],
    this.fateBatches = const [],
    this.fateRolesBatches = const [],
    this.fateIndex = 0,
    this.fateTotal = 0,
    this.fateHasMore = false,
    this.drawArgs = const {},
    this.traits = const {},
    this.options = const [],
    this.optionsUsed = false,
  });

  final ChatRole role;
  final String content;
  final bool isLoading;

  // 智能模式的思考过程（只展示进度用，不进发给服务端的历史、不落本地记录）。
  final String thinking;
  final List<Product> products;
  final List<Product> pendingCart;
  final Uint8List? imageBytes;
  final List<String> starRoles;
  final String? giftNote;
  final bool isAppraisal;
  final Map<String, String>? visionPayload;

  // 办事清单与功课段（Agent 第二步）：只存本地记录，不回发服务端。
  final List<AgentAction> actions;
  final List<HomeworkEntry> homework;

  // 亮牌批次：每一批的三张牌与角色原样存下，上一批/下一批只切下标、
  // 不重新抽；drawArgs 是服务端回带的抽牌条件，「下一批」与牌面
  // 调档（预算/路线）都拿它接着调 draw-batch 接口。
  final List<List<Product>> fateBatches;
  final List<List<String>> fateRolesBatches;
  final int fateIndex;
  final int fateTotal;
  final bool fateHasMore;
  final Map<String, dynamic> drawArgs;

  // 每张牌的特点句（服务端按真实数据算好）：商品 id -> 一句话。
  final Map<String, String> traits;

  // 提问选项（服务端在这条回复以问句收尾时随信下发）：气泡下方
  // 渲染成按钮，点一个就当用户回复；optionsUsed 后整组撤掉。
  final List<String> options;
  final bool optionsUsed;

  bool get hasAgentCard => actions.isNotEmpty || homework.isNotEmpty;

  bool get hasProducts => products.isNotEmpty;
  bool get hasPendingCart => pendingCart.isNotEmpty;
  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
  bool get isFate => starRoles.length >= 2 && products.length >= 2;
  bool get awaitVisionChoice => isAppraisal && visionPayload != null;

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    List<Product>? products,
    List<Product>? pendingCart,
    Uint8List? imageBytes,
    List<String>? starRoles,
    String? giftNote,
    bool? isAppraisal,
    Map<String, String>? visionPayload,
    String? thinking,
    List<AgentAction>? actions,
    List<HomeworkEntry>? homework,
    List<List<Product>>? fateBatches,
    List<List<String>>? fateRolesBatches,
    int? fateIndex,
    int? fateTotal,
    bool? fateHasMore,
    Map<String, dynamic>? drawArgs,
    Map<String, String>? traits,
    List<String>? options,
    bool? optionsUsed,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      pendingCart: pendingCart ?? this.pendingCart,
      imageBytes: imageBytes ?? this.imageBytes,
      starRoles: starRoles ?? this.starRoles,
      giftNote: giftNote ?? this.giftNote,
      isAppraisal: isAppraisal ?? this.isAppraisal,
      visionPayload: visionPayload ?? this.visionPayload,
      thinking: thinking ?? this.thinking,
      actions: actions ?? this.actions,
      homework: homework ?? this.homework,
      fateBatches: fateBatches ?? this.fateBatches,
      fateRolesBatches: fateRolesBatches ?? this.fateRolesBatches,
      fateIndex: fateIndex ?? this.fateIndex,
      fateTotal: fateTotal ?? this.fateTotal,
      fateHasMore: fateHasMore ?? this.fateHasMore,
      drawArgs: drawArgs ?? this.drawArgs,
      traits: traits ?? this.traits,
      options: options ?? this.options,
      optionsUsed: optionsUsed ?? this.optionsUsed,
    );
  }
}
