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
import '../widgets/tab_transition_scope.dart';
import '../widgets/xiaodou_guide_overlay.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppTab _activeTab = AppTab.home;
  AppTab? _fromTab;
  int _slideDirection = 1;
  AppTabProvider? _tabProvider;
  bool _showXiaodouGuide = false;
  final _guideStorage = XiaodouGuideStorage();

  late final AnimationController _animController;
  late final Animation<double> _anim;
  late final List<Widget> _pageWidgets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 固定四个页槽位，切 Tab 只改位移/显隐，不换父节点，避免商品图被拆掉重建。
    _pageWidgets = const [
      _KeepAlivePage(key: ValueKey(AppTab.home), child: HomePage()),
      _KeepAlivePage(key: ValueKey(AppTab.mall), child: MallPage()),
      _KeepAlivePage(key: ValueKey(AppTab.cart), child: CartPage()),
      _KeepAlivePage(key: ValueKey(AppTab.profile), child: ProfilePage()),
    ];
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _fromTab = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabProvider = context.read<AppTabProvider>();
      _tabProvider!.attach(_onTabTap);
      unawaited(_maybeShowXiaodouGuide());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabProvider?.detach();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshSessionData(context));
    }
  }

  Future<void> _maybeShowXiaodouGuide() async {
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
    if (_activeTab == tab || _animController.isAnimating) return;
    if (tab == AppTab.profile) {
      unawaited(refreshSessionData(context));
    }
    final from = _activeTab;
    setState(() {
      _fromTab = from;
      _slideDirection = tab.index > from.index ? 1 : -1;
      _activeTab = tab;
    });
    _animController.forward(from: 0);
  }

  Widget _buildPageStack(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final animating = _fromTab != null;
    final t = animating ? _anim.value : 0.0;
    final dir = _slideDirection.toDouble();
    final fromIdx = _fromTab?.index;
    final toIdx = _activeTab.index;

    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < _pageWidgets.length; i++)
          _pageSlot(
            index: i,
            width: width,
            height: height,
            animating: animating,
            fromIdx: fromIdx,
            toIdx: toIdx,
            t: t,
            dir: dir,
          ),
      ],
    );
  }

  Widget _pageSlot({
    required int index,
    required double width,
    required double height,
    required bool animating,
    required int? fromIdx,
    required int toIdx,
    required double t,
    required double dir,
  }) {
    var visible = false;
    var dx = 0.0;

    if (!animating) {
      visible = index == toIdx;
    } else if (index == fromIdx) {
      visible = true;
      dx = -dir * t * width;
    } else if (index == toIdx) {
      visible = true;
      dx = dir * (1 - t) * width;
    }

    return Positioned(
      key: ValueKey('tab_slot_$index'),
      top: 0,
      left: 0,
      width: width,
      height: height,
      child: Offstage(
        offstage: !visible,
        child: IgnorePointer(
          ignoring: index != toIdx,
          child: TickerMode(
            enabled: visible,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: RepaintBoundary(
                child: ClipRect(
                  child: _pageWidgets[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
                child: TabTransitionScope(
                  isAnimating: _fromTab != null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _anim,
                        builder: (context, _) => _buildPageStack(constraints),
                      );
                    },
                  ),
                ),
              ),
              AppTabBar(
                active: _activeTab,
                onChange: _onTabTap,
              ),
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
              onOpenXiaodou: () => unawaited(_finishXiaodouGuide(openChat: true)),
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

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
