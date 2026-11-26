import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/starwish_profile.dart';
import '../providers/starwish_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import 'click_effect/app_buttons.dart';

// 「小豆记得你」弹层（hx 2026-11-27 定版，取代旧星愿档案问卷）：
// 这里不再是进门填的表，而是小豆从对话里自动记住的偏好清单——
// 用户在这里只做三件事：看、改、删。自动沉淀的入口在聊天页的
// 分组问答提交处（StarwishProfileProvider.rememberFromOptions）。
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

  // 「买给谁」单选的当前键：自己用看 purpose，其余看 recipient 原话
  String get _whoKey => _draft.purpose == 'self' ? '自己用' : _draft.recipient;

  void _pickWho(String v) {
    setState(() {
      _draft = v == '自己用'
          ? _draft.copyWith(purpose: 'self', recipient: '')
          : _draft.copyWith(purpose: 'gift', recipient: v);
    });
  }

  // 多选切换：已选再点取消；未满 3 个直接加，满了挤掉最早记的一个
  List<String> _toggle(List<String> list, String v) {
    final next = [...list];
    if (next.contains(v)) {
      next.remove(v);
    } else {
      if (next.length >= 3) next.removeAt(0);
      next.add(v);
    }
    return next;
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
              '这些是小豆从你们聊天里记住的偏好，会自动更新；你也可以在这里改或删。下次挑东西时它会先用这些，不再重复问你。',
              style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground, height: 1.4),
            ),
            SizedBox(height: AppScale.s(14)),
            if (_draft.isEmpty)
              Container(
                padding: EdgeInsets.all(AppScale.s(12)),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(AppScale.s(12)),
                ),
                child: Text(
                  '小豆还没记住什么。跟它聊聊你想买什么、送给谁，它就慢慢记住了。',
                  style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground, height: 1.5),
                ),
              ),
            _label('预算'),
            _chips(
              [('50', '50 内'), ('100', '100 内'), ('200', '200 内'), ('0', '不限')],
              '${_draft.budget}',
              (v) => setState(() => _draft = _draft.copyWith(budget: int.tryParse(v) ?? 0)),
            ),
            SizedBox(height: AppScale.s(12)),
            _label('买给谁'),
            _chips(
              [('自己用', '自己用'), ('送朋友', '送朋友'), ('送对象', '送对象'), ('送家人', '送家人'), ('送同担', '送同担')],
              _whoKey,
              _pickWho,
            ),
            SizedBox(height: AppScale.s(12)),
            _label('喜欢的类型（最多记 3 个）'),
            _multiChips(
              ['玩具', '公仔', '手办', '谷子', '小卡', '文具', '实用周边'],
              _draft.favoriteCategories,
              (v) => setState(() => _draft = _draft.copyWith(favoriteCategories: _toggle(_draft.favoriteCategories, v))),
            ),
            SizedBox(height: AppScale.s(12)),
            _label('喜欢的系列（最多记 3 个）'),
            _multiChips(
              ['星屿邮局', '山海小食堂', '月光马戏团', '霓虹夜行', '深海观测站', '时光钟表店', '樱庭花艺社', '极光观测队'],
              _draft.favoriteSeries,
              (v) => setState(() => _draft = _draft.copyWith(favoriteSeries: _toggle(_draft.favoriteSeries, v))),
            ),
            SizedBox(height: AppScale.s(16)),
            AppFilledButton(
              onPressed: () async {
                await context.read<StarwishProfileProvider>().update(_draft);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('就这么记', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w700)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppTextButton(
                  onPressed: () => setState(() => _draft = const StarwishProfile()),
                  child: Text('全部清空', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.priceRed)),
                ),
                AppTextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('先不改', style: TextStyle(fontSize: AppScale.t(12), color: AppColors.mutedForeground)),
                ),
              ],
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

  Widget _multiChips(List<String> items, List<String> selected, ValueChanged<String> onToggle) {
    return Wrap(
      spacing: AppScale.s(8),
      runSpacing: AppScale.s(8),
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () => onToggle(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(8)),
              decoration: BoxDecoration(
                color: selected.contains(item) ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(AppScale.s(999)),
                border: Border.all(color: selected.contains(item) ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: AppScale.t(12),
                  fontWeight: FontWeight.w600,
                  color: selected.contains(item) ? Colors.white : AppColors.foreground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
