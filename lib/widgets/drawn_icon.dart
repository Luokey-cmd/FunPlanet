import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

enum DrawnIconStyle { card, line, plain }

class DrawnFeatureIcon extends StatelessWidget {
  const DrawnFeatureIcon({
    super.key,
    required this.type,
    this.size,
    this.backgroundColor,
    this.color,
    this.accentColor,
    this.style = DrawnIconStyle.card,
  });

  final DrawnIconType type;
  final double? size;
  final Color? backgroundColor;
  final Color? color;
  final Color? accentColor;
  final DrawnIconStyle style;

  @override
  Widget build(BuildContext context) {
    final s = size ?? AppScale.s(48);
    final stroke = color ?? (style == DrawnIconStyle.line ? AppColors.foreground : _colorForType(type));
    final accent = accentColor ?? AppColors.primary;
    final painter = _DrawnIconPainter(
      type: type,
      color: stroke,
      accentColor: accent,
      style: style,
    );

    if (style == DrawnIconStyle.card) {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: backgroundColor ?? _bgForType(type),
          borderRadius: BorderRadius.circular(AppScale.s(14)),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
          boxShadow: AppColors.softShadow,
        ),
        child: CustomPaint(painter: painter, size: Size(s, s)),
      );
    }

    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: painter, size: Size(s, s)),
    );
  }

  static Color _bgForType(DrawnIconType type) => switch (type) {
        DrawnIconType.dailyTask => const Color(0xFFFFE8F0),
        DrawnIconType.member => const Color(0xFFFFF0D8),
        DrawnIconType.coupon => const Color(0xFFF0E8FF),
        DrawnIconType.category => const Color(0xFFE8F0FF),
        DrawnIconType.order => const Color(0xFFFFE8F0),
        DrawnIconType.pendingPayment => const Color(0xFFFFE8F0),
        DrawnIconType.address => const Color(0xFFE8F0FF),
        DrawnIconType.favorite => const Color(0xFFFFE8F0),
        DrawnIconType.favoriteStar => const Color(0xFFFFE8F0),
        DrawnIconType.history => const Color(0xFFF0E8FF),
        DrawnIconType.service => const Color(0xFFE8FFF0),
        DrawnIconType.coins => const Color(0xFFFFF0D8),
        DrawnIconType.gift => const Color(0xFFF0E8FF),
        DrawnIconType.shipping => const Color(0xFFE8F0FF),
        DrawnIconType.orderCompleted => const Color(0xFFFFE8F0),
        DrawnIconType.refund => const Color(0xFFFFE8E8),
        DrawnIconType.memberCoupon => const Color(0xFFF0E8FF),
        DrawnIconType.memberPoints => const Color(0xFFF0E8FF),
        DrawnIconType.memberDiscount => const Color(0xFFF0E8FF),
        DrawnIconType.memberGift => const Color(0xFFF0E8FF),
        DrawnIconType.memberShipping => const Color(0xFFF0E8FF),
      };

  static Color _colorForType(DrawnIconType type) => switch (type) {
        DrawnIconType.dailyTask => const Color(0xFFE85588),
        DrawnIconType.member => const Color(0xFFE8A030),
        DrawnIconType.coupon => const Color(0xFF9B7FE8),
        DrawnIconType.category => const Color(0xFF6898E8),
        DrawnIconType.order => const Color(0xFFE85588),
        DrawnIconType.pendingPayment => const Color(0xFFE85588),
        DrawnIconType.address => const Color(0xFF6898E8),
        DrawnIconType.favorite => const Color(0xFFE85588),
        DrawnIconType.favoriteStar => const Color(0xFFE85588),
        DrawnIconType.history => const Color(0xFF9B7FE8),
        DrawnIconType.service => const Color(0xFF55B888),
        DrawnIconType.coins => const Color(0xFFE8A030),
        DrawnIconType.gift => const Color(0xFF9B7FE8),
        DrawnIconType.shipping => const Color(0xFF6898E8),
        DrawnIconType.orderCompleted => const Color(0xFFE85588),
        DrawnIconType.refund => const Color(0xFFE85555),
        DrawnIconType.memberCoupon => AppColors.primary,
        DrawnIconType.memberPoints => AppColors.primary,
        DrawnIconType.memberDiscount => AppColors.primary,
        DrawnIconType.memberGift => AppColors.primary,
        DrawnIconType.memberShipping => AppColors.primary,
      };
}

