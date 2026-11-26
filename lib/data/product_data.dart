import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.price,
    required this.category,
    required this.description,
    required this.purchaseNotes,
    required this.subCategory,
    required this.majorCategory,
    required this.rating,
    required this.sales,
    required this.imagePath,
    this.originalPrice,
    this.tag,
    this.tagColor,
    this.spec,
    this.series,
    this.imageColor,
    this.imageIcon,
    // 下面是后端字段整改后新增的商品信息，老商品没有时为空，不影响原有展示。
    this.imagePaths = const [],
    this.detailImages = const [],
    this.stock = 100,
    this.videoPath,
    this.brand,
    this.rarity,
    this.suitableFor,
    this.sellingPoints = const [],
    // 数据丰富化（2026-11-25）：结构化参数与口碑统计，老商品没有时为空/0，不影响展示。
    this.attributes,
    this.reviewCount = 0,
    this.positiveRate,
    this.favoriteCount = 0,
    this.recentSales = 0,
    this.promoPrice,
    this.promotionName,
    this.promoEndsAt,
  });

  final String id;
  final String name;
  final String nameEn;
  final double price;
  final double? originalPrice;
  final String category;
  final String subCategory;
  final String majorCategory;
  final String? tag;
  final String? tagColor;
  final String description;
  final String purchaseNotes;
  final double rating;
  final int sales;
  final String? spec;
  final String? series;
  final String imagePath;
  final Color? imageColor;
  final IconData? imageIcon;
  // 多图列表（第一张应与 imagePath 主图一致）；为空时详情页只显示主图。
  final List<String> imagePaths;
  // 详情长图列表（详情页介绍区纵向展示）；为空时整段不显示。
  final List<String> detailImages;
  // 库存：老接口没返回时按 100 兜底；详情页用它提示「仅剩 N 件」和售完置灰。
  final int stock;
  final String? videoPath;
  final String? brand;
  final String? rarity;
  final String? suitableFor;
  // 结构化卖点，一条一句，详情页「商品介绍」里逐条展示。
  final List<String> sellingPoints;
  // 结构化参数（材质/尺寸/重量等键值对）：详情页参数表逐行展示，小豆比对也读它。
  final Map<String, String>? attributes;
  // 评价数与好评率：详情页价格区与评价区展示；评价数与接口拉到的评价条数同口径。
  final int reviewCount;
  final int? positiveRate;
  // 收藏数：热度展示用。
  final int favoriteCount;
  // 近 30 天销量：服务端按订单明细实时汇总（见 server/src/routes/products.js），
  // 老接口/本地兜底清单没有这个字段时为 0，「近期热销」会自动退回按总销量兜底排序。
  final int recentSales;
  // 限时特价（营销中心）：接口命中活动时才有值，老接口没有就全空。
  final double? promoPrice;
  final String? promotionName;
  final String? promoEndsAt;

  // 全 App 唯一的价格口径：展示和算钱都用它，不要再直接拿 price 算钱，
  // 否则卡片价、购物车总额和服务端实付会对不上。
  double get effectivePrice => promoPrice ?? price;
  bool get hasPromo => promoPrice != null;

  // 详情页图集：优先用多图，没有多图就退回主图一张。
  List<String> get galleryImages {
    final imgs = imagePaths.where((e) => e.trim().isNotEmpty).toList();
    if (imgs.isNotEmpty) return imgs;
    return imagePath.isNotEmpty ? [imagePath] : const [];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['nameEn'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: json['originalPrice'] == null ? null : (json['originalPrice'] as num).toDouble(),
      category: json['category'] as String,
      subCategory: json['subCategory'] as String,
      majorCategory: json['majorCategory'] as String,
      tag: json['tag'] as String?,
      tagColor: json['tagColor'] as String?,
      description: json['description'] as String,
      purchaseNotes: json['purchaseNotes'] as String,
      rating: (json['rating'] as num).toDouble(),
      sales: json['sales'] as int,
      spec: json['spec'] as String?,
      // series 字段模型里一直有，但 fromJson 以前漏读，接口返回了也用不上，这里补上。
      series: json['series'] as String?,
      imagePath: json['imagePath'] as String,
      // 新字段全部容忍缺失：老接口/本地缓存没有这些键时按空处理，不能抛错。
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
      detailImages: (json['detailImages'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
      stock: (json['stock'] as num?)?.toInt() ?? 100,
      videoPath: json['videoPath'] as String?,
      brand: json['brand'] as String?,
      rarity: json['rarity'] as String?,
      suitableFor: json['suitableFor'] as String?,
      sellingPoints: (json['sellingPoints'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
      attributes: (json['attributes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, '$v'),
      ),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      positiveRate: (json['positiveRate'] as num?)?.toInt(),
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      recentSales: (json['recentSales'] as num?)?.toInt() ?? 0,
      promoPrice: json['promoPrice'] == null ? null : (json['promoPrice'] as num).toDouble(),
      promotionName: json['promotionName'] as String?,
      promoEndsAt: json['promoEndsAt'] as String?,
    );
  }

  // 与 fromJson 一一对应的写回：本地缓存存盘时用（见 ProductCacheService）。
  // imageColor / imageIcon 是界面用的临时值、不来自接口，不进缓存。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'price': price,
      'originalPrice': originalPrice,
      'category': category,
      'subCategory': subCategory,
      'majorCategory': majorCategory,
      'tag': tag,
      'tagColor': tagColor,
      'description': description,
      'purchaseNotes': purchaseNotes,
      'rating': rating,
      'sales': sales,
      'spec': spec,
      'series': series,
      'imagePath': imagePath,
      'imagePaths': imagePaths,
      'detailImages': detailImages,
      'stock': stock,
      'videoPath': videoPath,
      'brand': brand,
      'rarity': rarity,
      'suitableFor': suitableFor,
      'sellingPoints': sellingPoints,
      'attributes': attributes,
      'reviewCount': reviewCount,
      'positiveRate': positiveRate,
      'favoriteCount': favoriteCount,
      'recentSales': recentSales,
      'promoPrice': promoPrice,
      'promotionName': promotionName,
      'promoEndsAt': promoEndsAt,
    };
  }
}

class CartItem {
  const CartItem({required this.product, required this.quantity, this.spec});

  final Product product;
  final int quantity;
  final String? spec;

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity, spec: spec);
  }
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.quantity,
    this.spec,
    this.productId,
    this.imagePath,
    this.unitPrice,
  });

  final String name;
  final int quantity;
  final String? spec;
  final String? productId;
  // 下单时的商品图快照：商品后来改图/下架，订单里仍显示下单时的图。
  final String? imagePath;
  // 下单时的成交单价：服务端 serializeOrder 一直在发，2026-11-26 前 App 没接，
  // 订单详情页要靠它算每件小计；老数据没有时为 null，详情页就不显示单价行。
  final double? unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      spec: json['spec'] as String?,
      productId: json['productId'] as String?,
      imagePath: json['imagePath'] as String?,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
    );
  }
}

