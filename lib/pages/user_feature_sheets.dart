import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/feature_page_scaffold.dart';
import 'address_edit_page.dart';
import 'product_detail_page.dart';
import 'support_chat_page.dart';

class UserFeatureSheets {
  static void handleService(BuildContext context, String label) {
    switch (label) {
      case '优惠券':
        showCoupons(context);
      case '趣玩币明细':
        showFunCoinLedger(context);
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
    showMemberBenefits(context, highlight: label);
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
                          content: Text('积分不足，还差 ${500 - user.points}', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                        );
                        return;
                      }
                      final err = await context.read<UserProvider>().redeemPointsForCoupon();
                      if (!context.mounted) return;
                      showTopSnackBar(
                        context,
                        content: Text(
                          err ?? '兑换成功，优惠券已到账',
                          style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600),
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
    return InkWell(
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
              OutlinedButton(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前趣玩币', style: FeaturePageStyle.secondary(color: Colors.white70)),
                        Text('${user.funCoins}', style: FeaturePageStyle.display(color: Colors.white)),
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
                              TextButton(
                                onPressed: () => _showAddressEditor(context, address: addr),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                                ),
                                child: Text('编辑', style: FeaturePageStyle.action()),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final error = await context.read<UserProvider>().removeAddress(addr.id);
                                  if (!context.mounted) return;
                                  if (error != null) {
                                    showTopSnackBar(
                                      context,
                                      content: Text(error, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: AppScale.s(12), vertical: AppScale.s(6)),
                                ),
                                child: Text('删除', style: FeaturePageStyle.action(color: AppColors.priceRed)),
                              ),
                              if (!addr.isDefault)
                                TextButton(
                                  onPressed: () {
                                    context.read<UserProvider>().setDefaultAddress(addr.id);
                                    showTopSnackBar(
                                      context,
                                      content: Text('已设为默认地址', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: AppScale.s(10)),
            itemBuilder: (context, index) {
              final p = items[index];
              return InkWell(
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
    _showSheet(
      context,
      title: '浏览记录',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final items = user.browseHistory
              .map(productById)
              .whereType<Product>()
              .toList();
          if (items.isEmpty) return _empty('暂无浏览记录');
          return ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: AppScale.s(10)),
            itemBuilder: (context, index) {
              final p = items[index];
              return InkWell(
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
      ('每月赠券', 'VIP 每月可领 1 张满99减20 优惠券，当月有效。'),
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
                FilledButton(
                  onPressed: () async {
                    final err = await user.subscribeMember();
                    if (!context.mounted) return;
                    if (err != null) {
                      showTopSnackBar(
                        context,
                        content: Text(err, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                      );
                    } else {
                      showTopSnackBar(
                        context,
                        content: Text('会员开通成功', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
                FilledButton(
                  onPressed: user.memberMonthlyCouponClaimed
                      ? null
                      : () {
                          if (user.claimMemberMonthlyCoupon()) {
                            showTopSnackBar(
                              context,
                              content: Text('会员赠券已到账', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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

  static void showDailyTasks(BuildContext context) {
    _showSheet(
      context,
      title: '每日任务',
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          return Column(
            children: [
              _taskTile(
                context,
                title: '每日签到',
                reward: '+50 积分',
                done: user.dailyCheckInDone,
                actionLabel: user.dailyCheckInDone ? '已完成' : '签到',
                onAction: user.dailyCheckInDone
                    ? null
                    : () {
                        if (user.dailyCheckIn()) {
                          showTopSnackBar(
                            context,
                            content: Text('签到成功，获得 50 积分', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                          );
                        }
                      },
              ),
              _taskTile(
                context,
                title: '浏览 3 件商品',
                reward: '+30 趣玩币',
                done: user.dailyBrowseRewardClaimed,
                subtitle: '进度 ${user.dailyBrowseCount.clamp(0, 3)}/3',
                actionLabel: user.dailyBrowseRewardClaimed
                    ? '已完成'
                    : user.dailyBrowseCount >= 3
                        ? '领取'
                        : '去完成',
                onAction: user.dailyBrowseRewardClaimed
                    ? null
                    : user.dailyBrowseCount >= 3
                        ? () {
                            if (user.claimDailyBrowseReward()) {
                              showTopSnackBar(
                                context,
                                content: Text('任务完成，获得 30 趣玩币', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                              );
                            }
                          }
                        : () {
                            Navigator.pop(context);
                            context.read<AppTabProvider>().goTo(AppTab.mall);
                          },
              ),
              _taskTile(
                context,
                title: '分享一次商品',
                reward: '+20 趣玩币',
                done: user.dailyShareDone,
                actionLabel: user.dailyShareDone ? '已完成' : '分享',
                onAction: user.dailyShareDone
                    ? null
                    : () {
                        if (user.completeDailyShare()) {
                          showTopSnackBar(
                            context,
                            content: Text('分享成功，获得 20 趣玩币', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                          );
                        }
                      },
              ),
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
          final claimed = user.coupons.any((c) => c.id == 'c6');
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppScale.s(14)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.secondary]),
                  borderRadius: BorderRadius.circular(AppScale.s(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('满120减25', style: FeaturePageStyle.title()),
                    SizedBox(height: AppScale.s(6)),
                    Text('全场潮玩通用 · 领取后 30 天有效', style: FeaturePageStyle.secondary()),
                    SizedBox(height: AppScale.s(10)),
                    FilledButton(
                      onPressed: claimed
                          ? null
                          : () {
                              if (user.claimCouponCenterGift()) {
                                showTopSnackBar(
                                  context,
                                  content: Text('领券成功，已放入账户', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.muted,
                        minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
                      ),
                      child: Text(
                        claimed ? '已领取' : '立即领取',
                        style: FeaturePageStyle.buttonLabel(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppScale.s(12)),
              if (!user.newcomerClaimed)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppScale.s(14)),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(AppScale.s(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('新人券包', style: FeaturePageStyle.bodyBold()),
                      SizedBox(height: AppScale.s(6)),
                      Text('满30减5 · 满50减10', style: FeaturePageStyle.secondary()),
                      SizedBox(height: AppScale.s(10)),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AppTabProvider>().goTo(AppTab.profile);
                        },
                        child: Text('去我的页领取', style: FeaturePageStyle.action()),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FeaturePageStyle.bodyBold()),
                if (subtitle != null) Text(subtitle, style: FeaturePageStyle.secondary()),
                Text(reward, style: FeaturePageStyle.action()),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel, style: FeaturePageStyle.action())),
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
