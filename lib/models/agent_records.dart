// 小豆办事清单与功课段的数据模型（Agent 第二步「长手」）。
//
// 来源：服务端在聊天流里推的 actions / homework 事件，字段口径与
// 服务端 xiaodou-tools.js 的 makeAction 完全对齐，这里只做解析与
// 本地保存，不许在 App 侧自己编数字（金额、件数都以服务端为准）。
// 这两类数据只存手机本地聊天记录，不回发给服务端当对话历史。

/// 待付款订单的账（付款闸用）：数字不全时清单卡不显示确认按钮。
class AgentActionPayment {
  const AgentActionPayment({
    required this.subtotal,
    required this.discount,
    required this.freight,
    required this.total,
    this.couponTitle,
  });

  final double subtotal;
  final double discount;
  final double freight;
  final double total;
  final String? couponTitle;

  factory AgentActionPayment.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return AgentActionPayment(
      subtotal: toD(json['subtotal']),
      discount: toD(json['discount']),
      freight: toD(json['freight']),
      total: toD(json['total']),
      couponTitle: json['couponTitle'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'subtotal': subtotal,
        'discount': discount,
        'freight': freight,
        'total': total,
        if (couponTitle != null) 'couponTitle': couponTitle,
      };
}

/// 办事清单的一条：小豆真办成（或没办成）的一件事。
class AgentAction {
  const AgentAction({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.status,
    this.failReason,
    this.saved = 0,
    this.target = const {},
    this.payment,
  });

  final String id;

  /// coupon / cart_add / cart_update / favorite / order_note / order_create
  final String type;
  final String title;
  final String detail;

  /// done 已办好 / pending 待确认（只有待付款订单）/ failed 没办成
  final String status;
  final String? failReason;

  /// 这条省了多少钱（目前只有用券下单会带），卡头「共省」靠它汇总。
  final double saved;

  /// 点击跳哪：{page: cart/coupons/favorites/order/addresses, id?, productId?, orderNo?}
  final Map<String, String> target;
  final AgentActionPayment? payment;

  bool get isPendingOrder => type == 'order_create' && status == 'pending' && payment != null;

  factory AgentAction.fromJson(Map<String, dynamic> json) {
    final rawTarget = json['target'];
    final target = <String, String>{};
    if (rawTarget is Map) {
      rawTarget.forEach((key, value) {
        if (value != null) target['$key'] = '$value';
      });
    }
    final rawPayment = json['payment'];
    return AgentAction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      status: json['status'] as String? ?? 'done',
      failReason: json['failReason'] as String?,
      saved: (json['saved'] as num?)?.toDouble() ?? 0,
      target: target,
      payment: rawPayment is Map<String, dynamic> ? AgentActionPayment.fromJson(rawPayment) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'detail': detail,
        'status': status,
        if (failReason != null) 'failReason': failReason,
        if (saved != 0) 'saved': saved,
        if (target.isNotEmpty) 'target': target,
        if (payment != null) 'payment': payment!.toJson(),
      };

  AgentAction copyWith({String? status, String? detail}) {
    return AgentAction(
      id: id,
      type: type,
      title: title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      failReason: failReason,
      saved: saved,
      target: target,
      payment: payment,
    );
  }
}

/// 功课段里可点开的候选明细一行（名字 + 价格，都是工具真实返回）。
class HomeworkCandidate {
  const HomeworkCandidate({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final double price;

  factory HomeworkCandidate.fromJson(Map<String, dynamic> json) {
    return HomeworkCandidate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

/// 功课段的一条：选定商品之前小豆做的一件功课，带真实数字。
class HomeworkEntry {
  const HomeworkEntry({required this.text, this.candidates = const []});

  final String text;
  final List<HomeworkCandidate> candidates;

  factory HomeworkEntry.fromJson(Map<String, dynamic> json) {
    return HomeworkEntry(
      text: json['text'] as String? ?? '',
      candidates: (json['candidates'] as List<dynamic>? ?? [])
          .map((e) => HomeworkCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (candidates.isNotEmpty) 'candidates': candidates.map((c) => c.toJson()).toList(),
      };
}