enum OrderStatus { pending, paid, shipping, completed, cancelled }

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.items,
    required this.total,
    required this.status,
    required this.time,
    this.subtotal,
    this.discount = 0,
    this.promotionDiscount = 0,
    this.memberDiscount = 0,
    this.promotionName,
    this.reviewedProductIds = const [],
    // 下面是后端字段整改后订单新增的信息，老订单没有时为空。
    this.freight = 0,
    this.remark,
    this.shippingCompany,
    this.trackingNo,
    this.shippedAt,
    this.receivedAt,
    this.cancelReason,
    this.addressName,
    this.addressPhone,
    this.addressDetail,
  });

  final String id;
  final String orderNo;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final String time;
  final double? subtotal;
  final double discount;
  // 满减优惠（营销中心）：与券 discount 分开记，订单详情拆开显示
  final double promotionDiscount;
  // 会员 95 折金额（服务端下单时真打折后回传；老订单/非会员为 0）
  final double memberDiscount;
  final String? promotionName;
  final List<String> reviewedProductIds;
  final double freight;
  final String? remark;
  // 物流：后台发货时填写，App 在订单卡上展示。
  final String? shippingCompany;
  final String? trackingNo;
  final String? shippedAt;
  final String? receivedAt;
  final String? cancelReason;
  // 收货信息快照：服务端 serializeOrder 以 address 对象下发（name/phone/detail），
  // 2026-11-26 前 App 没接；订单详情页展示用，老订单没有时为空、整段不显示。
  final String? addressName;
  final String? addressPhone;
  final String? addressDetail;

  bool get hasTracking => trackingNo != null && trackingNo!.isNotEmpty;

  bool isProductReviewed(String? productId) {
    if (productId == null || productId.isEmpty) return false;
    return reviewedProductIds.contains(productId);
  }

  List<OrderItem> get unreviewedItems =>
      items.where((item) => item.productId != null && !isProductReviewed(item.productId)).toList();

  Order copyWith({OrderStatus? status, List<String>? reviewedProductIds}) {
    return Order(
      id: id,
      orderNo: orderNo,
      items: items,
      total: total,
      status: status ?? this.status,
      time: time,
      subtotal: subtotal,
      discount: discount,
      promotionDiscount: promotionDiscount,
      memberDiscount: memberDiscount,
      promotionName: promotionName,
      reviewedProductIds: reviewedProductIds ?? this.reviewedProductIds,
      // copyWith 只换状态/评价记录，物流等字段必须原样带过去，漏一个就丢一个。
      freight: freight,
      remark: remark,
      shippingCompany: shippingCompany,
      trackingNo: trackingNo,
      shippedAt: shippedAt,
      receivedAt: receivedAt,
      cancelReason: cancelReason,
      addressName: addressName,
      addressPhone: addressPhone,
      addressDetail: addressDetail,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNo: json['orderNo'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? (json['total'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      promotionDiscount: (json['promotionDiscount'] as num?)?.toDouble() ?? 0,
      memberDiscount: (json['memberDiscount'] as num?)?.toDouble() ?? 0,
      promotionName: json['promotionName'] as String?,
      status: _orderStatusFromString(json['status'] as String),
      time: json['time'] as String,
      reviewedProductIds: (json['reviewedProductIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      freight: (json['freight'] as num?)?.toDouble() ?? 0,
      remark: json['remark'] as String?,
      shippingCompany: json['shippingCompany'] as String?,
      trackingNo: json['trackingNo'] as String?,
      shippedAt: json['shippedAt'] as String?,
      receivedAt: json['receivedAt'] as String?,
      cancelReason: json['cancelReason'] as String?,
      addressName: (json['address'] as Map<String, dynamic>?)?['name'] as String?,
      addressPhone: (json['address'] as Map<String, dynamic>?)?['phone'] as String?,
      addressDetail: (json['address'] as Map<String, dynamic>?)?['detail'] as String?,
    );
  }
}

// 售后申请（对应服务端 AfterSaleRequest 表）：
// type: refund 仅退款 / return 退货退款；
// status: pending 待处理 / approved 已同意 / rejected 已拒绝 / completed 已完成。
class AfterSaleRequest {
  const AfterSaleRequest({
    required this.id,
    required this.orderId,
    required this.orderNo,
    required this.type,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.description,
    this.amount,
    this.adminNote,
  });

  final String id;
  final String orderId;
  final String orderNo;
  final String type;
  final String reason;
  final String? description;
  final double? amount;
  final String status;
  final String? adminNote;
  final String createdAt;

  String get typeLabel => type == 'return' ? '退货退款' : '仅退款';

  String get statusLabel => switch (status) {
        'approved' => '已同意',
        'rejected' => '已拒绝',
        'completed' => '已完成',
        _ => '待处理',
      };

  factory AfterSaleRequest.fromJson(Map<String, dynamic> json) {
    return AfterSaleRequest(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      orderNo: json['orderNo'] as String? ?? '',
      type: json['type'] as String? ?? 'refund',
      reason: json['reason'] as String? ?? '',
      description: json['description'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      adminNote: json['adminNote'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

OrderStatus _orderStatusFromString(String value) {
  if (value == 'returned') return OrderStatus.cancelled;
  return OrderStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => OrderStatus.pending,
  );
}

class Coupon {
  const Coupon({
    required this.id,
    required this.title,
    required this.discount,
    required this.condition,
    required this.expire,
    this.used = false,
  });

  final String id;
  final String title;
  final double discount;
  final String condition;
  final String expire;
  final bool used;

  Coupon copyWith({bool? used}) {
    return Coupon(
      id: id,
      title: title,
      discount: discount,
      condition: condition,
      expire: expire,
      used: used ?? this.used,
    );
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      title: json['title'] as String,
      discount: (json['discount'] as num).toDouble(),
      condition: json['condition'] as String,
      expire: json['expire'] as String,
      used: json['used'] as bool? ?? false,
    );
  }
}

class Address {
  const Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.detail,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String phone;
  final String detail;
  final bool isDefault;

  Address copyWith({bool? isDefault}) {
    return Address(
      id: id,
      name: name,
      phone: phone,
      detail: detail,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      detail: json['detail'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}

class BannerItem {
  const BannerItem({
    required this.id,
    required this.imagePath,
    required this.productId,
    this.linkType = 'product',
    this.linkTarget,
  });

  final String id;
  final String imagePath;
  final String productId;

  // 跳转类型：product 点开 productId 那件商品（老横幅）；
  // series 点开系列页，linkTarget 存系列名（2026-11-27 系列横幅）。
  final String linkType;
  final String? linkTarget;

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      productId: json['productId'] as String,
      linkType: json['linkType'] as String? ?? 'product',
      linkTarget: json['linkTarget'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'productId': productId,
      'linkType': linkType,
      'linkTarget': linkTarget,
    };
  }
}

enum MarketTab { recommend, hot, newRelease, ranking }

enum RankingSubTab { collect, sales }

const categoryTags = [
  Category(id: 'toy', name: '玩具'),
  Category(id: 'doll', name: '公仔'),
  Category(id: 'figure', name: '手办'),
  Category(id: 'merch', name: '谷子'),
  Category(id: 'card', name: '小卡'),
  Category(id: 'stationery', name: '文具'),
  Category(id: 'utility', name: '实用类周边'),
];

const mallCategoryTags = [
  Category(id: 'all', name: '全部'),
  Category(id: 'toy', name: '玩具'),
  Category(id: 'doll', name: '公仔'),
  Category(id: 'figure', name: '手办'),
  Category(id: 'merch', name: '谷子'),
  Category(id: 'card', name: '小卡'),
  Category(id: 'stationery', name: '文具'),
  Category(id: 'utility', name: '实用类周边'),
];

const marketTabs = [
  (MarketTab.recommend, '趣玩推荐'),
  (MarketTab.hot, '近期热销'),
  (MarketTab.newRelease, '新品首发'),
  (MarketTab.ranking, '人气榜单'),
];

var products = <Product>[];

void replaceProducts(List<Product> next) {
  products = List<Product>.from(next);
}

const bannerAspectRatio = 2732 / 1534;

const fallbackBanners = [
  BannerItem(
    id: '1',
    imagePath: 'assets/images/banners/banner1.png',
    productId: 'p09',
  ),
  BannerItem(
    id: '2',
    imagePath: 'assets/images/banners/banner2.png',
    productId: 'p38',
  ),
  BannerItem(
    id: '3',
    imagePath: 'assets/images/banners/banner3.png',
    productId: 'p28',
  ),
];

// 系列横幅的内置兜底（与服务端 banners.json 同一批）：离线/老服务端时
// 首页轮播也出得了系列横幅，点开同样进系列页。
const fallbackSeriesBanners = [
  BannerItem(id: 's1', imagePath: 'assets/images/banners/banner-series-canteen.jpg', productId: 'p62', linkType: 'series', linkTarget: '山海小食堂'),
  BannerItem(id: 's2', imagePath: 'assets/images/banners/banner-series-postoffice.jpg', productId: 'p76', linkType: 'series', linkTarget: '星屿邮局'),
  BannerItem(id: 's3', imagePath: 'assets/images/banners/banner-series-circus.jpg', productId: 'p89', linkType: 'series', linkTarget: '月光马戏团'),
  BannerItem(id: 's4', imagePath: 'assets/images/banners/banner-series-neon.jpg', productId: 'p103', linkType: 'series', linkTarget: '霓虹夜行'),
  BannerItem(id: 's5', imagePath: 'assets/images/banners/banner-series-deepsea.jpg', productId: 'p221', linkType: 'series', linkTarget: '深海观测站'),
  BannerItem(id: 's6', imagePath: 'assets/images/banners/banner-series-clockshop.jpg', productId: 'p227', linkType: 'series', linkTarget: '时光钟表店'),
  BannerItem(id: 's7', imagePath: 'assets/images/banners/banner-series-flower.jpg', productId: 'p233', linkType: 'series', linkTarget: '樱庭花艺社'),
  BannerItem(id: 's8', imagePath: 'assets/images/banners/banner-series-aurora.jpg', productId: 'p239', linkType: 'series', linkTarget: '极光观测队'),
];

var appBanners = List<BannerItem>.from([...fallbackBanners, ...fallbackSeriesBanners]);

void replaceBanners(List<BannerItem> next) {
  appBanners = List<BannerItem>.from(next);
}

const profileAvatarPath = '';
const appLogoPath = 'assets/images/趣玩星球logo.png';
const driftBottlePath = 'assets/images/漂流瓶.png';
const memberMascotPath = 'assets/images/会员领好礼IP形象.png';
const memberBadgePath = 'assets/images/会员图标.png';
const memberTargetVipLevel = 2;
const memberSubscribeCoinPrice = 299;

// 趣玩币充值档位（2026-11-26 定 B 方案：1 元 = 15 币）。
// 这份只供 App 展示与选择；真正到账的币数以服务端 profile.js 的
// RECHARGE_PACKAGES 为准（按 id 查表），改档位时两边必须一起改。
class CoinRechargePackage {
  const CoinRechargePackage({required this.id, required this.yuan, required this.coins});

  final String id;
  final int yuan;
  final int coins;

  // 高于基础比例（15 币/元）的部分就是赠送币数，0 表示这档不送。
  int get bonus => coins - yuan * 15;
}

const coinRechargePackages = <CoinRechargePackage>[
  CoinRechargePackage(id: 'r6', yuan: 6, coins: 90),
  CoinRechargePackage(id: 'r12', yuan: 12, coins: 180),
  CoinRechargePackage(id: 'r20', yuan: 20, coins: 320),
  CoinRechargePackage(id: 'r48', yuan: 48, coins: 780),
  CoinRechargePackage(id: 'r98', yuan: 98, coins: 1590),
];
const oneEyedGiftBoxPath = 'assets/images/独眼礼盒.png';
const inviteCharactersPath = 'assets/images/两小人物.png';
const aiPaintEntryPath = 'assets/images/AI绘画.png';
const aiCommunityEntryPath = 'assets/images/AI社区.jpg';

const quickActionIconPaths = {
  '每日任务': 'assets/images/每日任务.png',
  '会员专享': 'assets/images/会员专享.png',
  '领券中心': 'assets/images/领券中心.png',
  '趣玩分类': 'assets/images/趣玩分类.png',
};

const memberBenefitIconPaths = {
  'coupon': 'assets/images/优惠券.png',
  'coins': 'assets/images/金币.png',
  'gift': 'assets/images/礼盒.png',
};

const profileStatIconPaths = {
  'points': 'assets/images/积分.png',
  'coins': 'assets/images/金币.png',
  'coupon': 'assets/images/优惠券.png',
};

enum NotificationType { order, promo, coupon, system, support }

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.time,
  });

  final String id;
  final String title;
  final int amount;
  final String time;

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as int,
      time: _formatNotificationTime(json['createdAt'] as String?),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.read = false,
    this.targetType,
    this.targetId,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final NotificationType type;
  final bool read;

  // 跳转目标：服务端通知自带（targetType 目前只有 'order'）；老通知为空 = 点了不跳。
  final String? targetType;
  final String? targetId;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      time: time,
      type: type,
      read: read ?? this.read,
      targetType: targetType,
      targetId: targetId,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      time: _formatNotificationTime(json['createdAt'] as String?),
      type: _notificationTypeFromString(json['type'] as String),
      read: json['read'] as bool? ?? false,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
    );
  }
}

NotificationType _notificationTypeFromString(String value) {
  return NotificationType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => NotificationType.system,
  );
}

String _formatNotificationTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && now.day == local.day) {
    return '今天 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays == 1) return '昨天 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

List<Product> productsByCategory(String categoryId) {
  if (categoryId.isEmpty || categoryId == 'all') return products;
  return products.where((p) => p.category == categoryId).toList();
}

// 商品编号取数字部分（p123 → 123），取不到按 0 算。
// 市集排序里当「上架先后」用：编号越大上架越晚（App 商品模型没接服务端的 createdAt）。
int _productIdNum(String id) =>
    int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

// 新品穿插（2026-11-27 hx 定稿）：综合分再准也压不住老爆款的销量
// （p22～p38 销量 5500～8600、新系列只有几百），前两屏仍会全是老货；
// 而且 hx 明确更喜欢新商品、不要老商品占大头。所以排完综合分后做一次
// 「偏向新品的随机编织」：新品池与老商品各自保持综合分顺序，
// 合并时每一步约 70% 概率先出新品、30% 出老商品，
// 直到一池用完、另一池依次补齐——新品占多数、位置又不机械。
// 随机种子按当天日期 + 下拉刷新代次定：同一天内不下拉顺序稳定
// （列表重建不会跳来跳去），隔天自动换一套编织；
// 首页/商城下拉刷新一次也会立刻换一套新的（hx 2026-11-27 追加）。
// 只用于推荐流与商城综合列表；热销/收藏/售卖这类榜单是真实名次，不穿插。
// 下拉刷新换序代次：首页与商城下拉刷新时 +1，穿插种子随之改变。
int productShuffleEpoch = 0;

void bumpProductShuffleEpoch() {
  productShuffleEpoch++;
}

// 当前编织代次的种子：当天日期 + 下拉刷新代次。
// 同一代次内不变（列表重建顺序稳定），下拉一次或隔天就换一套。
int _productShuffleSeed() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day + productShuffleEpoch * 100000;
}

// 名次窗口扰动（2026-11-27 hx 拍板「下拉真换一批」）：
// 每件商品的有效名次 = 原名次 ± 15 名内的一个随机偏移，再按有效
// 名次重排；任何商品最多挪 15 名，高分商品不会被甩出前排、低分
// 商品也跳不上首屏。
// 坑（2026-11-27 二次修正）：第一版偏移用「编号杂凑 + 种子」手算，
// 种子只以 +seed×40503 进杂凑、再过一轮乘法取模——相邻种子的偏移
// 几乎整体平移（每件只差约 0.02），排序结果基本不变，下拉了跟没
// 拉一样（hx 真机连拉三次首屏同一件）。改用 math.Random(种子)
// 依次取偏移：同种子序列确定、重建稳定，换种子才真正洗牌。
List<Product> jitterRankedByWindow(List<Product> ranked, {int window = 15}) {
  if (ranked.length < 2) return ranked;
  final rng = math.Random(_productShuffleSeed());
  final keyed = <(double, Product)>[];
  for (var i = 0; i < ranked.length; i++) {
    keyed.add((i + (rng.nextDouble() * 2 - 1) * window, ranked[i]));
  }
  keyed.sort((a, b) => a.$1.compareTo(b.$1));
  return keyed.map((e) => e.$2).toList();
}

List<Product> interleaveNewProducts(List<Product> sorted) {
  // 新旧的线按 hx 的口径：编号 1～61 是 App 最早的老商品，
  // 62 起（八个原创系列）都算新商品、新商品优先出。
  final fresh = sorted.where((p) => _productIdNum(p.id) >= 62).toList();
  if (fresh.isEmpty || fresh.length == sorted.length) return sorted;
  final main = sorted.where((p) => _productIdNum(p.id) < 62).toList();
  final rng = math.Random(_productShuffleSeed());
  final result = <Product>[];
  var mi = 0;
  var fi = 0;
  while (mi < main.length && fi < fresh.length) {
    if (rng.nextDouble() < 0.7) {
      result.add(fresh[fi++]);
    } else {
      result.add(main[mi++]);
    }
  }
  while (fi < fresh.length) {
    result.add(fresh[fi++]);
  }
  while (mi < main.length) {
    result.add(main[mi++]);
  }
  return result;
}

// 首屏防重复（2026-11-27 hx 二次反馈「下拉了还是那几张脸」）：
// 只靠窗口扰动，池头几件高分商品换来换去还是它们。这里记住每个
// 出口上一代次首屏露过的前 12 件，下一代次算完序后把它们整体挪到
// 第 24 位之后——下拉一次，首屏保证全换新脸；再下一代次它们又能
// 回来，不永久消失。同一代次内按 scope 缓存结果，滚动重建不跳序；
// 目录被 replaceProducts 换成新列表对象时缓存自动失效。
final Map<String, List<Product>> _noRepeatCache = {};
final Map<String, Set<String>> _lastScreenIds = {};

List<Product> avoidImmediateRepeats(List<Product> list, {required String scope}) {
  final cacheKey = '$scope|${_productShuffleSeed()}|${identityHashCode(products)}';
  final cached = _noRepeatCache[cacheKey];
  if (cached != null) return cached;
  final shown = _lastScreenIds[scope];
  var result = list;
  if (shown != null && shown.isNotEmpty && list.length > 24) {
    final kept = <Product>[];
    final demoted = <Product>[];
    for (final p in list) {
      (shown.contains(p.id) ? demoted : kept).add(p);
    }
    if (demoted.isNotEmpty) {
      result = [...kept.take(24), ...kept.skip(24), ...demoted];
    }
  }
  _lastScreenIds[scope] = result.take(12).map((p) => p.id).toSet();
  _noRepeatCache
    ..removeWhere((k, _) => k.startsWith('$scope|') && k != cacheKey)
    ..[cacheKey] = result;
  return result;
}

// 市集四个页签的取数与排序（2026-11-26 hx 拍板修正版）。
// 输入：全局 products（服务端按编号正序返回全店商品）；输出：排好序的新列表，不动原列表。
// 坑：全店评分只有 4.6～4.9 四档，只按评分排会有上百件同分、同分顺序等于编号序，
// 所以「趣玩推荐」必须用综合分打破同分；各榜同分时统一用编号大的在前兜底，保证顺序稳定。
List<Product> productsByMarketTab(MarketTab tab, {RankingSubTab? rankingSub}) {
  switch (tab) {
    case MarketTab.recommend:
      // 趣玩推荐 = 综合分：0.40×对数销量分 + 0.25×评分分 + 0.20×对数收藏分 + 0.15×新品分。
      // 销量/收藏差距悬殊（销量最高 8569、中位约 200），直接比原值会焊死老爆款，
      // 取对数压平（与商城页综合排序同口径）；评分分把 4.5 当 0、5.0 当 1 拉开窄区间；
      // 新品分 = 编号÷全店最大编号，让新系列穿插进前排（实测前 30 件约 8 件新系列）。
      final list = List<Product>.from(products);
      if (list.length < 2) return list;
      var maxSales = 0;
      var maxFav = 0;
      var maxId = 0;
      for (final p in list) {
        if (p.sales > maxSales) maxSales = p.sales;
        if (p.favoriteCount > maxFav) maxFav = p.favoriteCount;
        final n = _productIdNum(p.id);
        if (n > maxId) maxId = n;
      }
      final maxLogSales = math.log(maxSales + 1);
      final maxLogFav = math.log(maxFav + 1);
      double score(Product p) {
        final salesPart = maxLogSales > 0 ? math.log(p.sales + 1) / maxLogSales : 0.0;
        final ratingPart = ((p.rating - 4.5) / 0.5).clamp(0.0, 1.0);
        final favPart = maxLogFav > 0 ? math.log(p.favoriteCount + 1) / maxLogFav : 0.0;
        final newPart = maxId > 0 ? _productIdNum(p.id) / maxId : 0.0;
        return 0.40 * salesPart + 0.25 * ratingPart + 0.20 * favPart + 0.15 * newPart;
      }

      list.sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        return byScore != 0 ? byScore : _productIdNum(b.id).compareTo(_productIdNum(a.id));
      });
      // 综合分排完先做名次窗口扰动（不然面孔被铁序锁死、下拉刷新
      // 换不了几件），再做偏向新品的随机穿插（见 interleaveNewProducts），
      // 不然前两屏被老爆款占满、hx 看不到新系列。
      return avoidImmediateRepeats(interleaveNewProducts(jitterRankedByWindow(list)), scope: 'recommend');
    case MarketTab.hot:
      // 近期热销：按近 30 天真实销量 recentSales 排（服务端按订单明细汇总，
      // 虚拟订单也在订单表里、同样计入）——这才和人气榜单·售卖榜（累计总销量）拉开区别，
      // 旧版两边都按总销量排、是完全相同的两张榜。同分依次按总销量、收藏数、编号兜底；
      // recentSales 全为 0（老服务端/本地兜底清单）时自动退化成总销量排序，不会乱序。
      final sorted = List<Product>.from(products)..sort((a, b) {
          final byRecent = b.recentSales.compareTo(a.recentSales);
          if (byRecent != 0) return byRecent;
          final bySales = b.sales.compareTo(a.sales);
          if (bySales != 0) return bySales;
          final byFav = b.favoriteCount.compareTo(a.favoriteCount);
          return byFav != 0 ? byFav : _productIdNum(b.id).compareTo(_productIdNum(a.id));
        });
      return sorted;
    case MarketTab.newRelease:
      // 新品首发：只留「新品」标签，再按编号从大到小——最新上架的排最前，
      // 不再像旧版那样正序把最新商品埋在最后。
      final news = products.where((p) => p.tag == '新品').toList();
      news.sort((a, b) => _productIdNum(b.id).compareTo(_productIdNum(a.id)));
      return news;
    case MarketTab.ranking:
      final sorted = List<Product>.from(products)..sort((a, b) {
        if (rankingSub == RankingSubTab.collect) {
          // 收藏排行榜单：按收藏数 favoriteCount 排（旧版误按评分排，与「趣玩推荐」撞榜）。
          final byFav = b.favoriteCount.compareTo(a.favoriteCount);
          if (byFav != 0) return byFav;
          final bySales = b.sales.compareTo(a.sales);
          return bySales != 0 ? bySales : _productIdNum(b.id).compareTo(_productIdNum(a.id));
        }
        // 售卖排行榜单：按累计总销量排（全历史口径，与「近期热销」的近 30 天口径不同）。
        final bySales = b.sales.compareTo(a.sales);
        if (bySales != 0) return bySales;
        final byFav = b.favoriteCount.compareTo(a.favoriteCount);
        return byFav != 0 ? byFav : _productIdNum(b.id).compareTo(_productIdNum(a.id));
      });
      return sorted;
  }
}

