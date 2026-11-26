import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../pages/home_page.dart';
import '../pages/mall_page.dart';
import '../pages/messages_page.dart';
import '../pages/profile_page.dart';
import '../pages/xiaodou_chat_page.dart';
import '../providers/app_tab_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/user_session_sync.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/floating_ai_assistant.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  AppTab _activeTab = AppTab.home;
  AppTabProvider? _tabProvider;

  // 底部导航直达滑动（2026-11-23 hx 二次要求）：上一版用 PageView，
  // 相邻切换很顺，但从第 1 页跳到第 4 页时动画要拖着中间两页一起
  // 滑，又卡又乱。改成两页直达：五页全部常驻（不在台前的用
  // Offstage 收起，状态与滚动位置都保住），切换时只有「离开的页」
  // 和「进来的页」两页参与滑动——出去一屏、进来一屏，距离多远
  // 都是同一种滑动、同一个时长，中间页不参与、不拖速度。
  // 页序与 AppTab 枚举一一对应（首页/商城/消息/购物车/我的），
  // 滑动方向只比下标大小，中间插入消息页后天然适配，不用改逻辑。
  late final AnimationController _slideCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  AppTab? _outgoingTab; // 正在滑出的页，动画结束即清空
  double _slideDir = 1; // +1 新页从右进来，-1 从左进来

  late final List<Widget> _pages = const [
    _KeepAlivePage(key: ValueKey(AppTab.home), child: HomePage()),
    _KeepAlivePage(key: ValueKey(AppTab.mall), child: MallPage()),
    _KeepAlivePage(key: ValueKey(AppTab.message), child: MessagesPage()),
    _KeepAlivePage(key: ValueKey(AppTab.cart), child: CartPage()),
    _KeepAlivePage(key: ValueKey(AppTab.profile), child: ProfilePage()),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _outgoingTab != null) {
        setState(() => _outgoingTab = null);
      }
    });
    WidgetsBinding.instance.addObserver(this);
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
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshSessionData(context));
    }
  }

  void _onTabTap(AppTab tab) {
    if (_activeTab == tab) return;
    // 点按、程序跳转（AppTabProvider）都走这一条路：记下谁滑出、
    // 谁滑入与方向，动画从头播一遍。高亮立刻跟上（_activeTab 当场
    // 换），页面随后滑到，观感是「点哪去哪」。
    setState(() {
      _slideDir = tab.index > _activeTab.index ? 1.0 : -1.0;
      _outgoingTab = _activeTab;
      _activeTab = tab;
    });
    _slideCtrl.forward(from: 0);
    if (tab == AppTab.profile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(refreshSessionData(context));
      });
    }
  }

  /// 五页在台上的摆法：当前页与滑出页按动画进度平移，其余页
  /// Offstage 收起（不绘制、不响应，但状态保住）。
  Widget _pageLayer(int index, double width, double t) {
    final tab = AppTab.values[index];
    final isActive = tab == _activeTab;
    final isOutgoing = tab == _outgoingTab;
    if (!isActive && !isOutgoing) {
      return Offstage(offstage: true, child: _pages[index]);
    }
    var dx = 0.0;
    if (isOutgoing) {
      dx = -_slideDir * t * width;
    } else if (_outgoingTab != null) {
      dx = _slideDir * (1 - t) * width;
    }
    return Transform.translate(
      offset: Offset(dx, 0),
      child: IgnorePointer(
        // 动画期间两页都不许点（防滑到一半误触）；结束只放当前页。
        ignoring: !isActive || _outgoingTab != null,
        child: _pages[index],
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
                child: AnimatedBuilder(
                  animation: _slideCtrl,
                  builder: (context, _) {
                    final width = MediaQuery.sizeOf(context).width;
                    final t = Curves.easeOutCubic.transform(_slideCtrl.value);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          _pageLayer(i, width, t),
                      ],
                    );
                  },
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
    // RepaintBoundary 把整页缓存成独立图层：标签滑动时只平移图层，
    // 不再逐帧重画页面里的图片、阴影和渐变（2026-11-24 切换卡顿优化）。
    return RepaintBoundary(child: widget.child);
  }
}
