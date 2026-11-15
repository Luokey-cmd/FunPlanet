import 'package:flutter/material.dart';

import '../theme/app_scale.dart';

/// AI 生成内容角标（参考 peduliAI ai_generated_label，轻量重写）。
class AiGeneratedBadge extends StatelessWidget {
  const AiGeneratedBadge({
    super.key,
    this.label = 'AI生成',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padH = compact ? AppScale.s(6) : AppScale.s(8);
    final padV = compact ? AppScale.s(2) : AppScale.s(4);
    final fontSize = compact ? AppScale.t(10) : AppScale.t(11);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppScale.s(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
