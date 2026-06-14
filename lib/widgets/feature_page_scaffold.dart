import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import 'sparkle_background.dart';

class FeaturePageScaffold extends StatelessWidget {
  const FeaturePageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = scrollable
        ? SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(16), FeaturePageStyle.s(8), FeaturePageStyle.s(16), FeaturePageStyle.s(24)),
            child: child,
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(16), FeaturePageStyle.s(8), FeaturePageStyle.s(16), FeaturePageStyle.s(16)),
            child: child,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(FeaturePageStyle.s(4), FeaturePageStyle.s(4), FeaturePageStyle.s(8), FeaturePageStyle.s(4)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: AppColors.foreground, size: FeaturePageStyle.iconSize),
                    ),
                    Expanded(
                      child: Text(title, style: FeaturePageStyle.pageTitle()),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

void openFeaturePage(BuildContext context, {required String title, required Widget child, bool scrollable = true}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => FeaturePageScaffold(title: title, scrollable: scrollable, child: child),
    ),
  );
}