List<Product> searchProducts(String query) {
  final q = query.trim();
  if (q.isEmpty) return [];
  return products.where((p) {
    return p.name.contains(q) ||
        p.nameEn.toLowerCase().contains(q.toLowerCase()) ||
        p.subCategory.contains(q) ||
        p.majorCategory.contains(q) ||
        p.description.contains(q) ||
        (p.series?.contains(q) ?? false) ||
        categoryTags.any((c) => c.name == q && c.id == p.category);
  }).toList();
}

Product? productById(String id) {
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
}

class OrderStatusConfig {
  const OrderStatusConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

OrderStatusConfig orderStatusConfig(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return const OrderStatusConfig(
        label: '待付款',
        icon: Icons.payment_outlined,
        color: Color(0xFFD97706),
        background: Color(0xFFFFFBEB),
      );
    case OrderStatus.paid:
      return const OrderStatusConfig(
        label: '待发货',
        icon: Icons.inventory_2_outlined,
        color: Color(0xFF2563EB),
        background: Color(0xFFEFF6FF),
      );
    case OrderStatus.shipping:
      return const OrderStatusConfig(
        label: '待收货',
        icon: Icons.local_shipping_outlined,
        color: Color(0xFF7C3AED),
        background: Color(0xFFF3E8FF),
      );
    case OrderStatus.completed:
      return const OrderStatusConfig(
        label: '已完成',
        icon: Icons.check_circle_outline,
        color: Color(0xFF16A34A),
        background: Color(0xFFF0FDF4),
      );
    case OrderStatus.cancelled:
      return OrderStatusConfig(
        label: '已退货',
        icon: Icons.assignment_return_outlined,
        color: AppColors.mutedForeground,
        background: AppColors.muted,
      );
  }
}
