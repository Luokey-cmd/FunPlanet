import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/feature_page_scaffold.dart';
import 'address_edit_page.dart';
import 'member_benefit_page.dart';
import 'product_detail_page.dart';
import 'ai_community_page.dart';
import 'orders_sheet.dart';
import 'xiaodou_chat_page.dart';
import 'support_chat_page.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_buttons.dart';
class UserFeatureSheets {
  static void handleService(BuildContext context, String label) {
    switch (label) {
      case '优惠券':
        showCoupons(context);
      case '趣玩币':
        showFunCoinLedger(context);
      case '我的钱包':
        showWallet(context);
      case '地址管理':
        showAddresses(context);
      case '收藏夹':
        showFavorites(context);
      case '浏览记录':
        showBrowseHistory(context);
      case '客服中心':
        SupportChatPage.openGeneral(context);
      default:
        break;
    }
  }

  static void handleQuickAction(BuildContext context, String label) {
    switch (label) {
      case '每日任务':
        showDailyTasks(context);
      case '会员专享':
        showMemberBenefits(context);
      case '领券中心':
        showCouponCenter(context);
      case '趣玩分类':
        context.read<AppTabProvider>().goTo(AppTab.mall);
      default:
        break;
    }
  }

  static void handleMemberBenefit(BuildContext context, String label) {
    // 2026-11-20 改：5 项权益各开自己的详情页（member_benefit_page），
    // 不再全部挤进同一个「办理会员」弹层；弹层只留给「会员专享/开通会员」入口。
    MemberBenefitPage.openByLabel(context, label);
  }

  static void handleStatBar(BuildContext context, String label) {
    switch (label) {
      case '积分':
        showPointsCenter(context);
      case '趣玩币':
        showFunCoinLedger(context);
      case '优惠券':
        showCoupons(context);
      default:
        break;
    }
  }

