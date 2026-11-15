import '../data/product_data.dart';

int couponMinAmount(String condition) {
  final match = RegExp(r'满(\d+)').firstMatch(condition);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

List<Coupon> eligibleCoupons(List<Coupon> coupons, double subtotal) {
  return coupons.where((c) {
    if (c.used) return false;
    return subtotal >= couponMinAmount(c.condition);
  }).toList()
    ..sort((a, b) => b.discount.compareTo(a.discount));
}

double estimatedPayable(double subtotal, Coupon? coupon) {
  if (coupon == null) return subtotal;
  return (subtotal - coupon.discount).clamp(0, double.infinity);
}
