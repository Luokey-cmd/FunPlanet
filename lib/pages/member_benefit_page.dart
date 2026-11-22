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
import '../widgets/click_effect/app_buttons.dart';
import '../widgets/feature_page_scaffold.dart';
import 'orders_sheet.dart';
import 'profile_edit_page.dart';
import 'user_feature_sheets.dart';

// 会员权益详情页：5 项权益各一页，不再共用同一个「办理会员」弹层。
// 入口：「我的」页会员卡上的 5 个权益格子（profile_page 的 _benefits），
// 经 UserFeatureSheets.handleMemberBenefit 按名字转到这里。
// 每页结构统一：头图（图标+一句话+我的状态）→ 专属内容 → 规则说明 → 动作按钮，
// 但内容按权益各自长：赠券页能直接领券、积分页有真实明细、生日页能跳去设生日。
// 注意：专属折扣与生日礼包目前服务端只有文案、没有结算/发放逻辑，
// 本页只做状态展示与说明，不要在这里假装能领、能抵扣（补逻辑要改服务端）。

enum MemberBenefitKind {
  monthlyCoupon,
  pointsBoost,
  discount,
  birthdayGift,
  priorityShipping,
}

// 权益的静态文案与图标。数值口径与会员卡小字、权益说明页保持一致，改一处同步三处。
class _BenefitMeta {
  const _BenefitMeta({
    required this.label,
    required this.iconPath,
    required this.tagline,
    required this.valueText,
    required this.rules,
  });

  final String label;
  final String iconPath;
  final String tagline;
  final String valueText;
  final List<String> rules;
}

const _metas = <MemberBenefitKind, _BenefitMeta>{
  MemberBenefitKind.monthlyCoupon: _BenefitMeta(
    label: '每月赠券',
    iconPath: 'assets/images/icon_pf_monthly_coupon.png',
    tagline: '每月 1 张会员专属券，领了当月用',
    valueText: '满99减20',
    rules: [
      'VIP2 及以上会员每月可领 1 张，跨月自动恢复可领。',
      '领到的券在「我的优惠券」里，结算时选用即可抵扣。',
      '券当月有效，过期作废，不补发。',
    ],
  ),
  MemberBenefitKind.pointsBoost: _BenefitMeta(
    label: '积分加成',
    iconPath: 'assets/images/icon_pf_points_boost.png',
    tagline: '购物得积分，会员按 1.5 倍累计',
    valueText: '购物×1.5',
    rules: [
      '购物积分在订单完成后自动累计，不用手动领。',
      '倍率按当前等级算：VIP2 为 ×1.5，普通用户 ×1.0。',
      '本页和「积分中心」都能看积分明细。',
    ],
  ),
  MemberBenefitKind.discount: _BenefitMeta(
    label: '专属折扣',
    iconPath: 'assets/images/icon_pf_discount.png',
    tagline: '指定商品会员价，结算时自动按 95 折算',
    valueText: '指定95折',
    rules: [
      '指定潮玩 / 谷子商品参与，是否参与以商品详情和结算页显示为准。',
      '结算时自动按 95 折计算，不用领券、不用输码。',
      '与优惠券能否叠加，以结算页最终显示为准。',
    ],
  ),
  MemberBenefitKind.birthdayGift: _BenefitMeta(
    label: '生日礼包',
    iconPath: 'assets/images/icon_pf_birthday_gift.png',
    tagline: '生日当月有礼，记得提前把生日填好',
    valueText: '+50趣玩币',
    rules: [
      '生日以个人资料里保存的日期为准，没填就发不了礼包。',
      '礼包内容：50 趣玩币 + 限定徽章，生日当月发放到账户。',
      '每年发放一次，错过当月不补发。',
    ],
  ),
  MemberBenefitKind.priorityShipping: _BenefitMeta(
    label: '优先发货',
    iconPath: 'assets/images/icon_pf_priority_shipping.png',
    tagline: '会员订单优先拣货，现货 24 小时内发出',
    valueText: '24h内发出',
    rules: [
      '优先指仓库拣货顺序优先，快递在途时效不变。',
      '预售 / 定制商品按商品页标注的时间发货。',
      '节假日订单可能顺延，以订单页的物流更新为准。',
    ],
  ),
};

class MemberBenefitPage extends StatefulWidget {
  const MemberBenefitPage({super.key, required this.kind});

  final MemberBenefitKind kind;

