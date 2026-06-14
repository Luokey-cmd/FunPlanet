import 'package:flutter/material.dart';
import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

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
    final barHeight = _s(this.barHeight ?? (compact ? 26 : 34));
    final hPad = _s(chipHorizontalPadding ?? (compact ? 10 : 12));
    final vPad = _s(chipVerticalPadding ?? (compact ? 3 : 6));
    final fontSize = compact ? _s(12) : _s(13);
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
          return GestureDetector(
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
                boxShadow: active ? null : AppColors.softShadow,
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
