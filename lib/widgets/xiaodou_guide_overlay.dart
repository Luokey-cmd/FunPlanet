import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/xiaodou_guide_cards.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import 'click_effect/app_buttons.dart';
import 'floating_ai_assistant.dart';
import 'product_image.dart';

class XiaodouGuideOverlay extends StatefulWidget {
  const XiaodouGuideOverlay({
    super.key,
    required this.onFinished,
    required this.onOpenXiaodou,
  });

  final VoidCallback onFinished;
  final VoidCallback onOpenXiaodou;

  @override
  State<XiaodouGuideOverlay> createState() => _XiaodouGuideOverlayState();
}

class _XiaodouGuideOverlayState extends State<XiaodouGuideOverlay> with SingleTickerProviderStateMixin {
  final _page = PageController(viewportFraction: 0.96);
  late final AnimationController _twinkle;
  int _index = 0;

  bool get _isLast => _index >= xiaodouGuideCards.length - 1;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onOpenXiaodou();
      return;
    }
    _page.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC1B1238), Color(0xB32D1B55), Color(0x99140C28)],
                  ),
                ),
              ),
              CustomPaint(painter: _StarfieldPainter(t: _twinkle.value), child: const SizedBox.expand()),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(8), AppScale.s(16), AppScale.s(12)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '星愿入门笺',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppScale.t(13),
                              color: AppColors.gold.withValues(alpha: 0.92),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          AppTextButton(
                            onPressed: widget.onFinished,
                            child: Text(
                              '这次先不看说明书',
                              style: TextStyle(
                                fontSize: AppScale.t(12),
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _page,
                          itemCount: xiaodouGuideCards.length,
                          onPageChanged: (value) => setState(() => _index = value),
                          itemBuilder: (context, index) {
                            final isLast = index >= xiaodouGuideCards.length - 1;
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppScale.s(6),
                                horizontal: AppScale.s(2),
                              ),
                              child: _EnchantedCard(
                                card: xiaodouGuideCards[index],
                                twinkle: _twinkle.value,
                                highlighted: index == _index,
                                pageIndex: index,
                                pageCount: xiaodouGuideCards.length,
                                isLast: isLast,
                                onPrimary: isLast ? widget.onOpenXiaodou : _next,
                                onSecondary: isLast ? widget.onFinished : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnchantedCard extends StatelessWidget {
  const _EnchantedCard({
    required this.card,
    required this.twinkle,
    required this.highlighted,
    required this.pageIndex,
    required this.pageCount,
    required this.isLast,
    required this.onPrimary,
    this.onSecondary,
  });

  final XiaodouGuideCard card;
  final double twinkle;
  final bool highlighted;
  final int pageIndex;
  final int pageCount;
  final bool isLast;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final glow = 0.28 + 0.12 * math.sin(twinkle * math.pi * 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppScale.s(26)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A227).withValues(alpha: highlighted ? glow : 0.12),
            blurRadius: AppScale.s(28),
            spreadRadius: AppScale.s(1),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: AppScale.s(18),
            offset: Offset(0, AppScale.s(10)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppScale.s(26)),
        child: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF8EC), Color(0xFFF4E7FF), Color(0xFFE7D7FF)],
                ),
              ),
              child: SizedBox.expand(),
            ),
            CustomPaint(painter: _CardOrnamentPainter(t: twinkle), child: const SizedBox.expand()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + twinkle * 2, -1),
                      end: Alignment(-0.2 + twinkle * 2, 0.4),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(18), AppScale.s(16), AppScale.s(18), AppScale.s(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '星愿笺 · ${card.badge}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppScale.t(12),
                          color: const Color(0xFF7A5A12),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      _WaxSeal(label: card.seal),
                    ],
                  ),
                  SizedBox(height: AppScale.s(10)),
                  _MoonPortrait(twinkle: twinkle),
                  SizedBox(height: AppScale.s(12)),
                  Text(
                    card.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppScale.t(20),
                      fontWeight: FontWeight.w800,
                      height: 1.32,
                      color: const Color(0xFF3A245C),
                    ),
                  ),
                  SizedBox(height: AppScale.s(8)),
                  Container(
                    width: AppScale.s(64),
                    height: 1.2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00C9A227), Color(0xFFC9A227), Color(0x00C9A227)],
                      ),
                    ),
                  ),
                  SizedBox(height: AppScale.s(10)),
                  // 正文：上方内容区，下方留白给按钮（对齐截图2的大卡比例）
                  Text(
                    card.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppScale.t(14),
                      height: 1.62,
                      color: const Color(0xFF5C4A78),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pageCount; i++)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppScale.s(4)),
                          child: Icon(
                            i == pageIndex ? Icons.auto_awesome : Icons.star_border_rounded,
                            size: i == pageIndex ? AppScale.s(15) : AppScale.s(11),
                            color: i == pageIndex ? AppColors.gold : const Color(0xFFB8A8D4),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: AppScale.s(12)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppScale.s(999)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.32),
                          blurRadius: AppScale.s(12),
                          offset: Offset(0, AppScale.s(3)),
                        ),
                      ],
                    ),
                    child: AppFilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B3FA8),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, AppScale.s(48)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(999)),
                          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.75), width: 1.2),
                        ),
                      ),
                      child: Text(
                        card.nextLabel,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppScale.t(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (isLast && onSecondary != null)
                    AppTextButton(
                      onPressed: onSecondary,
                      child: Text(
                        '先自己在星球上乱跑',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppScale.t(12),
                          color: const Color(0xFF7A6A98),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaxSeal extends StatelessWidget {
  const _WaxSeal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(5)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8B84A), Color(0xFFC48A1A)],
        ),
        borderRadius: BorderRadius.circular(AppScale.s(999)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC48A1A).withValues(alpha: 0.35),
            blurRadius: AppScale.s(6),
            offset: Offset(0, AppScale.s(2)),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppScale.t(11),
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MoonPortrait extends StatelessWidget {
  const _MoonPortrait({required this.twinkle});

  final double twinkle;

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + 0.03 * math.sin(twinkle * math.pi * 2);
    return SizedBox(
      width: AppScale.s(148),
      height: AppScale.s(148),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: pulse,
            child: Container(
              width: AppScale.s(148),
              height: AppScale.s(148),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.35),
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: AppScale.s(118),
            height: AppScale.s(118),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF3C4), Color(0xFFE8D4FF), Color(0xFFC9B4F5)],
              ),
              border: Border.all(color: const Color(0xFFE8B84A), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: AppScale.s(12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ProductImage(
              image: FloatingAiAssistant.assetFull,
              width: AppScale.s(118),
              height: AppScale.s(118),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: AppScale.s(8),
            right: AppScale.s(18),
            child: Icon(Icons.auto_awesome, size: AppScale.s(14), color: AppColors.gold.withValues(alpha: 0.9)),
          ),
          Positioned(
            bottom: AppScale.s(16),
            left: AppScale.s(14),
            child: Icon(Icons.star_rounded, size: AppScale.s(11), color: AppColors.accent.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 42; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final phase = (t + random.nextDouble()) % 1;
      final alpha = 0.15 + 0.55 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
      paint.color = (i.isEven ? AppColors.gold : Colors.white).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.7 + random.nextDouble() * 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) => oldDelegate.t != t;
}

class _CardOrnamentPainter extends CustomPainter {
  _CardOrnamentPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [Color(0xFFE8B84A), Color(0xFFF6E7B2), Color(0xFFC48A1A)],
      );

    final inset = 8.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, gold);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x66C9A227);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset + 4, inset + 4, size.width - (inset + 4) * 2, size.height - (inset + 4) * 2),
        const Radius.circular(16),
      ),
      inner,
    );

    final arm = 18.0;
    void corner(Offset o, double sx, double sy) {
      final p = Path()
        ..moveTo(o.dx + sx * arm, o.dy)
        ..lineTo(o.dx, o.dy)
        ..lineTo(o.dx, o.dy + sy * arm);
      canvas.drawPath(p, gold);
    }

    corner(Offset(inset + 10, inset + 10), 1, 1);
    corner(Offset(size.width - inset - 10, inset + 10), -1, 1);
    corner(Offset(inset + 10, size.height - inset - 10), 1, -1);
    corner(Offset(size.width - inset - 10, size.height - inset - 10), -1, -1);

    final spark = Paint()..color = AppColors.gold.withValues(alpha: 0.35 + 0.25 * math.sin(t * math.pi * 2));
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.22), 2.2, spark);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.28), 1.6, spark);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.78), 1.8, spark);
  }

  @override
  bool shouldRepaint(_CardOrnamentPainter oldDelegate) => oldDelegate.t != t;
}
