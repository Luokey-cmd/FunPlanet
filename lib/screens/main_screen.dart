import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../pages/home_page.dart';
import '../pages/mall_page.dart';
import '../pages/profile_page.dart';
import '../pages/xiaodou_chat_page.dart';
import '../providers/app_tab_provider.dart';
import '../providers/user_provider.dart';
import '../services/xiaodou_guide_storage.dart';
import '../theme/app_colors.dart';
import '../utils/user_session_sync.dart';
import '../widgets/app_tab_bar.dart';
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
      unawaited(_maybeShowGuide());
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

  /// 进门引导：没看过小豆引导层时弹一次。
  /// （今日星签已于 2026-11-23 删除，进门不再有第二层弹层。）
  Future<void> _maybeShowGuide() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final userId = context.read<UserProvider>().userId;
    final seen = await _guideStorage.hasSeen(userId);
    if (!mounted || seen) return;
    setState(() => _showXiaodouGuide = true);
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
