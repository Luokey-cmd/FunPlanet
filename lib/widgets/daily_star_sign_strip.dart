import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../pages/xiaodou_chat_page.dart';
import '../providers/user_provider.dart';
import '../services/daily_star_sign_picker.dart';
import '../services/daily_star_sign_storage.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'click_effect/app_pressable.dart';
import 'daily_star_sign_sheet.dart';

/// 首页常驻条：今日星签的安静入口（白底一行，不做奇幻大横幅）。
///
/// 未翻显示「今日星签还没翻 · 去翻牌」，已翻显示今天的商品名。
/// 监听 DailyStarSignStorage.revision，半屏层里状态变了它跟着刷新。
class DailyStarSignStrip extends StatefulWidget {
  const DailyStarSignStrip({super.key});

  @override
  State<DailyStarSignStrip> createState() => _DailyStarSignStripState();
}

class _DailyStarSignStripState extends State<DailyStarSignStrip> {
  final _storage = DailyStarSignStorage();
  DailyStarSignRecord? _record;
  Product? _product;

  @override
  void initState() {
    super.initState();
    DailyStarSignStorage.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DailyStarSignStorage.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final userId = context.read<UserProvider>().userId;
    final record = await _storage.readToday(userId);
    if (!mounted) return;
    Product? product;
    final pid = record?.productId;
    if (pid != null) {
      for (final p in products) {
        if (p.id == pid) {
          product = p;
          break;
        }
      }
    }
    setState(() {
      _record = record;
      _product = product;
    });
  }

  Future<void> _open() async {
    final user = context.read<UserProvider>();
    final userId = user.userId;
    var record = _record;
    var product = _product;
    if (record == null || product == null) {
      // 还没挑过（比如当天让给引导层的 skipped）：打开时现挑一张。
      product = DailyStarSignPicker.pick(
        pool: products,
        browseHistoryIds: user.browseHistory,
        favoriteIds: user.favoriteIds,
        recentProductIds: await _storage.recentProductIds(userId),
        userId: userId,
        dateStr: DailyStarSignStorage.todayString(),
      );
      if (!mounted || product == null) return;
      record = DailyStarSignRecord(
        date: DailyStarSignStorage.todayString(),
        state: DailyStarSignState.popped,
        productId: product.id,
      );
      await _storage.save(userId, record);
    }
    if (!mounted) return;
    await showDailyStarSignSheet(
      context,
      userId: userId,
      record: record,
      product: product,
      onDrawTriple: () {
        if (mounted) XiaodouChatPage.open(context, autoDraw: true);
      },
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final flipped =
        _product != null &&
        (_record?.state == DailyStarSignState.flipped ||
            _record?.state == DailyStarSignState.done);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(16)),
      child: AppPressable(
        child: GestureDetector(
          onTap: _open,
          child: Container(
            height: AppScale.s(48),
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(14)),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppScale.s(14)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: AppScale.s(26),
                  height: AppScale.s(26),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF251E54), Color(0xFF171238)],
                    ),
                  ),
                  child: Icon(
                    Icons.nightlight_round,
                    size: AppScale.s(15),
                    color: AppColors.gold,
                  ),
                ),
                SizedBox(width: AppScale.s(10)),
                Expanded(
                  child: Text(
                    flipped ? '今日星签：${_product!.name}' : '今日星签还没翻',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppScale.t(13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  flipped ? '看牌' : '去翻牌',
                  style: TextStyle(
                    fontSize: AppScale.t(12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppScale.s(18),
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
