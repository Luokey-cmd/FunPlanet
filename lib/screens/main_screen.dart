import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../pages/home_page.dart';
import '../pages/mall_page.dart';
import '../pages/profile_page.dart';
import '../pages/xiaodou_chat_page.dart';
import '../providers/app_tab_provider.dart';
import '../theme/app_colors.dart';
import '../utils/user_session_sync.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/floating_ai_assistant.dart';
import '../widgets/tab_transition_scope.dart';

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

  late final AnimationController _animController;
  late final Animation<double> _anim;
  late final List<Widget> _pageWidgets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Widget _slideLayer({
    required int index,
    required double width,
    required double height,
    required bool isFrom,
  }) {
    final t = _anim.value;
    final dir = _slideDirection.toDouble();
    final dx = isFrom ? -dir * t * width : dir * (1 - t) * width;

    return Positioned(
      top: 0,
      left: dx,
      width: width,
      height: height,
      child: RepaintBoundary(
        child: ClipRect(
          child: _pageWidgets[index],
        ),
      ),
    );
  }

  Widget _buildPageStack(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    if (_fromTab == null) {
      return Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < _pageWidgets.length; i++)
            Offstage(
              offstage: _activeTab.index != i,
              child: SizedBox(width: width, height: height, child: _pageWidgets[i]),
            ),
        ],
      );
    }

    final fromIdx = _fromTab!.index;
    final toIdx = _activeTab.index;

    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < _pageWidgets.length; i++)
          if (i != fromIdx && i != toIdx)
            Offstage(offstage: true, child: _pageWidgets[i]),
        _slideLayer(index: fromIdx, width: width, height: height, isFrom: true),
        _slideLayer(index: toIdx, width: width, height: height, isFrom: false),
      ],
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