  static void open(BuildContext context, MemberBenefitKind kind) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => MemberBenefitPage(kind: kind)),
    );
  }

  // 按「我的」页权益格子的中文名打开对应页；名字对不上就不动（防止文案改名后点空）。
  static void openByLabel(BuildContext context, String label) {
    for (final entry in _metas.entries) {
      if (entry.value.label == label) {
        open(context, entry.key);
        return;
      }
    }
  }

  @override
  State<MemberBenefitPage> createState() => _MemberBenefitPageState();
}

class _MemberBenefitPageState extends State<MemberBenefitPage> {
  // 只有积分页要用：进页时拉一次积分明细。坑：fetchPointLedger 走服务端，
  // 失败时 FutureBuilder 收到空列表即可，不要让整页报错。
  Future<List<WalletLedgerEntry>>? _ledgerFuture;

  @override
  void initState() {
    super.initState();
    if (widget.kind == MemberBenefitKind.pointsBoost) {
      _ledgerFuture = context.read<UserProvider>().fetchPointLedger();
    }
  }

  _BenefitMeta get _meta => _metas[widget.kind]!;

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: _meta.label,
      child: Consumer<UserProvider>(
        builder: (context, user, _) {
          final isMember = user.vipLevel >= memberTargetVipLevel;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(user, isMember),
              SizedBox(height: AppScale.s(14)),
              ..._content(context, user, isMember),
              SizedBox(height: AppScale.s(14)),
              _rulesCard(),
              SizedBox(height: AppScale.s(14)),
              if (!isMember) _subscribeHint(context),
            ],
          );
        },
      ),
    );
  }

  // 头图：渐变底 + 珐琅图标 + 一句话 + 右侧状态徽标（已开通/未开通）。
  Widget _hero(UserProvider user, bool isMember) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(16)),
      decoration: BoxDecoration(
        gradient: AppColors.profileMemberGradient,
        borderRadius: BorderRadius.circular(AppScale.s(14)),
      ),
      child: Row(
        children: [
          Image.asset(
            _meta.iconPath,
            width: AppScale.s(52),
            height: AppScale.s(52),
            errorBuilder: (_, __, ___) =>
                Icon(Icons.diamond, size: AppScale.s(40), color: AppColors.gold),
          ),
          SizedBox(width: AppScale.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_meta.label, style: FeaturePageStyle.bodyBold(color: Colors.white)),
                    SizedBox(width: AppScale.s(8)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(8), vertical: AppScale.s(2)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppScale.s(20)),
                      ),
                      child: Text(
                        _meta.valueText,
                        style: FeaturePageStyle.caption(color: Colors.white, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppScale.s(4)),
                Text(_meta.tagline, style: FeaturePageStyle.secondary(color: Colors.white70)),
                SizedBox(height: AppScale.s(4)),
                // 成长值与到期日：服务端资料接口已返回，显示真实值，不编造升级门槛。
                Text(
                  user.vipExpireAt.isNotEmpty
                      ? '成长值 ${user.growthPoints} · 有效期至 ${_formatDate(user.vipExpireAt)}'
                      : '成长值 ${user.growthPoints}',
                  style: FeaturePageStyle.caption(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
            decoration: BoxDecoration(
              color: isMember ? AppColors.gold : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppScale.s(20)),
            ),
            child: Text(
              isMember ? '已开通' : '未开通',
              style: FeaturePageStyle.caption(
                color: isMember ? Colors.black87 : Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 专属内容区：每种权益返回自己的卡片组合，这是「每页不一样」的核心。
  List<Widget> _content(BuildContext context, UserProvider user, bool isMember) {
    switch (widget.kind) {
      case MemberBenefitKind.monthlyCoupon:
        return _monthlyCouponContent(context, user, isMember);
      case MemberBenefitKind.pointsBoost:
        return _pointsContent(context, user, isMember);
      case MemberBenefitKind.discount:
        return _discountContent(context, user, isMember);
      case MemberBenefitKind.birthdayGift:
        return _birthdayContent(context, user, isMember);
      case MemberBenefitKind.priorityShipping:
        return _shippingContent(context, user, isMember);
    }
  }

  // ---- 每月赠券：券面 + 本月状态 + 领券/看券按钮（走真实领取逻辑） ----
  List<Widget> _monthlyCouponContent(BuildContext context, UserProvider user, bool isMember) {
    final claimed = user.memberMonthlyCouponClaimed;
    return [
      _ticketCard(),
      SizedBox(height: AppScale.s(12)),
      _statusRow('本月状态', !isMember ? '开通会员后可领' : (claimed ? '已领取，去优惠券里用吧' : '可领取')),
      SizedBox(height: AppScale.s(12)),
      if (isMember && !claimed)
        AppFilledButton(
          onPressed: () {
            final ok = user.claimMemberMonthlyCoupon();
            showTopSnackBar(
              context,
              content: Text(
                ok ? '领取成功，已放进你的优惠券' : '领取失败，请稍后再试',
                style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600),
              ),
            );
          },
          child: const Text('领取本月赠券'),
        ),
      if (isMember && claimed)
        AppFilledButton(
          onPressed: () => UserFeatureSheets.showCoupons(context),
          child: const Text('查看我的优惠券'),
        ),
    ];
  }

  // 券面：左边金额、右边名称与门槛，仿真实优惠券的两段式卡片。
  Widget _ticketCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '¥', style: FeaturePageStyle.bodyBold(color: AppColors.primary)),
                    TextSpan(text: '20', style: FeaturePageStyle.display(color: AppColors.primary)),
                  ],
                ),
              ),
              Text('满99可用', style: FeaturePageStyle.caption()),
            ],
          ),
          SizedBox(width: AppScale.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('会员每月赠券', style: FeaturePageStyle.bodyBold()),
                SizedBox(height: AppScale.s(4)),
                Text('每月 1 张 · 当月有效 · 结算时抵扣', style: FeaturePageStyle.secondary()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 积分加成：当前积分 + 倍率 + 最近 5 条明细 ----
  List<Widget> _pointsContent(BuildContext context, UserProvider user, bool isMember) {
    return [
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppScale.s(16)),
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
                  Text('当前积分', style: FeaturePageStyle.secondary()),
                  SizedBox(height: AppScale.s(4)),
                  Text('${user.points}', style: FeaturePageStyle.display()),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('当前倍率', style: FeaturePageStyle.secondary()),
                SizedBox(height: AppScale.s(4)),
                Text(
                  '×${isMember ? '1.5' : '1.0'}',
                  style: FeaturePageStyle.bodyBold(color: AppColors.primary),
                ),
                SizedBox(height: AppScale.s(2)),
                Text(isMember ? '会员加成生效中' : '开通会员变 ×1.5', style: FeaturePageStyle.caption()),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: AppScale.s(14)),
      Text('最近积分明细', style: FeaturePageStyle.sectionTitle()),
      SizedBox(height: AppScale.s(8)),
      FutureBuilder<List<WalletLedgerEntry>>(
        future: _ledgerFuture,
        builder: (context, snapshot) {
          final records = (snapshot.data ?? []).take(5).toList();
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (records.isEmpty) {
            return Text('暂无积分明细', style: FeaturePageStyle.secondary());
          }
          return Column(
            children: [
              for (final r in records)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: FeaturePageStyle.body()),
                            Text(r.time, style: FeaturePageStyle.caption()),
                          ],
                        ),
                      ),
                      Text(
                        r.amount >= 0 ? '+${r.amount}' : '${r.amount}',
                        style: FeaturePageStyle.bodyBold(
                          color: r.amount >= 0 ? AppColors.primary : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      SizedBox(height: AppScale.s(12)),
      AppFilledButton(
        onPressed: () => UserFeatureSheets.showDailyTasks(context),
        child: const Text('做每日任务赚积分'),
      ),
    ];
  }

  // ---- 专属折扣：生效状态 + 一个算例（服务端暂无结算逻辑，只展示） ----
  List<Widget> _discountContent(BuildContext context, UserProvider user, bool isMember) {
    return [
      _statusRow('折扣状态', isMember ? '生效中，结算时自动按 95 折算' : '未开通，开通会员后生效'),
      SizedBox(height: AppScale.s(12)),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppScale.s(16)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(12)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('举个例子', style: FeaturePageStyle.bodyBold()),
            SizedBox(height: AppScale.s(8)),
            _statusRow('一件指定商品', '¥199'),
            SizedBox(height: AppScale.s(4)),
            _statusRow('会员 95 折后', '¥189.05'),
            SizedBox(height: AppScale.s(4)),
            _statusRow('直接省下', '¥9.95'),
          ],
        ),
      ),
      SizedBox(height: AppScale.s(12)),
      AppFilledButton(
        onPressed: () {
          Navigator.pop(context);
          context.read<AppTabProvider>().goTo(AppTab.mall);
        },
        child: const Text('去逛逛指定商品'),
      ),
    ];
  }

  // ---- 生日礼包：我的生日 + 是否生日月 + 礼包内容 + 去设置/改生日 ----
  List<Widget> _birthdayContent(BuildContext context, UserProvider user, bool isMember) {
    final birthday = user.birthday; // yyyy-MM-dd，空 = 未设置
    final parsed = birthday.isEmpty ? null : DateTime.tryParse(birthday);
    final now = DateTime.now();
    final isBirthdayMonth = parsed != null && parsed.month == now.month;
    String daysText = '';
    if (parsed != null && !isBirthdayMonth) {
      // 距下次生日的天数：今年的生日过了就看明年。
      var next = DateTime(now.year, parsed.month, parsed.day);
      if (!next.isAfter(DateTime(now.year, now.month, now.day))) {
        next = DateTime(now.year + 1, parsed.month, parsed.day);
      }
      final days = next.difference(DateTime(now.year, now.month, now.day)).inDays;
      daysText = '还有 $days 天到你的生日';
    }
    return [
      _statusRow('我的生日', parsed == null ? '还没设置' : birthday),
      SizedBox(height: AppScale.s(8)),
      _statusRow(
        '礼包状态',
        parsed == null
            ? '先设置生日，生日当月才能领礼包'
            : (isBirthdayMonth ? '生日月到了，礼包本月内发放' : daysText),
      ),
      SizedBox(height: AppScale.s(12)),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppScale.s(16)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(12)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('礼包里有', style: FeaturePageStyle.bodyBold()),
            SizedBox(height: AppScale.s(8)),
            _statusRow('趣玩币', '+50'),
            SizedBox(height: AppScale.s(4)),
            _statusRow('限定徽章', '×1'),
          ],
        ),
      ),
      SizedBox(height: AppScale.s(12)),
      AppFilledButton(
        onPressed: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ProfileEditPage()),
          );
        },
        child: Text(parsed == null ? '去设置生日' : '修改生日'),
      ),
    ];
  }

  // ---- 优先发货：状态 + 最近 3 笔已发货订单（真实物流时间） ----
  List<Widget> _shippingContent(BuildContext context, UserProvider user, bool isMember) {
    final shipped = context
        .read<OrderProvider>()
        .orders
        .where((o) => o.shippedAt != null && o.shippedAt!.isNotEmpty)
        .take(3)
        .toList();
    return [
      _statusRow('优先拣货', isMember ? '生效中，现货订单 24 小时内发出' : '未开通，开通会员后生效'),
      SizedBox(height: AppScale.s(14)),
      Text('最近发货记录', style: FeaturePageStyle.sectionTitle()),
      SizedBox(height: AppScale.s(8)),
      if (shipped.isEmpty)
        Text('暂无已发货订单', style: FeaturePageStyle.secondary())
      else
        for (final o in shipped)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppScale.s(6)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.items.isEmpty ? '订单 ${o.orderNo}' : o.items.first.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FeaturePageStyle.body(),
                      ),
                      Text(
                        '${o.shippingCompany ?? '快递'} · ${_formatTime(o.shippedAt!)} 发出',
                        style: FeaturePageStyle.caption(),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.local_shipping_outlined, size: AppScale.s(20), color: AppColors.primary),
              ],
            ),
          ),
      SizedBox(height: AppScale.s(12)),
      AppFilledButton(
        onPressed: () => OrdersSheet.show(context),
        child: const Text('查看我的订单'),
      ),
    ];
  }

  // 规则说明卡：每页文案不同，来自 _metas 的 rules。
  Widget _rulesCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppScale.s(14)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('权益说明', style: FeaturePageStyle.bodyBold()),
          SizedBox(height: AppScale.s(8)),
          for (final rule in _meta.rules)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppScale.s(3)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: FeaturePageStyle.body(color: AppColors.primary)),
                  Expanded(child: Text(rule, style: FeaturePageStyle.secondary())),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 非会员页尾的开通引导：点开原「办理会员」弹层完成开通，不另写一套支付流程。
  Widget _subscribeHint(BuildContext context) {
    return AppFilledButton(
      onPressed: () => UserFeatureSheets.showMemberBenefits(context),
      child: Text('开通会员 · $memberSubscribeCoinPrice 趣玩币/月'),
    );
  }

  // 一行「左标签 + 右值」的通用状态行。
  Widget _statusRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: FeaturePageStyle.secondary()),
        SizedBox(width: AppScale.s(12)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: FeaturePageStyle.bodyBold(),
          ),
        ),
      ],
    );
  }

  // 会员到期 ISO 串展示成 yyyy-MM-dd；解析失败就原样返回。
  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  // 服务端 shippedAt 是 ISO 时间串，展示成 MM-dd HH:mm；解析失败就原样返回。
  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
