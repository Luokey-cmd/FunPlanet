import 'package:flutter/material.dart';

/// 小豆页图标：按 Lucide / SF Symbols 比例自绘，细线圆角，小尺寸仍清晰。
class XiaodouIcon extends StatelessWidget {
  const XiaodouIcon.gift({super.key, required this.size, required this.color})
      : _kind = _XiaodouIconKind.gift;

  const XiaodouIcon.image({super.key, required this.size, required this.color})
      : _kind = _XiaodouIconKind.image;

  const XiaodouIcon.mic({super.key, required this.size, required this.color})
      : _kind = _XiaodouIconKind.mic;

  const XiaodouIcon.micOn({super.key, required this.size, required this.color})
      : _kind = _XiaodouIconKind.micOn;

  final double size;
  final Color color;
  final _XiaodouIconKind _kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _XiaodouIconPainter(kind: _kind, color: color),
      ),
    );
  }
}

enum _XiaodouIconKind { gift, image, mic, micOn }

class _XiaodouIconPainter extends CustomPainter {
  _XiaodouIconPainter({required this.kind, required this.color});

  final _XiaodouIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (kind) {
      case _XiaodouIconKind.gift:
        _gift(canvas, stroke);
      case _XiaodouIconKind.image:
        _image(canvas, stroke);
      case _XiaodouIconKind.mic:
        _mic(canvas, stroke, fill, on: false);
      case _XiaodouIconKind.micOn:
        _mic(canvas, stroke, fill, on: true);
    }
  }

  // Lucide gift 几何：盒 + 盖 + 十字 + 双环蝴蝶结
  void _gift(Canvas canvas, Paint stroke) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 8, 18, 13), const Radius.circular(2)), stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2, 8, 20, 4), const Radius.circular(1.5)), stroke);
    canvas.drawLine(const Offset(12, 8), const Offset(12, 21), stroke);
    canvas.drawLine(const Offset(3, 12), const Offset(21, 12), stroke);

    final left = Path()
      ..moveTo(12, 8)
      ..cubicTo(12, 8, 10.2, 3.2, 7.2, 3.8)
      ..cubicTo(5.2, 4.2, 5.4, 7.2, 8.2, 8.2)
      ..cubicTo(9.6, 8.7, 11, 8.3, 12, 8);
    final right = Path()
      ..moveTo(12, 8)
      ..cubicTo(12, 8, 13.8, 3.2, 16.8, 3.8)
      ..cubicTo(18.8, 4.2, 18.6, 7.2, 15.8, 8.2)
      ..cubicTo(14.4, 8.7, 13, 8.3, 12, 8);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
  }

  // 相册：后层卡片 + 前层相框（太阳 + 山线）
  void _image(Canvas canvas, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(5.5, 3, 15, 13), const Radius.circular(2.8)),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(3, 6.5, 15.5, 13.5), const Radius.circular(3)),
      stroke,
    );
    canvas.drawCircle(const Offset(7.8, 11), 1.35, stroke);
    final hills = Path()
      ..moveTo(4.2, 18.2)
      ..lineTo(8.4, 13.6)
      ..lineTo(11.2, 16)
      ..lineTo(14.6, 12.2)
      ..lineTo(17.2, 18.2);
    canvas.drawPath(hills, stroke);
  }

  // 胶囊麦头 + 托架弧 + 立杆 + 底座；录音态实心麦头
  void _mic(Canvas canvas, Paint stroke, Paint fill, {required bool on}) {
    final head = RRect.fromRectAndRadius(const Rect.fromLTWH(9, 2.5, 6, 11), const Radius.circular(3));
    if (on) {
      canvas.drawRRect(head, fill);
    } else {
      canvas.drawRRect(head, stroke);
    }

    final yoke = Path()
      ..moveTo(6.5, 11)
      ..quadraticBezierTo(6.5, 17.2, 12, 17.2)
      ..quadraticBezierTo(17.5, 17.2, 17.5, 11);
    canvas.drawPath(yoke, stroke);
    canvas.drawLine(const Offset(12, 17.2), const Offset(12, 20.2), stroke);
    canvas.drawLine(const Offset(8.2, 20.2), const Offset(15.8, 20.2), stroke);
  }

  @override
  bool shouldRepaint(covariant _XiaodouIconPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
