import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../providers/support_chat_provider.dart';
import '../providers/xiaodou_chat_provider.dart';

Timer? _sessionPollTimer;

/// 轻量刷新：订单状态 + 消息通知（不拉全量用户资料）
Future<void> refreshSessionData(BuildContext context) async {
  final orders = context.read<OrderProvider>();
  final user = context.read<UserProvider>();
  final tasks = <Future<void>>[];
  if (orders.isCloudSync) tasks.add(orders.loadFromRemote());
  if (user.isCloudSync) tasks.add(user.refreshNotifications());
  if (tasks.isEmpty) return;
  await Future.wait(tasks);
}

void startSessionPolling(BuildContext context) {
  stopSessionPolling();
  _sessionPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
    if (!context.mounted) return;
    unawaited(refreshSessionData(context));
  });
}

void stopSessionPolling() {
  _sessionPollTimer?.cancel();
  _sessionPollTimer = null;
}

Future<void> syncUserSession(
  BuildContext context, {
  required String nickname,
  required String userId,
  required String phone,
  bool isNewUser = false,
}) async {
  final userProvider = context.read<UserProvider>();
  final cart = context.read<CartProvider>();
  final orders = context.read<OrderProvider>();

  userProvider.applyFromAuth(
    nickname: nickname,
    userId: userId,
    phone: phone,
    isNewUser: isNewUser,
  );
  cart.setCloudSync(true);
  orders.setCloudSync(true);
  await Future.wait([
    cart.loadFromRemote(),
    userProvider.loadFromRemote(),
    orders.loadFromRemote(),
  ]);
  await context.read<XiaodouChatProvider>().bindUser(userId);
  await context.read<SupportChatProvider>().bindUser(userId);
  startSessionPolling(context);
}

void clearUserSession(BuildContext context) {
  stopSessionPolling();
  context.read<CartProvider>().resetLocal();
  context.read<UserProvider>().resetForLogout();
  context.read<OrderProvider>().resetLocal();
  context.read<XiaodouChatProvider>().bindUser(null);
  unawaited(context.read<SupportChatProvider>().resetSession());
}
