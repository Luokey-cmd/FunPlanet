import 'dart:typed_data';

import '../data/product_data.dart';
import 'agent_records.dart';

enum ChatRole { user, assistant }

// 分组提问选项（2026-11-26 挑礼物问法定）：服务端随问句下发的
// 结构化选项，替代单组 options 的场合用。mode=each 每组必选一个
// （送给谁+预算合并问）；mode=multi 两组共选 1~2 个、每组最多 1 个
// （类型+系列）；anyOption 是能单独点选直接提交的兜底项（你帮我定）。
// 与 options 一样只活在本次会话里，不落本地记录。
class XiaodouOptionGroup {
  const XiaodouOptionGroup({required this.label, required this.options});

  final String label;
  final List<String> options;

  factory XiaodouOptionGroup.fromJson(Map<String, dynamic> json) {
    return XiaodouOptionGroup(
      label: json['label'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
    );
  }
}

class XiaodouOptionSet {
  const XiaodouOptionSet({required this.mode, required this.groups, this.anyOption});

  final String mode;
  final List<XiaodouOptionGroup> groups;
  final String? anyOption;

  factory XiaodouOptionSet.fromJson(Map<String, dynamic> json) {
    return XiaodouOptionSet(
      mode: json['mode'] as String? ?? 'each',
      groups: (json['groups'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(XiaodouOptionGroup.fromJson)
          .toList(),
      anyOption: json['anyOption'] as String?,
    );
  }
}

// 可领券清单条目（2026-11-26 hx 定：小豆只列券、不代领）：服务端
// list_claimable_coupons 随信下发，页面渲染成带「领取」按钮的卡片，
// 用户点哪张领哪张。status：claimable 可领 / claimed 已领 /
// member 需先开通会员 / unavailable 领完或过期；claiming 是 App
// 本地领取中的临时态，不落记录（存盘时按 claimable 写回）。
class CouponChoice {
  const CouponChoice({
    required this.group,
    required this.title,
    required this.detail,
    required this.status,
    this.statusText = '',
    this.failReason,
  });

  final String group;
  final String title;
  final String detail;
  final String status;
  final String statusText;
  final String? failReason;

  factory CouponChoice.fromJson(Map<String, dynamic> json) {
    return CouponChoice(
      group: json['group'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      status: json['status'] as String? ?? 'claimable',
      statusText: json['statusText'] as String? ?? '',
      failReason: json['failReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group': group,
      'title': title,
      'detail': detail,
      'status': status == 'claiming' ? 'claimable' : status,
      'statusText': statusText,
      if (failReason != null) 'failReason': failReason,
    };
  }

  CouponChoice copyWith({
    String? status,
    String? statusText,
    String? failReason,
    bool clearFailReason = false,
  }) {
    return CouponChoice(
      group: group,
      title: title,
      detail: detail,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      failReason: clearFailReason ? null : (failReason ?? this.failReason),
    );
  }
}

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
    this.optionSet,
    this.couponChoices = const [],
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
  // 分组提问选项（挑礼物两步问法用）；有它时优先于 options 渲染。
  final XiaodouOptionSet? optionSet;

  // 可领券清单（找优惠时下发）：气泡下方渲染成带领取按钮的卡片。
  final List<CouponChoice> couponChoices;

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
    XiaodouOptionSet? optionSet,
    List<CouponChoice>? couponChoices,
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
      optionSet: optionSet ?? this.optionSet,
      couponChoices: couponChoices ?? this.couponChoices,
    );
  }
}
