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
      imagePath: json['imagePath'] as String,
    );
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
  });

  final String name;
  final int quantity;
  final String? spec;
  final String? productId;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      spec: json['spec'] as String?,
      productId: json['productId'] as String?,
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
    this.reviewedProductIds = const [],
  });

  final String id;
  final String orderNo;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final String time;
  final double? subtotal;
  final double discount;
  final List<String> reviewedProductIds;

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
      reviewedProductIds: reviewedProductIds ?? this.reviewedProductIds,
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
      status: _orderStatusFromString(json['status'] as String),
      time: json['time'] as String,
      reviewedProductIds: (json['reviewedProductIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
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
  });

  final String id;
  final String imagePath;
  final String productId;

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      productId: json['productId'] as String,
    );
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
];

const mallCategoryTags = [
  Category(id: 'all', name: '全部'),
  Category(id: 'toy', name: '玩具'),
  Category(id: 'doll', name: '公仔'),
  Category(id: 'figure', name: '手办'),
  Category(id: 'merch', name: '谷子'),
  Category(id: 'card', name: '小卡'),
  Category(id: 'stationery', name: '文具'),
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

var appBanners = List<BannerItem>.from(fallbackBanners);

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
const oneEyedGiftBoxPath = 'assets/images/独眼礼盒.png';
const inviteCharactersPath = 'assets/images/两小人物.png';
const aiPaintEntryPath = 'assets/images/AI绘画.png';
const aiCommunityEntryPath = 'assets/images/AI社区.png';

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
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final NotificationType type;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      time: time,
      type: type,
      read: read ?? this.read,
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

List<Product> productsByMarketTab(MarketTab tab, {RankingSubTab? rankingSub}) {
  switch (tab) {
    case MarketTab.recommend:
      return List<Product>.from(products)..sort((a, b) => b.rating.compareTo(a.rating));
    case MarketTab.hot:
      final sorted = List<Product>.from(products)..sort((a, b) => b.sales.compareTo(a.sales));
      return sorted;
    case MarketTab.newRelease:
      return products.where((p) => p.tag == '新品').toList();
    case MarketTab.ranking:
      final sorted = List<Product>.from(products)..sort((a, b) {
        if (rankingSub == RankingSubTab.collect) {
          return b.rating.compareTo(a.rating);
        }
        return b.sales.compareTo(a.sales);
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
