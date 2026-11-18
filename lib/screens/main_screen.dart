import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../pages/home_page.dart';
import '../pages/mall_page.dart';
import '../pages/profile_page.dart';
import '../pages/xiaodou_chat_page.dart';
import '../data/product_data.dart';
import '../providers/app_tab_provider.dart';
import '../providers/user_provider.dart';
import '../services/daily_star_sign_picker.dart';
import '../services/daily_star_sign_storage.dart';
import '../services/xiaodou_guide_storage.dart';
import '../theme/app_colors.dart';
import '../utils/user_session_sync.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/daily_star_sign_sheet.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/xiaodou_guide_overlay.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  AppTab _activeTab = AppTab.home;
  AppTabProvider? _tabProvider;
  bool _showXiaodouGuide = false;
  final _guideStorage = XiaodouGuideStorage();
  final _starSignStorage = DailyStarSignStorage();

  late final List<Widget> _pages = const [
    _KeepAlivePage(key: ValueKey(AppTab.home), child: HomePage()),
    _KeepAlivePage(key: ValueKey(AppTab.mall), child: MallPage()),
    _KeepAlivePage(key: ValueKey(AppTab.cart), child: CartPage()),
    _KeepAlivePage(key: ValueKey(AppTab.profile), child: ProfilePage()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabProvider = context.read<AppTabProvider>();
      _tabProvider!.attach(_onTabTap);
      unawaited(_maybeShowGuideThenStarSign());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabProvider?.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshSessionData(context));
    }
  }

  /// 进门顺序（定死）：先小豆引导，后今日星签，两个层永不叠弹。
  /// 引导要弹的那天，星签打个 skipped 记号让路，当天不再自动弹，
  /// 第二天起恢复（首页常驻条当天仍可手动打开）。
  Future<void> _maybeShowGuideThenStarSign() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final userId = context.read<UserProvider>().userId;
    final seen = await _guideStorage.hasSeen(userId);
    if (!mounted) return;
    if (!seen) {
      await _starSignStorage.markSkippedToday(userId);
      if (!mounted) return;
      setState(() => _showXiaodouGuide = true);
      return;
    }
    await _maybeShowStarSign(userId);
  }

  Future<void> _maybeShowStarSign(String userId) async {
    final existing = await _starSignStorage.readToday(userId);
    if (!mounted || existing != null) return;
    final user = context.read<UserProvider>();
    final product = DailyStarSignPicker.pick(
      pool: products,
      browseHistoryIds: user.browseHistory,
      favoriteIds: user.favoriteIds,
      recentProductIds: await _starSignStorage.recentProductIds(userId),
      userId: userId,
      dateStr: DailyStarSignStorage.todayString(),
    );
    if (!mounted || product == null) return;
    final record = DailyStarSignRecord(
      date: DailyStarSignStorage.todayString(),
      state: DailyStarSignState.popped,
      productId: product.id,
    );
    await _starSignStorage.save(userId, record);
    // 引导检查已用掉 420ms，这里再补 180ms，凑齐设计稿的约 600ms。
    await Future<void>.delayed(const Duration(milliseconds: 180));
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
  }

  Future<void> _finishXiaodouGuide({bool openChat = false}) async {
    final userId = context.read<UserProvider>().userId;
    await _guideStorage.markSeen(userId);
    if (!mounted) return;
    setState(() => _showXiaodouGuide = false);
    if (openChat) {
      await XiaodouChatPage.open(context);
    }
  }

  void _onTabTap(AppTab tab) {
    if (_activeTab == tab) return;
    final toProfile = tab == AppTab.profile;
    setState(() => _activeTab = tab);
    if (toProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(refreshSessionData(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _activeTab.index,
                  sizing: StackFit.expand,
                  children: _pages,
                ),
              ),
              AppTabBar(active: _activeTab, onChange: _onTabTap),
            ],
          ),
        ),
        Positioned.fill(
          child: FloatingAiAssistant(
            onOpenChat: () => XiaodouChatPage.open(context),
          ),
        ),
        if (_showXiaodouGuide)
          Positioned.fill(
            child: XiaodouGuideOverlay(
              onFinished: () => unawaited(_finishXiaodouGuide()),
              onOpenXiaodou: () =>
                  unawaited(_finishXiaodouGuide(openChat: true)),
            ),
          ),
      ],
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
