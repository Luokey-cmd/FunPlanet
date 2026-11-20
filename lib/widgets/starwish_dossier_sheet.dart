import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/starwish_profile.dart';
import '../providers/starwish_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import 'click_effect/app_buttons.dart';

Future<void> showStarwishDossierSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<StarwishProfileProvider>(),
      child: const _StarwishDossierSheet(),
    ),
  );
}

class _StarwishDossierSheet extends StatefulWidget {
  const _StarwishDossierSheet();

  @override
  State<_StarwishDossierSheet> createState() => _StarwishDossierSheetState();
}

class _StarwishDossierSheetState extends State<_StarwishDossierSheet> {
  late StarwishProfile _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<StarwishProfileProvider>().profile;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: EdgeInsets.fromLTRB(AppScale.s(10), 0, AppScale.s(10), AppScale.s(10)),
        padding: EdgeInsets.fromLTRB(AppScale.s(18), AppScale.s(16), AppScale.s(18), AppScale.s(18)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(20)),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '小豆记得你',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppScale.t(18),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppScale.s(4)),
            Text(
              '这些是小豆记住的偏好，随时能改；不改也能直接逛，不挡你买东西。',
              style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground, height: 1.4),
            ),
            SizedBox(height: AppScale.s(14)),
            _label('今晚的心情'),
            _chips([
              ('dream', '梦幻'),
              ('heal', '治愈'),
              ('cool', '帅气'),
              ('funny', '搞怪'),
            ], _draft.mood, (v) => setState(() => _draft = _draft.copyWith(mood: v))),
            SizedBox(height: AppScale.s(12)),
            _label('预算信封'),
            _chips([
              ('30', '30 内'),
              ('50', '50 内'),
              ('100', '100 内'),
              ('0', '不限'),
            ], '${_draft.budget}', (v) => setState(() => _draft = _draft.copyWith(budget: int.tryParse(v) ?? 0))),
            SizedBox(height: AppScale.s(12)),
            _label('此行目的'),
            _chips([
              ('self', '犒劳自己'),
              ('gift', '送给别人'),
              ('browse', '只是逛逛'),
            ], _draft.purpose, (v) => setState(() => _draft = _draft.copyWith(purpose: v))),
            if (_draft.purpose == 'gift') ...[
              SizedBox(height: AppScale.s(12)),
              _label('希望对方感到'),
              _chips([
                ('understood', '被懂'),
                ('comforted', '被哄'),
                ('surprised', '被惊到'),
              ], _draft.giftFeeling, (v) => setState(() => _draft = _draft.copyWith(giftFeeling: v))),
            ],
            SizedBox(height: AppScale.s(16)),
            AppFilledButton(
              onPressed: () async {
                await context.read<StarwishProfileProvider>().update(_draft);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('就这么记', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w700)),
            ),
            AppTextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('先不改', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppScale.s(8)),
      child: Text(text, style: TextStyle(fontSize: AppScale.t(13), fontWeight: FontWeight.w700)),
    );
  }

  Widget _chips(List<(String, String)> items, String selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: AppScale.s(8),
      runSpacing: AppScale.s(8),
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () => onSelect(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(8)),
              decoration: BoxDecoration(
                color: selected == item.$1 ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(AppScale.s(999)),
                border: Border.all(color: selected == item.$1 ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: AppScale.t(12),
                  fontWeight: FontWeight.w600,
                  color: selected == item.$1 ? Colors.white : AppColors.foreground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
