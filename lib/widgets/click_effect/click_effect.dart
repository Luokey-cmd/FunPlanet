import 'package:flutter/material.dart';
import 'click_effect_host.dart';

export 'click_effect_host.dart';
export 'app_pressable.dart';
export 'app_icon_button.dart';
export 'app_buttons.dart';

/// MaterialApp.builder 用：注入全局点击粒子层。
Widget wrapWithClickEffect(BuildContext context, Widget? child) {
  return ClickEffectHost(child: child ?? const SizedBox.shrink());
}