  static void showPointsCenter(BuildContext context) {
    final user = context.read<UserProvider>();
    final ledgerFuture = user.fetchPointLedger();
    _showSheet(
      context,
      title: '积分中心',
      child: FutureBuilder<List<WalletLedgerEntry>>(
        future: ledgerFuture,
        builder: (context, snapshot) {
          final records = snapshot.data ?? [];
          return Consumer<UserProvider>(
            builder: (context, user, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppScale.s(14)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(AppScale.s(12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前积分', style: FeaturePageStyle.secondary(color: AppColors.mutedForeground)),
                        Text('${user.points}', style: FeaturePageStyle.display()),
                        SizedBox(height: AppScale.s(4)),
                        Text(
                          'VIP${user.vipLevel} 购物积分 ×${user.vipLevel >= 2 ? '1.5' : '1.0'} 倍',
                          style: FeaturePageStyle.caption(color: AppColors.primary, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppScale.s(14)),
                  Text('积分明细', style: FeaturePageStyle.sectionTitle()),
                  SizedBox(height: AppScale.s(8)),
                  _ledgerRows(records, emptyLabel: '暂无积分明细'),
                  SizedBox(height: AppScale.s(6)),
                  Text('赚积分', style: FeaturePageStyle.sectionTitle()),
                  SizedBox(height: AppScale.s(8)),
                  _actionTile(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: '每日签到',
                    subtitle: user.dailyCheckInDone ? '今日已签到' : '签到 +50 积分',
                    onTap: () => showDailyTasks(context),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: '商城购物',
                    subtitle: '实付 1 元 = 1 积分',
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AppTabProvider>().goTo(AppTab.mall);
                    },
                  ),
                  _actionTile(
                    context,
                    icon: Icons.card_giftcard_outlined,
                    title: '积分兑券',
                    subtitle: '500 积分兑满66减10券',
                    actionLabel: '兑换',
                    onTap: () async {
                      if (user.points < 500) {
                        showTopSnackBar(
                          context,
                          content: Text('积分不足，还差 ${500 - user.points}', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                        );
                        return;
                      }
                      final err = await context.read<UserProvider>().redeemPointsForCoupon();
                      if (!context.mounted) return;
                      showTopSnackBar(
                        context,
                        content: Text(
                          err ?? '兑换成功，优惠券已到账',
                          style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? actionLabel,
  }) {
    return AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
      child: Container(
        margin: EdgeInsets.only(bottom: AppScale.s(10)),
        padding: FeaturePageStyle.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
        ),
        child: Row(
          children: [
            Icon(icon, size: FeaturePageStyle.iconSize, color: AppColors.primary),
            SizedBox(width: AppScale.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FeaturePageStyle.bodyBold()),
                  Text(subtitle, style: FeaturePageStyle.secondary()),
                ],
              ),
            ),
            if (actionLabel != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppScale.s(999)),
                ),
                child: Text(actionLabel, style: FeaturePageStyle.badge(color: AppColors.primary)),
              )
            else
              Icon(Icons.chevron_right, size: FeaturePageStyle.chevronSize, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  static void showCoupons(BuildContext context) {
    _showSheet(
      context,
      title: '我的优惠券',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final available = user.coupons.where((c) => !c.used).toList();
          final used = user.coupons.where((c) => c.used).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _couponStatChip('可用', '${available.length} 张', AppColors.primary),
                  SizedBox(width: AppScale.s(8)),
                  _couponStatChip('已用', '${used.length} 张', AppColors.mutedForeground),
                ],
              ),
              SizedBox(height: AppScale.s(12)),
              if (user.coupons.isEmpty)
                _empty('暂无优惠券')
              else ...[
                if (available.isNotEmpty) ...[
                  Text('可使用', style: FeaturePageStyle.sectionTitle()),
                  SizedBox(height: AppScale.s(8)),
                  ...available.map((c) => _couponCard(c)),
                  SizedBox(height: AppScale.s(10)),
                ],
                if (used.isNotEmpty) ...[
                  Text('已使用', style: FeaturePageStyle.sectionTitle(color: AppColors.mutedForeground)),
                  SizedBox(height: AppScale.s(8)),
                  ...used.map((c) => _couponCard(c)),
                ],
              ],
              SizedBox(height: AppScale.s(8)),
              AppOutlinedButton(
                onPressed: () => showCouponCenter(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
                  side: BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                ),
                child: Text('去领券中心', style: FeaturePageStyle.action()),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _couponStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppScale.s(999)),
      ),
      child: Text('$label $value', style: FeaturePageStyle.bodyBold(color: color)),
    );
  }

  static Widget _couponCard(Coupon c) {
    return Container(
      margin: EdgeInsets.only(bottom: AppScale.s(10)),
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        color: c.used ? AppColors.muted : AppColors.secondary,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(
            '¥${c.discount.toStringAsFixed(0)}',
            style: FeaturePageStyle.priceLarge(color: c.used ? AppColors.mutedForeground : AppColors.priceRed),
          ),
          SizedBox(width: AppScale.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title, style: FeaturePageStyle.bodyBold()),
                SizedBox(height: AppScale.s(4)),
                Text('${c.condition} · 有效期至 ${c.expire}', style: FeaturePageStyle.secondary()),
              ],
            ),
          ),
          if (c.used)
            Text('已使用', style: FeaturePageStyle.caption())
          else
            Text('可用', style: FeaturePageStyle.caption(color: AppColors.primary, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  static void showFunCoinLedger(BuildContext context) {
    final user = context.read<UserProvider>();
    final ledgerFuture = user.fetchCoinLedger();
    _showSheet(
      context,
      title: '趣玩币明细',
      child: FutureBuilder<List<WalletLedgerEntry>>(
        future: ledgerFuture,
        builder: (context, snapshot) {
          final records = snapshot.data ?? [];
          return Consumer<UserProvider>(
            builder: (context, user, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppScale.s(14)),
                    decoration: BoxDecoration(
                      gradient: AppColors.profileMemberGradient,
                      borderRadius: BorderRadius.circular(AppScale.s(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('当前趣玩币', style: FeaturePageStyle.secondary(color: Colors.white70)),
                              Text('${user.funCoins}', style: FeaturePageStyle.display(color: Colors.white)),
                            ],
                          ),
                        ),
                        // 去充值：白色描边小按钮，点开充值页选档位（1 元 = 15 币）。
                        AppOutlinedButton(
                          onPressed: () => showCoinRecharge(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            minimumSize: Size(AppScale.s(76), AppScale.s(36)),
                          ),
                          child: Text('去充值', style: FeaturePageStyle.buttonLabel(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppScale.s(14)),
                  _ledgerRows(records, emptyLabel: '暂无趣玩币明细'),
                  SizedBox(height: AppScale.s(6)),
                  _actionTile(
                    context,
                    icon: Icons.task_alt_outlined,
                    title: '每日任务',
                    subtitle: '完成任务赚趣玩币',
                    onTap: () => showDailyTasks(context),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: '去商城逛逛',
                    subtitle: '购物返趣玩币，实付 1 元 = 2 币',
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AppTabProvider>().goTo(AppTab.mall);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 趣玩币充值页（2026-11-26，比例 1 元 = 15 币）：档位卡点选、默认选中
  // ¥20 档（320 币，正好够开一个月会员还剩 21）。支付与订单付款同口径，
  // 是模拟支付、无真实网关；点「立即充值」调 UserProvider.rechargeCoins，
  // 成功后余额由 Consumer 自动刷新，明细里会多一条「充值」流水（服务端记账）。
  static void showCoinRecharge(BuildContext context) {
    var selected = 2;
    _showSheet(
      context,
      title: '充值趣玩币',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return StatefulBuilder(
            builder: (context, setState) {
              final pack = coinRechargePackages[selected];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前趣玩币 ${user.funCoins}', style: FeaturePageStyle.bodyBold()),
                  SizedBox(height: AppScale.s(4)),
                  Text('充值比例：1 元 = 15 币 · 大档位有赠送', style: FeaturePageStyle.secondary()),
                  SizedBox(height: AppScale.s(14)),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: coinRechargePackages.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppScale.s(10),
                      crossAxisSpacing: AppScale.s(10),
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (context, i) {
                      final p = coinRechargePackages[i];
                      final active = i == selected;
                      return GestureDetector(
                        onTap: () => setState(() => selected = i),
                        child: Container(
                          padding: EdgeInsets.all(AppScale.s(10)),
                          decoration: BoxDecoration(
                            color: active ? AppColors.secondary : AppColors.muted,
                            borderRadius: BorderRadius.circular(AppScale.s(12)),
                            border: Border.all(color: active ? AppColors.primary : AppColors.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${p.coins}', style: FeaturePageStyle.title(color: active ? AppColors.primary : null)),
                              Text('趣玩币', style: FeaturePageStyle.caption()),
                              SizedBox(height: AppScale.s(4)),
                              Text('¥${p.yuan}', style: FeaturePageStyle.bodyBold()),
                              if (p.bonus > 0) Text('送 ${p.bonus} 币', style: FeaturePageStyle.caption(color: AppColors.primary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: AppScale.s(16)),
                  AppFilledButton(
                    onPressed: () async {
                      final err = await user.rechargeCoins(pack);
                      if (!context.mounted) return;
                      showTopSnackBar(
                        context,
                        content: Text(
                          err ?? '充值成功，+${pack.coins} 趣玩币已到账',
                          style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
                    ),
                    child: Text('立即充值 ¥${pack.yuan}', style: FeaturePageStyle.buttonLabel(color: Colors.white)),
                  ),
                  SizedBox(height: AppScale.s(10)),
                  Text('模拟支付，支付成功立即到账；充值记录可在趣玩币明细里查看。', style: FeaturePageStyle.caption()),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 开通会员时趣玩币不足的弹窗：写清需要/现有/还差，两个出路——
  // 「去充值」打开充值页、「去赚取」打开每日任务页；点「再想想」或弹窗外关闭。
  static void showCoinShortageDialog(BuildContext context, {required int current, required int cost}) {
    final diff = cost - current;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('趣玩币不足'),
          content: Text('开通会员需要 $cost 趣玩币，你当前有 $current，还差 $diff。\n可以充值，也可以做每日任务赚取。'),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('再想想', style: FeaturePageStyle.action(color: AppColors.mutedForeground)),
            ),
            AppTextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                showDailyTasks(context);
              },
              child: Text('去赚取', style: FeaturePageStyle.action()),
            ),
            AppTextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                showCoinRecharge(context);
              },
              child: Text('去充值', style: FeaturePageStyle.action()),
            ),
          ],
        );
      },
    );
  }

  // 非会员点首页「会员每日礼包」时的提示弹窗：先把专享口径与礼包内容
  // 说清，再给开通入口——绝不能让非会员直接领到（服务端也会 403 拦）。
  // 「去开通会员」打开现成的会员权益页（里面就是开通流程），不另造页面。
  static void showMemberDailyGiftLockedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('会员专享'),
          content: const Text('会员每日礼包是 VIP2 会员专享，开通后每天可领一份：积分 +10、趣玩币 +5、满30减5礼包券。'),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('再看看', style: FeaturePageStyle.action(color: AppColors.mutedForeground)),
            ),
            AppTextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                showMemberBenefits(context);
              },
              child: Text('去开通会员', style: FeaturePageStyle.action()),
            ),
          ],
        );
      },
    );
  }

  // 我的钱包：App 里三种资产（积分 / 趣玩币 / 优惠券）的总入口。
  // 数据全部走已有的积分中心、趣玩币流水、券包，不新建接口、不新建表；
  // 这里只做汇总展示和跳转，外加一个赚积分的每日任务入口形成闭环。
  static void showWallet(BuildContext context) {
    _showSheet(
      context,
      title: '我的钱包',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _actionTile(
                context,
                icon: Icons.star_outline,
                title: '积分',
                subtitle: '当前 ${user.points} 积分 · 签到、购物都能赚',
                onTap: () => showPointsCenter(context),
              ),
              _actionTile(
                context,
                icon: Icons.monetization_on_outlined,
                title: '趣玩币',
                subtitle: '当前 ${user.funCoins} · 可开通会员（299/月）',
                onTap: () => showFunCoinLedger(context),
              ),
              _actionTile(
                context,
                icon: Icons.local_offer_outlined,
                title: '优惠券',
                subtitle: '可用 ${user.availableCouponCount} 张 · 满减券下单自动可选',
                onTap: () => showCoupons(context),
              ),
              _actionTile(
                context,
                icon: Icons.calendar_today_outlined,
                title: '每日任务',
                subtitle: user.dailyCheckInDone ? '今日已签到' : '签到 +50 积分 · 还有浏览、分享任务',
                onTap: () => showDailyTasks(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // 我的盒柜（真收藏柜版，hx 2026-11-27 定）：只收已发货 / 已完成的订单
  // 商品——待付款、待发货的还没到手，不算藏品；已取消的不收。
  // 与「我的订单」的区别：订单按单看流水，这里按件看收藏——按系列
  // 分组陈列，每组显示集齐进度（已集款数 / 该系列在售总款数），顶部
  // 汇总总件数、点亮系列数、集齐系列数。没系列的老商品归「其他藏品」，
  // 只列件、不算进度。商品图通过 productId 回查商品库，查不到（商品
  // 已删）就用占位图，不整行丢弃。
  static void showCollectionCabinet(BuildContext context) {
    _showSheet(
      context,
      title: '我的盒柜',
      child: Consumer<OrderProvider>(
        builder: (context, orders, _) {
          final owned = <(Order, OrderItem)>[];
          for (final o in orders.orders) {
            if (o.status == OrderStatus.shipping || o.status == OrderStatus.completed) {
              for (final it in o.items) {
                owned.add((o, it));
              }
            }
          }
          if (owned.isEmpty) return _empty('盒柜还是空的，下单的宝贝发货后会出现在这里');

          // 按系列分组（键为系列名，无系列归「其他藏品」）
          final groups = <String, List<(Order, OrderItem)>>{};
          for (final e in owned) {
            final product = e.$2.productId == null ? null : productById(e.$2.productId!);
            final series = product?.series;
            final key = (series != null && series.isNotEmpty) ? series : '其他藏品';
            groups.putIfAbsent(key, () => []).add(e);
          }
          // 集齐进度的分母：该系列当前在售总款数，按商品库现算
          int seriesTotal(String name) => products.where((p) => p.series == name).length;
          // 已集款数：同一件买两件只算一款（凑套看的是款，不是件）
          int ownedKinds(List<(Order, OrderItem)> list) =>
              list.map((e) => e.$2.productId).whereType<String>().toSet().length;

          final totalPieces = owned.fold<int>(0, (sum, e) => sum + e.$2.quantity);
          final seriesNames = groups.keys.where((k) => k != '其他藏品').toList()
            ..sort((a, b) => ownedKinds(groups[b]!).compareTo(ownedKinds(groups[a]!)));
          final completedSeries = seriesNames
              .where((n) => seriesTotal(n) > 0 && ownedKinds(groups[n]!) >= seriesTotal(n))
              .length;

          Widget itemRow((Order, OrderItem) e) {
            final (order, item) = e;
            final product = item.productId == null ? null : productById(item.productId!);
            final cfg = orderStatusConfig(order.status);
            return Container(
              margin: EdgeInsets.only(bottom: AppScale.s(10)),
              padding: FeaturePageStyle.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
              ),
              child: Row(
                children: [
                  if (product != null)
                    ProductThumbnail(product: product, width: FeaturePageStyle.thumbSize, height: FeaturePageStyle.thumbSize)
                  else
                    Container(
                      width: FeaturePageStyle.thumbSize,
                      height: FeaturePageStyle.thumbSize,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppScale.s(8)),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: AppColors.mutedForeground),
                    ),
                  SizedBox(width: AppScale.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: FeaturePageStyle.bodyBold()),
                        SizedBox(height: AppScale.s(6)),
                        Text('x${item.quantity} · ${cfg.label}', style: FeaturePageStyle.secondary()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          Widget seriesHeader(String name) {
            final list = groups[name]!;
            final kinds = ownedKinds(list);
            if (name == '其他藏品') {
              return Padding(
                padding: EdgeInsets.only(top: AppScale.s(14), bottom: AppScale.s(10)),
                child: Text('其他藏品 · ${list.length} 件', style: FeaturePageStyle.sectionTitle()),
              );
            }
            final total = seriesTotal(name);
            final done = total > 0 && kinds >= total;
            return Padding(
              padding: EdgeInsets.only(top: AppScale.s(14), bottom: AppScale.s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: FeaturePageStyle.sectionTitle())),
                      if (done)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppScale.s(8), vertical: AppScale.s(3)),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppScale.s(999)),
                          ),
                          child: Text('已集齐', style: TextStyle(fontSize: AppScale.t(11), fontWeight: FontWeight.w700, color: AppColors.goldDark)),
                        ),
                      SizedBox(width: AppScale.s(8)),
                      Text('已集 $kinds/$total', style: FeaturePageStyle.secondary()),
                    ],
                  ),
                  SizedBox(height: AppScale.s(6)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppScale.s(3)),
                    child: LinearProgressIndicator(
                      value: total > 0 ? kinds / total : 0,
                      minHeight: AppScale.s(6),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(done ? AppColors.gold : AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部汇总：总件数 / 点亮系列 / 集齐系列
              Container(
                padding: FeaturePageStyle.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _cabinetStat('$totalPieces', '件藏品'),
                    _cabinetStat('${seriesNames.length}', '点亮系列'),
                    _cabinetStat('$completedSeries', '集齐系列'),
                  ],
                ),
              ),
              for (final name in seriesNames) ...[
                seriesHeader(name),
                for (final e in groups[name]!) itemRow(e),
              ],
              if (groups.containsKey('其他藏品')) ...[
                seriesHeader('其他藏品'),
                for (final e in groups['其他藏品']!) itemRow(e),
              ],
            ],
          );
        },
      ),
    );
  }

  static Widget _cabinetStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: AppScale.t(18), fontWeight: FontWeight.w800, color: AppColors.primary)),
        SizedBox(height: AppScale.s(2)),
        Text(label, style: FeaturePageStyle.caption()),
      ],
    );
  }

  static void showAddresses(BuildContext context) {
    _showSheet(
      context,
      title: '地址管理',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddressEditor(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(14)),
                  ),
                  icon: Icon(Icons.add, size: AppScale.s(22)),
                  label: Text('新增地址', style: FeaturePageStyle.buttonLabel(color: AppColors.primary)),
                ),
              ),
              SizedBox(height: AppScale.s(12)),
              if (user.addresses.isEmpty)
                _empty('还没有收货地址')
              else
                ListView.separated(
                  // padding 显式归零：不写时 ListView 会自带一份顶部
                  // 安全区留白，和页面外框的间距叠加，空出一大截。
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: user.addresses.length,
                  separatorBuilder: (_, _) => SizedBox(height: AppScale.s(10)),
                  itemBuilder: (context, index) {
                    final addr = user.addresses[index];
                    return Container(
                      padding: EdgeInsets.all(AppScale.s(14)),
                      decoration: BoxDecoration(
                        color: addr.isDefault ? AppColors.secondary : AppColors.muted,
                        borderRadius: BorderRadius.circular(AppScale.s(12)),
                        border: Border.all(
                          color: addr.isDefault ? AppColors.primaryLight : AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(addr.name, style: FeaturePageStyle.title()),
                              SizedBox(width: AppScale.s(10)),
                              Text(
                                addr.phone,
                                style: FeaturePageStyle.body(color: AppColors.foreground.withValues(alpha: 0.72)),
                              ),
                              if (addr.isDefault) ...[
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(AppScale.s(999)),
                                  ),
                                  child: Text('默认', style: FeaturePageStyle.badge()),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: AppScale.s(8)),
                          Text(addr.detail, style: FeaturePageStyle.body()),
                          SizedBox(height: AppScale.s(10)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AppTextButton(
                                onPressed: () => _showAddressEditor(context, address: addr),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                                ),
                                child: Text('编辑', style: FeaturePageStyle.action()),
                              ),
                              AppTextButton(
                                onPressed: () async {
                                  final error = await context.read<UserProvider>().removeAddress(addr.id);
                                  if (!context.mounted) return;
                                  if (error != null) {
                                    showTopSnackBar(
                                      context,
                                      content: Text(error, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                                ),
                                child: Text('删除', style: FeaturePageStyle.action(color: AppColors.priceRed)),
                              ),
                              if (!addr.isDefault)
                                AppTextButton(
                                  onPressed: () {
                                    context.read<UserProvider>().setDefaultAddress(addr.id);
                                    showTopSnackBar(
                                      context,
                                      content: Text('已设为默认地址', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                                  ),
                                  child: Text('设为默认', style: FeaturePageStyle.action()),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  static void _showAddressEditor(BuildContext context, {Address? address}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AddressEditPage(address: address)),
    );
  }

  static void showFavorites(BuildContext context) {
    _showSheet(
      context,
      title: '我的收藏',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final items = user.favoriteProducts;
          if (items.isEmpty) return _empty('还没有收藏商品');
          return ListView.separated(
            // padding 显式归零：不写时 ListView 会自带一份顶部安全区
            // 留白，和页面外框的间距叠加，列表顶部会空出一大截。
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: AppScale.s(10)),
            itemBuilder: (context, index) {
              final p = items[index];
              return AppInkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: p))),
                borderRadius: BorderRadius.circular(AppScale.s(12)),
                child: Container(
                  padding: FeaturePageStyle.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                  ),
                  child: Row(
                    children: [
                      ProductThumbnail(product: p, width: FeaturePageStyle.thumbSize, height: FeaturePageStyle.thumbSize),
                      SizedBox(width: AppScale.s(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: FeaturePageStyle.bodyBold()),
                            SizedBox(height: AppScale.s(6)),
                            Text('¥ ${p.price.toStringAsFixed(0)}', style: FeaturePageStyle.price()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void showBrowseHistory(BuildContext context) {
    openFeaturePage(
      context,
      title: '浏览记录',
      scrollable: false,
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final items = user.browseHistory
              .map(productById)
              .whereType<Product>()
              .toList();
          if (items.isEmpty) return _empty('暂无浏览记录');
          return ListView.separated(
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: AppScale.s(10)),
            itemBuilder: (context, index) {
              final p = items[index];
              return AppInkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: p))),
                borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                child: Container(
                  padding: FeaturePageStyle.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
                  ),
                  child: Row(
                    children: [
                      ProductThumbnail(product: p, width: FeaturePageStyle.thumbSize, height: FeaturePageStyle.thumbSize),
                      SizedBox(width: AppScale.s(12)),
                      Expanded(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: FeaturePageStyle.bodyBold())),
                      SizedBox(width: AppScale.s(8)),
                      Text('¥${p.price.toStringAsFixed(0)}', style: FeaturePageStyle.price()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void showMemberBenefits(BuildContext context, {String? highlight}) {
    const items = [
      ('每月赠券', 'VIP 每月可领 1 张满88减20 优惠券，当月有效。'),
      ('积分加成', 'VIP2 购物积分 ×1.5 倍，下单自动累计。'),
      ('专属折扣', '指定潮玩/谷子商品享 95 折，结算页自动抵扣。'),
      ('生日礼包', '生日当月可领限定徽章 + 50 趣玩币礼包。'),
      ('优先发货', '会员订单优先拣货，现货 24 小时内发出。'),
    ];
    _showSheet(
      context,
      title: '办理会员',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final isMember = user.vipLevel >= memberTargetVipLevel;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppScale.s(16)),
                decoration: BoxDecoration(
                  gradient: AppColors.profileMemberGradient,
                  borderRadius: BorderRadius.circular(AppScale.s(14)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppScale.s(10)),
                      child: Image.asset(
                        memberBadgePath,
                        width: AppScale.s(52),
                        height: AppScale.s(52),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.diamond, size: AppScale.s(40), color: AppColors.gold),
                      ),
                    ),
                    SizedBox(width: AppScale.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMember ? '趣玩星球 VIP${user.vipLevel}' : '开通趣玩星球会员',
                            style: FeaturePageStyle.bodyBold(color: Colors.white),
                          ),
                          SizedBox(height: AppScale.s(4)),
                          Text(
                            isMember ? '尊享专属权益，解锁更多惊喜福利' : 'VIP2 专享 · ${memberSubscribeCoinPrice} 趣玩币/月',
                            style: FeaturePageStyle.secondary(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppScale.s(14)),
              if (!isMember) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppScale.s(14)),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppScale.s(12)),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('会员价格', style: FeaturePageStyle.secondary()),
                            SizedBox(height: AppScale.s(4)),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${memberSubscribeCoinPrice}',
                                    style: FeaturePageStyle.display(color: AppColors.primary),
                                  ),
                                  TextSpan(
                                    text: ' 趣玩币 / 月',
                                    style: FeaturePageStyle.body(color: AppColors.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('当前趣玩币', style: FeaturePageStyle.secondary()),
                          SizedBox(height: AppScale.s(4)),
                          Text('${user.funCoins}', style: FeaturePageStyle.bodyBold(color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppScale.s(12)),
                AppFilledButton(
                  onPressed: () async {
                    final err = await user.subscribeMember();
                    if (!context.mounted) return;
                    if (err != null) {
                      // 币不足不再只飘一条提示：弹窗给出充值/赚取两个出路；
                      // 其他错误（已是会员等）仍走原来的顶部提示。
                      if (err.contains('趣玩币不足')) {
                        showCoinShortageDialog(context, current: user.funCoins, cost: memberSubscribeCoinPrice);
                      } else {
                        showTopSnackBar(
                          context,
                          content: Text(err, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                        );
                      }
                    } else {
                      showTopSnackBar(
                        context,
                        content: Text('会员开通成功', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
                  ),
                  child: Text('立即开通', style: FeaturePageStyle.buttonLabel(color: Colors.white)),
                ),
                SizedBox(height: AppScale.s(16)),
                Text('会员权益', style: FeaturePageStyle.bodyBold()),
                SizedBox(height: AppScale.s(10)),
              ] else ...[
                AppFilledButton(
                  onPressed: user.memberMonthlyCouponClaimed
                      ? null
                      : () {
                          if (user.claimMemberMonthlyCoupon()) {
                            showTopSnackBar(
                              context,
                              content: Text('会员赠券已到账', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
                  ),
                  child: Text(
                    user.memberMonthlyCouponClaimed ? '本月赠券已领取' : '领取本月赠券',
                    style: FeaturePageStyle.buttonLabel(color: Colors.white),
                  ),
                ),
                SizedBox(height: AppScale.s(16)),
                Text('我的权益', style: FeaturePageStyle.bodyBold()),
                SizedBox(height: AppScale.s(10)),
              ],
              ...items.map((item) {
                final active = highlight == null || highlight == item.$1;
                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: AppScale.s(10)),
                  padding: EdgeInsets.all(AppScale.s(12)),
                  decoration: BoxDecoration(
                    color: active ? AppColors.secondary : AppColors.muted,
                    borderRadius: BorderRadius.circular(AppScale.s(12)),
                    border: Border.all(
                      color: highlight == item.$1 ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
                      width: highlight == item.$1 ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: FeaturePageStyle.bodyBold()),
                      SizedBox(height: AppScale.s(6)),
                      Text(item.$2, style: FeaturePageStyle.body(color: AppColors.mutedForeground, height: 1.5)),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // 任务页统一的小提示，省得每个任务都写一长串
  static void _taskSnack(BuildContext context, String message) {
    showTopSnackBar(
      context,
      content: Text(message, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
    );
  }

  // 顶部汇总卡：今日已赚（服务端按当天任务流水汇总下发）+ 我的余额
  static Widget _tasksSummaryCard(UserProvider user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.secondary]),
        borderRadius: BorderRadius.circular(AppScale.s(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日已赚 ${user.dailyEarnedPoints} 积分 · ${user.dailyEarnedCoins} 趣玩币', style: FeaturePageStyle.bodyBold()),
          SizedBox(height: AppScale.s(4)),
          Text('我的积分 ${user.points} · 趣玩币 ${user.funCoins}', style: FeaturePageStyle.secondary()),
        ],
      ),
    );
  }

  // 连签条：按用户自己的连签节奏点亮 7 格（不是自然周），第 3 格 +30、
  // 第 7 格 +100 直接标在格子下面；今天还没签时，下一格描边高亮。
  static Widget _checkInStreakBar(UserProvider user) {
    final streak = user.checkInStreak;
    var signedDots = streak == 0 ? 0 : ((streak - 1) % 7) + 1;
    var pendingIndex = -1;
    if (!user.dailyCheckInDone) {
      if (signedDots == 7) {
        signedDots = 0;
        pendingIndex = 0;
      } else {
        pendingIndex = signedDots;
      }
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('连续签到', style: FeaturePageStyle.bodyBold()),
              SizedBox(width: AppScale.s(8)),
              Text(streak > 0 ? '已连签 $streak 天' : '签到开启连签', style: FeaturePageStyle.secondary()),
            ],
          ),
          SizedBox(height: AppScale.s(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final signed = i < signedDots;
              final pending = i == pendingIndex;
              final bonusDay = i == 2 || i == 6;
              final label = i == 2 ? '+30' : i == 6 ? '+100' : '第${i + 1}天';
              return Column(
                children: [
                  Container(
                    width: AppScale.s(32),
                    height: AppScale.s(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: signed ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: signed || pending ? AppColors.primary : AppColors.mutedForeground.withValues(alpha: 0.4),
                        width: pending ? 2 : 1,
                      ),
                    ),
                    child: signed ? Icon(Icons.check, size: AppScale.s(16), color: Colors.white) : null,
                  ),
                  SizedBox(height: AppScale.s(4)),
                  Text(
                    label,
                    style: FeaturePageStyle.caption(
                      color: bonusDay ? AppColors.primary : null,
                      weight: bonusDay ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  static void showDailyTasks(BuildContext context) {
    // 进门先拉一次最新资料：收藏/加购/聊天/点赞的进度都是服务端记的，
    // 不刷新会看到上次打开时的旧状态
    context.read<UserProvider>().refreshProfileFromRemote();
    _showSheet(
      context,
      title: '每日任务',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          void goMall() {
            Navigator.pop(context);
            context.read<AppTabProvider>().goTo(AppTab.mall);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tasksSummaryCard(user),
              SizedBox(height: AppScale.s(12)),
              _checkInStreakBar(user),
              SizedBox(height: AppScale.s(16)),
              Text('每日任务', style: FeaturePageStyle.sectionTitle()),
              SizedBox(height: AppScale.s(10)),
              _taskTile(
                context,
                icon: Icons.event_available_outlined,
                title: '每日签到',
                reward: '+50 积分',
                subtitle: user.checkInStreak > 0 ? '已连签 ${user.checkInStreak} 天' : '连签第 3 天、第 7 天有额外奖励',
                done: user.dailyCheckInDone,
                actionLabel: user.dailyCheckInDone ? '已完成' : '签到',
                onAction: user.dailyCheckInDone
                    ? null
                    : () {
                        if (user.dailyCheckIn()) _taskSnack(context, '签到成功，获得 50 积分');
                      },
              ),
              _taskTile(
                context,
                icon: Icons.explore_outlined,
                title: '浏览 3 件商品',
                reward: '+30 趣玩币',
                done: user.dailyBrowseRewardClaimed,
                progress: user.dailyBrowseCount.clamp(0, 3) / 3,
                progressText: '进度 ${user.dailyBrowseCount.clamp(0, 3)}/3',
                claimReady: !user.dailyBrowseRewardClaimed && user.dailyBrowseCount >= 3,
                actionLabel: user.dailyBrowseRewardClaimed
                    ? '已领取'
                    : user.dailyBrowseCount >= 3
                        ? '领取'
                        : '去完成',
                onAction: user.dailyBrowseRewardClaimed
                    ? null
                    : user.dailyBrowseCount >= 3
                        ? () {
                            if (user.claimDailyBrowseReward()) _taskSnack(context, '任务完成，获得 30 趣玩币');
                          }
                        : goMall,
              ),
              _taskTile(
                context,
                icon: Icons.favorite_border,
                title: '收藏 1 件商品',
                reward: '+15 趣玩币',
                done: user.dailyFavoriteClaimed,
                claimReady: user.dailyFavoriteDone && !user.dailyFavoriteClaimed,
                actionLabel: user.dailyFavoriteClaimed
                    ? '已领取'
                    : user.dailyFavoriteDone
                        ? '领取'
                        : '去完成',
                onAction: user.dailyFavoriteClaimed
                    ? null
                    : user.dailyFavoriteDone
                        ? () {
                            if (user.claimDailyFavoriteReward()) _taskSnack(context, '任务完成，获得 15 趣玩币');
                          }
                        : goMall,
              ),
              _taskTile(
                context,
                icon: Icons.add_shopping_cart_outlined,
                title: '加入购物车 1 件',
                reward: '+15 趣玩币',
                done: user.dailyCartClaimed,
                claimReady: user.dailyCartDone && !user.dailyCartClaimed,
                actionLabel: user.dailyCartClaimed
                    ? '已领取'
                    : user.dailyCartDone
                        ? '领取'
                        : '去完成',
                onAction: user.dailyCartClaimed
                    ? null
                    : user.dailyCartDone
                        ? () {
                            if (user.claimDailyCartReward()) _taskSnack(context, '任务完成，获得 15 趣玩币');
                          }
                        : goMall,
              ),
              _taskTile(
                context,
                icon: Icons.chat_bubble_outline,
                title: '和小豆聊一句',
                reward: '+20 积分',
                done: user.dailyChatClaimed,
                claimReady: user.dailyChatDone && !user.dailyChatClaimed,
                actionLabel: user.dailyChatClaimed
                    ? '已领取'
                    : user.dailyChatDone
                        ? '领取'
                        : '去完成',
                onAction: user.dailyChatClaimed
                    ? null
                    : user.dailyChatDone
                        ? () {
                            if (user.claimDailyChatReward()) _taskSnack(context, '任务完成，获得 20 积分');
                          }
                        : () {
                            Navigator.pop(context);
                            XiaodouChatPage.open(context);
                          },
              ),
              _taskTile(
                context,
                icon: Icons.thumb_up_outlined,
                title: 'AI 社区点赞 1 次',
                reward: '+20 积分',
                done: user.dailyCommunityClaimed,
                claimReady: user.dailyCommunityDone && !user.dailyCommunityClaimed,
                actionLabel: user.dailyCommunityClaimed
                    ? '已领取'
                    : user.dailyCommunityDone
                        ? '领取'
                        : '去完成',
                onAction: user.dailyCommunityClaimed
                    ? null
                    : user.dailyCommunityDone
                        ? () {
                            if (user.claimDailyCommunityReward()) _taskSnack(context, '任务完成，获得 20 积分');
                          }
                        : () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator.push(MaterialPageRoute(builder: (_) => const AiCommunityPage()));
                          },
              ),
              _taskTile(
                context,
                icon: Icons.share_outlined,
                title: '分享 1 件商品',
                reward: '+20 趣玩币',
                subtitle: '在商品详情页点右上角分享',
                done: user.dailyShareDone,
                actionLabel: user.dailyShareDone ? '已完成' : '去完成',
                onAction: user.dailyShareDone ? null : goMall,
              ),
              SizedBox(height: AppScale.s(6)),
              Text('每周任务', style: FeaturePageStyle.sectionTitle()),
              SizedBox(height: AppScale.s(10)),
              _taskTile(
                context,
                icon: Icons.date_range_outlined,
                title: '本周签到 5 天',
                reward: '+100 积分',
                done: user.weeklyCheckInClaimed,
                progress: user.weeklyCheckInDays.clamp(0, 5) / 5,
                progressText: '进度 ${user.weeklyCheckInDays.clamp(0, 5)}/5',
                claimReady: !user.weeklyCheckInClaimed && user.weeklyCheckInDays >= 5,
                actionLabel: user.weeklyCheckInClaimed
                    ? '已领取'
                    : user.weeklyCheckInDays >= 5
                        ? '领取'
                        : '进行中',
                onAction: !user.weeklyCheckInClaimed && user.weeklyCheckInDays >= 5
                    ? () {
                        if (user.claimWeeklyCheckInReward()) _taskSnack(context, '每周签到奖励，获得 100 积分');
                      }
                    : null,
              ),
              _taskTile(
                context,
                icon: Icons.receipt_long_outlined,
                title: '本周完成 1 笔订单',
                reward: '+50 趣玩币',
                done: user.weeklyOrderClaimed,
                claimReady: user.weeklyOrderDone && !user.weeklyOrderClaimed,
                actionLabel: user.weeklyOrderClaimed
                    ? '已领取'
                    : user.weeklyOrderDone
                        ? '领取'
                        : '去完成',
                onAction: user.weeklyOrderClaimed
                    ? null
                    : user.weeklyOrderDone
                        ? () {
                            if (user.claimWeeklyOrderReward()) _taskSnack(context, '每周下单奖励，获得 50 趣玩币');
                          }
                        : goMall,
              ),
              _taskTile(
                context,
                icon: Icons.rate_review_outlined,
                title: '本周评价 1 件商品',
                reward: '+30 趣玩币',
                done: user.weeklyReviewClaimed,
                claimReady: user.weeklyReviewDone && !user.weeklyReviewClaimed,
                actionLabel: user.weeklyReviewClaimed
                    ? '已领取'
                    : user.weeklyReviewDone
                        ? '领取'
                        : '去完成',
                onAction: user.weeklyReviewClaimed
                    ? null
                    : user.weeklyReviewDone
                        ? () {
                            if (user.claimWeeklyReviewReward()) _taskSnack(context, '每周评价奖励，获得 30 趣玩币');
                          }
                        : () {
                            Navigator.pop(context);
                            OrdersSheet.show(context, filterLabel: '待评价');
                          },
              ),
              Text('每日任务 0 点刷新，每周任务周一刷新（北京时间）', style: FeaturePageStyle.caption()),
            ],
          );
        },
      ),
    );
  }

  static void showCouponCenter(BuildContext context) {
    _showSheet(
      context,
      title: '领券中心',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          void toastClaimed() {
            showTopSnackBar(
              context,
              content: Text('领券成功，已放入账户', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
            );
          }

          final isMember = user.vipLevel >= memberTargetVipLevel;
          return Column(
            children: [
              _couponCenterCard(
                title: '新人券包',
                subtitle: '满30减5 · 满50减10 · 两张一起领',
                claimed: user.newcomerClaimed,
                onClaim: () {
                  if (user.claimNewcomerCoupon()) toastClaimed();
                },
              ),
              SizedBox(height: AppScale.s(12)),
              _couponCenterCard(
                title: '满120减25',
                subtitle: '全场潮玩通用 · 领取后 30 天有效',
                claimed: user.coupons.any((c) => c.id == 'c6'),
                highlight: true,
                onClaim: () {
                  if (user.claimCouponCenterGift()) toastClaimed();
                },
              ),
              SizedBox(height: AppScale.s(12)),
              _couponCenterCard(
                title: '满200减40',
                subtitle: '全场潮玩通用 · 领取后 30 天有效',
                claimed: user.coupons.any((c) => c.id == 'c8'),
                onClaim: () {
                  if (user.claimCouponCenterSingle(
                    couponId: 'c8',
                    title: '领券中心满200减40',
                    discount: 40,
                    condition: '满200可用',
                  )) {
                    toastClaimed();
                  }
                },
              ),
              SizedBox(height: AppScale.s(12)),
              _couponCenterCard(
                title: '满300减80',
                subtitle: '全场潮玩通用 · 领取后 30 天有效',
                claimed: user.coupons.any((c) => c.id == 'c3'),
                onClaim: () {
                  if (user.claimCouponCenterSingle(
                    couponId: 'c3',
                    title: '满300减80',
                    discount: 80,
                    condition: '满300可用',
                  )) {
                    toastClaimed();
                  }
                },
              ),
              SizedBox(height: AppScale.s(12)),
              _couponCenterCard(
                title: '会员每月赠券 · 满88减20',
                subtitle: isMember ? 'VIP2 会员每月 1 张 · 当月有效' : 'VIP2 会员专享 · 每月 1 张',
                claimed: user.memberMonthlyCouponClaimed,
                claimLabel: isMember ? '立即领取' : 'VIP2 可领',
                onClaim: () {
                  if (!isMember) {
                    showTopSnackBar(
                      context,
                      content: Text('开通会员（VIP2）后每月可领', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
                    );
                    return;
                  }
                  if (user.claimMemberMonthlyCoupon()) toastClaimed();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // 领券中心的单张券卡：标题 + 说明 + 整宽领取按钮，5 张卡共用一个样子。
  // claimed=true 时按钮变灰禁用并显示「已领取」；highlight=true 用紫色渐变突出主推券。
  static Widget _couponCenterCard({
    required String title,
    required String subtitle,
    required bool claimed,
    required VoidCallback onClaim,
    String claimLabel = '立即领取',
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        gradient: highlight ? LinearGradient(colors: [AppColors.primaryLight, AppColors.secondary]) : null,
        color: highlight ? null : AppColors.muted,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FeaturePageStyle.bodyBold()),
          SizedBox(height: AppScale.s(6)),
          Text(subtitle, style: FeaturePageStyle.secondary()),
          SizedBox(height: AppScale.s(10)),
          AppFilledButton(
            onPressed: claimed ? null : onClaim,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.muted,
              minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
            ),
            child: Text(
              claimed ? '已领取' : claimLabel,
              style: FeaturePageStyle.buttonLabel(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _taskTile(
    BuildContext context, {
    required String title,
    required String reward,
    required bool done,
    required String actionLabel,
    String? subtitle,
    VoidCallback? onAction,
    IconData? icon,
    double? progress,
    String? progressText,
    bool claimReady = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppScale.s(10)),
      padding: FeaturePageStyle.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(FeaturePageStyle.cardRadius),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: AppScale.s(38),
              height: AppScale.s(38),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppScale.s(10)),
              ),
              child: Icon(icon, size: AppScale.s(20), color: AppColors.primary),
            ),
            SizedBox(width: AppScale.s(10)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FeaturePageStyle.bodyBold()),
                if (subtitle != null) Text(subtitle, style: FeaturePageStyle.secondary()),
                if (progress != null) ...[
                  SizedBox(height: AppScale.s(6)),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppScale.s(3)),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: AppScale.s(6),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      if (progressText != null) ...[
                        SizedBox(width: AppScale.s(8)),
                        Text(progressText, style: FeaturePageStyle.caption()),
                      ],
                    ],
                  ),
                  SizedBox(height: AppScale.s(2)),
                ],
                Text(reward, style: FeaturePageStyle.action()),
              ],
            ),
          ),
          if (claimReady)
            AppFilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(AppScale.s(64), AppScale.s(34)),
                padding: EdgeInsets.symmetric(horizontal: AppScale.s(12)),
              ),
              child: Text(actionLabel, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600, color: Colors.white)),
            )
          else
            // 状态文字套圆角胶囊（hx 2026-11-27 点名）：裸文字看不出能点，
            // 去完成/签到用浅紫底紫字，已完成/已领取用浅灰底灰字，一眼是按钮。
            // onAction 为空（已完成态）时手势不注册，胶囊只是状态徽章。
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppScale.s(14),
                  vertical: AppScale.s(7),
                ),
                decoration: BoxDecoration(
                  color: done || onAction == null
                      ? AppColors.mutedForeground.withValues(alpha: 0.10)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppScale.s(999)),
                ),
                child: Text(
                  actionLabel,
                  style: FeaturePageStyle.action(
                    color: done || onAction == null ? AppColors.mutedForeground : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _ledgerRows(List<WalletLedgerEntry> records, {required String emptyLabel}) {
    if (records.isEmpty) return _empty(emptyLabel);
    return Column(
      children: records.map((r) {
        final positive = r.amount > 0;
        final value = '${positive ? '+' : ''}${r.amount}';
        return Padding(
          padding: EdgeInsets.only(bottom: AppScale.s(10)),
          child: Row(
            children: [
              Expanded(child: Text(r.title, style: FeaturePageStyle.bodyBold())),
              Text(
                value,
                style: FeaturePageStyle.bodyBold(
                  color: positive ? AppColors.priceRed : AppColors.mutedForeground,
                ),
              ),
              SizedBox(width: AppScale.s(12)),
              Text(r.time, style: FeaturePageStyle.caption()),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _empty(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppScale.s(32)),
      child: Center(child: Text(text, style: FeaturePageStyle.empty())),
    );
  }

  static void _showSheet(BuildContext context, {required String title, required Widget child}) {
    openFeaturePage(context, title: title, child: child);
  }
}
