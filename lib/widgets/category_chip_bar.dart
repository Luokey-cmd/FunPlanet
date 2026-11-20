import 'package:flutter/material.dart';
import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

import '../widgets/click_effect/app_pressable.dart';
class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({
    super.key,
    required this.activeId,
    required this.onSelected,
    this.categories,
    this.compact = false,
    this.highlightActive = true,
    this.padding,
    this.chipHorizontalPadding,
    this.chipVerticalPadding,
    this.barHeight,
    this.scale = 1.0,
  });

  final String activeId;
  final ValueChanged<Category> onSelected;
  final List<Category>? categories;
  final bool compact;
  final bool highlightActive;
  final EdgeInsetsGeometry? padding;
  final double? chipHorizontalPadding;
  final double? chipVerticalPadding;
  final double? barHeight;
  final double scale;

  double _s(double value) => AppScale.s(value * scale);

  @override
  Widget build(BuildContext context) {
    final barHeight = _s(this.barHeight ?? (compact ? 26 : 34)) + AppScale.fontBump;
    final hPad = _s(chipHorizontalPadding ?? (compact ? 10 : 12));
    final vPad = _s(chipVerticalPadding ?? (compact ? 3 : 6));
    // 字号走全 App 统一的 t（写几号是几号），只保留本组件的 scale 放大意图
    // （商城页传 1.2 时文字跟着放大）；旧写法拿布局系数算字号再 +fontBump，
    // 已随 2026-11-20 字体规范化废除。
    final fontSize = AppScale.t((compact ? 12 : 13) * scale);
    final gap = compact ? _s(5) : _s(6);

    final items = categories ?? categoryTags;
    return SizedBox(
      height: barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.symmetric(horizontal: _s(16)),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, index) {
          final cat = items[index];
          final active = highlightActive && activeId == cat.id;
          return AppGestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(_s(999)),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? Colors.white : AppColors.secondaryForeground,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