enum DrawnIconType {
  dailyTask,
  member,
  coupon,
  category,
  order,
  pendingPayment,
  orderCompleted,
  address,
  favorite,
  favoriteStar,
  history,
  service,
  coins,
  gift,
  shipping,
  refund,
  memberCoupon,
  memberPoints,
  memberDiscount,
  memberGift,
  memberShipping,
}

class _DrawnIconPainter extends CustomPainter {
  _DrawnIconPainter({
    required this.type,
    required this.color,
    required this.accentColor,
    required this.style,
  });

  final DrawnIconType type;
  final Color color;
  final Color accentColor;
  final DrawnIconStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = style == DrawnIconStyle.line ? 1.4 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()..color = color.withValues(alpha: style == DrawnIconStyle.line ? 0.08 : 0.15);
    final accentFill = Paint()..color = accentColor;
    final accentStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = style == DrawnIconStyle.line ? 1.5 : 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lineStyle = style == DrawnIconStyle.line;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22;

    switch (type) {
      case DrawnIconType.dailyTask:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2.2, height: r * 2),
          Radius.circular(r * 0.3),
        );
        canvas.drawRRect(rect, paint);
        canvas.drawLine(Offset(cx - r, cy - r * 0.5), Offset(cx + r, cy - r * 0.5), paint);
        canvas.drawCircle(Offset(cx - r * 0.5, cy + r * 0.3), r * 0.15, accentFill);
        canvas.drawCircle(Offset(cx, cy + r * 0.5), r * 0.15, accentFill);
        canvas.drawCircle(Offset(cx + r * 0.5, cy + r * 0.3), r * 0.15, accentFill);
      case DrawnIconType.member:
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, paint);
      case DrawnIconType.coupon:
        _drawCoupon(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle);
      case DrawnIconType.category:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
            Radius.circular(r * 0.3),
          ),
          paint,
        );
        canvas.drawLine(Offset(cx - r * 0.5, cy - r * 0.3), Offset(cx + r * 0.5, cy - r * 0.3), paint);
        canvas.drawLine(Offset(cx - r * 0.5, cy + r * 0.3), Offset(cx + r * 0.5, cy + r * 0.3), paint);
      case DrawnIconType.order:
        _drawClipboard(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle);
      case DrawnIconType.pendingPayment:
        _drawWallet(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle);
      case DrawnIconType.address:
        final path = Path()
          ..moveTo(cx, cy - r)
          ..cubicTo(cx + r * 1.2, cy - r * 0.3, cx + r * 0.8, cy + r, cx, cy + r * 1.1)
          ..cubicTo(cx - r * 0.8, cy + r, cx - r * 1.2, cy - r * 0.3, cx, cy - r);
        if (!lineStyle) canvas.drawPath(path, fill);
        canvas.drawPath(path, paint);
        if (lineStyle) {
          canvas.drawCircle(Offset(cx, cy), r * 0.12, accentFill);
        } else {
          canvas.drawCircle(Offset(cx, cy), r * 0.28, paint);
          canvas.drawCircle(Offset(cx, cy), r * 0.12, accentFill);
        }
      case DrawnIconType.favorite:
        _drawHeart(canvas, Offset(cx, cy), r, paint, fill);
      case DrawnIconType.favoriteStar:
        _drawFavoriteStar(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle);
      case DrawnIconType.history:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        if (lineStyle) {
          canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), accentStroke);
          canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.45, cy), accentStroke);
        } else {
          canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), paint);
          canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.45, cy), paint);
          canvas.drawCircle(Offset(cx + r * 0.15, cy - r * 0.35), r * 0.08, accentFill);
        }
      case DrawnIconType.service:
        _drawHeadset(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle);
      case DrawnIconType.coins:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        _drawYen(canvas, cx, cy, r, lineStyle ? accentStroke : paint, scale: lineStyle ? 1.55 : 1.2);
      case DrawnIconType.gift:
        _drawGift(canvas, cx, cy, r, paint, accentFill);
      case DrawnIconType.shipping:
        if (lineStyle) {
          _drawShippingPackage(canvas, cx, cy, r, paint, accentStroke);
        } else {
          _drawBox(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle, purpleRibbon: true);
        }
      case DrawnIconType.orderCompleted:
        if (lineStyle) {
          _drawCompletedInbox(canvas, cx, cy, r, paint, accentStroke);
        } else {
          _drawBox(canvas, cx, cy, r, paint, accentFill, accentStroke, lineStyle, purpleRibbon: false);
          _drawCheck(canvas, cx + r * 0.05, cy + r * 0.15, r * 0.42, accentStroke);
        }
      case DrawnIconType.refund:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        if (lineStyle) {
          _drawYen(canvas, cx - r * 0.06, cy - r * 0.12, r * 0.72, accentStroke, scale: 1.3);
          final arcRect = Rect.fromCenter(
            center: Offset(cx + r * 0.12, cy + r * 0.18),
            width: r * 0.75,
            height: r * 0.75,
          );
          canvas.drawArc(arcRect, 0.25, 2.05, false, paint);
          canvas.drawLine(
            Offset(cx + r * 0.46, cy + r * 0.44),
            Offset(cx + r * 0.54, cy + r * 0.34),
            paint,
          );
        } else {
          _drawYen(canvas, cx, cy, r * 0.88, accentStroke, scale: 1.2);
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx + r * 0.55, cy - r * 0.55), width: r * 0.9, height: r * 0.9),
            2.4,
            2.2,
            false,
            accentStroke,
          );
          canvas.drawLine(
            Offset(cx + r * 0.85, cy - r * 0.75),
            Offset(cx + r * 1.05, cy - r * 0.95),
            accentStroke,
          );
        }
      case DrawnIconType.memberCoupon:
        _drawCoupon(canvas, cx, cy, r, paint, accentFill, accentStroke, false);
        _drawYen(canvas, cx, cy, r * 0.35, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2, scale: 2.0);
      case DrawnIconType.memberPoints:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        _drawStar(canvas, cx, cy, r * 0.55, paint, accentFill);
      case DrawnIconType.memberDiscount:
        _drawTag(canvas, cx, cy, r, paint, accentFill);
      case DrawnIconType.memberGift:
        _drawGift(canvas, cx, cy, r, paint, accentFill);
      case DrawnIconType.memberShipping:
        _drawTruck(canvas, cx, cy, r, paint, accentFill);
    }
  }

  void _drawCoupon(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent, Paint accentStroke, bool lineStyle) {
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: r * 2.5, height: r * 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)), paint);
    canvas.drawLine(Offset(cx, cy - r * 0.8), Offset(cx, cy + r * 0.8), paint);
    if (lineStyle) {
      canvas.drawLine(Offset(cx - r * 0.35, cy - r * 0.25), Offset(cx + r * 0.35, cy + r * 0.25), accentStroke);
      canvas.drawLine(Offset(cx + r * 0.35, cy - r * 0.25), Offset(cx - r * 0.35, cy + r * 0.25), accentStroke);
    } else {
      canvas.drawCircle(Offset(cx - r * 0.9, cy), r * 0.18, accent);
      canvas.drawCircle(Offset(cx + r * 0.9, cy), r * 0.18, accent);
    }
  }

  void _drawClipboard(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent, Paint accentStroke, bool lineStyle) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.15), width: r * 1.9, height: r * 2.1),
        Radius.circular(r * 0.22),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - r * 0.95), width: r * 0.9, height: r * 0.45),
        Radius.circular(r * 0.12),
      ),
      paint,
    );
    if (lineStyle) {
      canvas.drawLine(Offset(cx - r * 0.45, cy + r * 0.05), Offset(cx + r * 0.45, cy + r * 0.05), accentStroke);
      canvas.drawLine(Offset(cx - r * 0.45, cy + r * 0.45), Offset(cx + r * 0.15, cy + r * 0.45), accentStroke);
      canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.45), r * 0.1, accent);
      canvas.drawCircle(Offset(cx - r * 0.55, cy + r * 0.05), r * 0.08, accent);
    } else {
      canvas.drawLine(Offset(cx - r * 0.45, cy + r * 0.1), Offset(cx + r * 0.45, cy + r * 0.1), paint);
      canvas.drawLine(Offset(cx - r * 0.45, cy + r * 0.55), Offset(cx + r * 0.2, cy + r * 0.55), paint);
      canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.55), r * 0.1, accent);
    }
  }

  void _drawWallet(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent, Paint accentStroke, bool lineStyle) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.1), width: r * 2.2, height: r * 1.6),
        Radius.circular(r * 0.25),
      ),
      paint,
    );
    canvas.drawLine(Offset(cx - r * 0.3, cy - r * 0.35), Offset(cx + r * 0.3, cy - r * 0.35), paint);
    canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.1), r * 0.22, paint);
    if (lineStyle) {
      canvas.drawLine(Offset(cx - r * 0.55, cy + r * 0.05), Offset(cx + r * 0.25, cy + r * 0.05), accentStroke);
    } else {
      canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.1), r * 0.1, accent);
    }
  }

  void _drawBox(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint paint,
    Paint accent,
    Paint accentStroke,
    bool lineStyle, {
    required bool purpleRibbon,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: r * 1.9, height: r * 1.7),
        Radius.circular(r * 0.18),
      ),
      paint,
    );
    final topTape = purpleRibbon ? accentStroke : paint;
    canvas.drawLine(Offset(cx - r * 0.95, cy - r * 0.35), Offset(cx + r * 0.95, cy - r * 0.35), topTape);
    if (purpleRibbon) {
      canvas.drawLine(Offset(cx, cy - r * 0.35), Offset(cx, cy + r * 0.9), accentStroke);
    } else {
      canvas.drawLine(Offset(cx, cy - r * 0.35), Offset(cx, cy + r * 0.9), paint);
      canvas.drawCircle(Offset(cx - r * 0.55, cy + r * 0.15), r * 0.1, accent);
    }
  }

  void _drawShippingPackage(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.08), width: r * 1.85, height: r * 1.65),
        Radius.circular(r * 0.14),
      ),
      paint,
    );
    final lidY = cy - r * 0.18;
    canvas.drawLine(Offset(cx - r * 0.92, lidY), Offset(cx + r * 0.92, lidY), paint);
    canvas.drawLine(Offset(cx - r * 0.72, cy - r * 0.42), Offset(cx + r * 0.72, cy - r * 0.42), accent);
    canvas.drawLine(Offset(cx, cy - r * 0.48), Offset(cx, lidY), accent);
  }

  void _drawCompletedInbox(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.12), width: r * 1.8, height: r * 1.5),
        Radius.circular(r * 0.12),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - r * 0.58), width: r * 0.52, height: r * 0.24),
        Radius.circular(r * 0.08),
      ),
      paint,
    );
    canvas.drawLine(Offset(cx - r * 0.9, cy - r * 0.2), Offset(cx + r * 0.9, cy - r * 0.2), paint);
    _drawCheck(canvas, cx, cy + r * 0.16, r * 0.4, accent);
  }

  void _drawGift(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent) {
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + r * 0.25), width: r * 2, height: r * 1.35), paint);
    canvas.drawLine(Offset(cx - r, cy + r * 0.05), Offset(cx + r, cy + r * 0.05), paint);
    canvas.drawLine(Offset(cx, cy - r * 0.75), Offset(cx, cy + r * 0.95), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - r * 0.35, cy - r * 0.55), width: r * 0.7, height: r * 0.55),
      3.14,
      3.14,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + r * 0.35, cy - r * 0.55), width: r * 0.7, height: r * 0.55),
      3.14,
      3.14,
      false,
      paint,
    );
    canvas.drawCircle(Offset(cx, cy + r * 0.05), r * 0.12, accent);
  }

  void _drawTag(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent) {
    final path = Path()
      ..moveTo(cx - r * 0.9, cy - r * 0.55)
      ..lineTo(cx + r * 0.55, cy - r * 0.55)
      ..lineTo(cx + r * 0.95, cy)
      ..lineTo(cx + r * 0.55, cy + r * 0.55)
      ..lineTo(cx - r * 0.9, cy + r * 0.55)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx - r * 0.45, cy), r * 0.18, accent);
  }

  void _drawTruck(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - r * 0.25, cy + r * 0.05), width: r * 1.7, height: r * 1.1),
        Radius.circular(r * 0.12),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + r * 0.75, cy + r * 0.15), width: r * 0.95, height: r * 0.85),
        Radius.circular(r * 0.1),
      ),
      paint,
    );
    canvas.drawCircle(Offset(cx - r * 0.35, cy + r * 0.75), r * 0.28, paint);
    canvas.drawCircle(Offset(cx + r * 0.75, cy + r * 0.75), r * 0.28, paint);
    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + r * 0.15, cy - r * 0.55), width: r * 0.75, height: r * 0.42),
      Radius.circular(r * 0.08),
    );
    canvas.drawRRect(badge, accent);
  }

  void _drawHeadset(Canvas canvas, double cx, double cy, double r, Paint paint, Paint accent, Paint accentStroke, bool lineStyle) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - r * 0.05), width: r * 1.6, height: r * 1.5),
      3.14,
      3.14,
      false,
      paint,
    );
    final leftCup = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - r * 0.85, cy + r * 0.15), width: r * 0.45, height: r * 0.75),
      Radius.circular(r * 0.12),
    );
    final rightCup = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + r * 0.85, cy + r * 0.15), width: r * 0.45, height: r * 0.75),
      Radius.circular(r * 0.12),
    );
    if (lineStyle) {
      canvas.drawRRect(leftCup, paint);
      canvas.drawRRect(rightCup, paint);
      canvas.drawRRect(leftCup.deflate(r * 0.12), Paint()..color = accent.color.withValues(alpha: 0.35)..style = PaintingStyle.fill);
      canvas.drawRRect(rightCup.deflate(r * 0.12), Paint()..color = accent.color.withValues(alpha: 0.35)..style = PaintingStyle.fill);
    } else {
      canvas.drawRRect(leftCup, paint);
      canvas.drawRRect(rightCup, paint);
    }
    canvas.drawLine(Offset(cx - r * 0.2, cy + r * 0.55), Offset(cx + r * 0.2, cy + r * 0.55), paint);
    if (!lineStyle) canvas.drawCircle(Offset(cx, cy + r * 0.55), r * 0.1, accent);
  }

  void _drawFavoriteStar(Canvas canvas, double cx, double cy, double r, Paint stroke, Paint accent, Paint accentStroke, bool lineStyle) {
    _drawStarPath(canvas, cx, cy, r, stroke);
    if (lineStyle) {
      _drawStarPath(canvas, cx, cy, r * 0.48, accentStroke, fill: accent, fillAlpha: 0.55);
    }
  }

  void _drawStarPath(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint stroke, {
    Paint? fill,
    double fillAlpha = 0.25,
  }) {
    final star = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.28, cy - r * 0.28)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + r * 0.28, cy + r * 0.28)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.28, cy + r * 0.28)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - r * 0.28, cy - r * 0.28)
      ..close();
    if (fill != null) {
      canvas.drawPath(star, Paint()..color = fill.color.withValues(alpha: fillAlpha));
    }
    canvas.drawPath(star, stroke);
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, Paint stroke, Paint fill) {
    _drawStarPath(canvas, cx, cy, r, stroke, fill: fill);
  }

  void _drawCheck(Canvas canvas, double cx, double cy, double r, Paint paint) {
    canvas.drawLine(Offset(cx - r, cy), Offset(cx - r * 0.2, cy + r * 0.65), paint);
    canvas.drawLine(Offset(cx - r * 0.2, cy + r * 0.65), Offset(cx + r, cy - r * 0.55), paint);
  }

  void _drawYen(Canvas canvas, double cx, double cy, double radius, Paint paint, {double scale = 1.5}) {
    final fontSize = radius * scale;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '¥',
        style: TextStyle(
          fontSize: fontSize,
          color: paint.color,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2 - fontSize * 0.02),
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(center.dx, center.dy + r * 0.8)
      ..cubicTo(center.dx - r * 1.5, center.dy - r * 0.2, center.dx - r * 0.5, center.dy - r, center.dx, center.dy - r * 0.3)
      ..cubicTo(center.dx + r * 0.5, center.dy - r, center.dx + r * 1.5, center.dy - r * 0.2, center.dx, center.dy + r * 0.8);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _DrawnIconPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.style != style;
}
