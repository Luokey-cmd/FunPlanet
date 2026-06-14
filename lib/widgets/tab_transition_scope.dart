import 'package:flutter/material.dart';

class TabTransitionScope extends InheritedWidget {
  const TabTransitionScope({
    super.key,
    required this.isAnimating,
    required super.child,
  });

  final bool isAnimating;

  static TabTransitionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabTransitionScope>();
  }

  static bool isTabAnimating(BuildContext context) {
    return maybeOf(context)?.isAnimating ?? false;
  }

  @override
  bool updateShouldNotify(TabTransitionScope oldWidget) => isAnimating != oldWidget.isAnimating;
}
