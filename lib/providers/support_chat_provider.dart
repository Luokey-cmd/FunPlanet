import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/support_stickers.dart';
import '../models/support_message.dart';
import '../services/support_chat_history_storage.dart';
import '../services/support_chat_service.dart';

class SupportChatProvider extends ChangeNotifier {
  SupportChatProvider({SupportChatService? service, SupportChatHistoryStorage? storage})
      : _service = service ?? SupportChatService(),
        _storage = storage ?? SupportChatHistoryStorage();

  final SupportChatService _service;
  final SupportChatHistoryStorage _storage;

  String? _userKey;
  String? _activeSessionKey;
  SupportConversation? _conversation;
  final List<SupportMessage> _messages = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  SupportConversation? get conversation => _conversation;
  List<SupportMessage> get messages => List.unmodifiable(_messages);

  // 会话汇总（消息中心专用）：bindUser / 进消息页时只读拉一次列表，
  // 不打开会话、不标已读。与正在聊的 _conversation 是两套数据，互不干扰。
  List<SupportConversation> _conversationSummaries = [];

  List<SupportConversation> get conversationSummaries =>
      List.unmodifiable(_conversationSummaries);

  /// 客服未读总数：全部会话 unreadUser 相加（通用会话 + 商品咨询会话都算，
  /// 漏掉哪个都会出现「角标消了但里面还有红点」的对不上）。
  int get supportUnreadTotal =>
      _conversationSummaries.fold(0, (sum, c) => sum + c.unreadUser);

  /// 最新一条客服消息预览：列表由服务端按 lastMessageAt 倒序，第一条即最新。
  String? get latestSupportPreview =>
      _conversationSummaries.isEmpty ? null : _conversationSummaries.first.lastMessagePreview;

  /// 刷新会话汇总。拉不到就静默保留旧值（或空），不打扰用户、不弹错。
  Future<void> refreshConversationSummaries() async {
    if (_userKey == null) return;
    try {
      _conversationSummaries = await _service.fetchConversations();
      notifyListeners();
    } catch (_) {
      // 静默：消息中心的行会按旧值/空显示，下次进来再拉。
    }
  }
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  static String sessionKey({String? productId}) =>
      productId == null ? 'general' : 'product_$productId';

  Future<void> bindUser(String? userId) async {
    if (_userKey == userId) return;
    _userKey = userId;
    _stopPolling();
    _conversation = null;
    _messages.clear();
    _activeSessionKey = null;
    _loading = false;
    _sending = false;
    _error = null;

    if (userId != null) {
      await _restoreFromCache(sessionKey: 'general');
      unawaited(_open(productId: null, productName: null, subject: null));
      // 顺带拉一次会话汇总，让底部「消息」角标一登录就有数；
      // 不 await：汇总慢不能拖住聊天页打开。
      unawaited(refreshConversationSummaries());
    }
    notifyListeners();
  }

  Future<void> openGeneral() async {
    await _open(productId: null, productName: null, subject: null);
  }

  Future<void> openForProduct({
    required String productId,
    required String productName,
  }) async {
    await _open(
      productId: productId,
      productName: productName,
      subject: '商品咨询：$productName',
    );
  }

  Future<void> _restoreFromCache({required String sessionKey}) async {
    final cached = await _storage.load(_userKey, sessionKey);
    if (cached == null) return;
    _activeSessionKey = sessionKey;
    _conversation = cached.conversation;
    _messages
      ..clear()
      ..addAll(cached.messages);
  }

  Future<void> _persistCache() async {
    final conv = _conversation;
    final key = _activeSessionKey;
    if (conv == null || key == null) return;
    await _storage.save(_userKey, key, conv, _messages);
  }

  Future<void> _open({
    String? productId,
    String? productName,
    String? subject,
  }) async {
    final key = sessionKey(productId: productId);
    final sameSession = _activeSessionKey == key && _conversation != null;

    if (!sameSession) {
      _stopPolling();
      _activeSessionKey = key;
      _messages.clear();
      _conversation = null;
      _error = null;
      await _restoreFromCache(sessionKey: key);
    }

    final hadMessages = _messages.isNotEmpty;
    if (!hadMessages) {
      _loading = true;
      notifyListeners();
    }

    try {
      final result = await _service.openConversation(
        productId: productId,
        productName: productName,
        subject: subject,
      );
      _conversation = result.conversation;
      _messages
        ..clear()
        ..addAll(result.messages);
      await _service.markRead(result.conversation.id);
      // 刚标完已读，顺手刷新汇总，不然消息中心的客服角标还挂着旧未读数。
      unawaited(refreshConversationSummaries());
      await _persistCache();
      _startPolling();
      _error = null;
    } catch (e) {
      if (_messages.isEmpty) {
        _error = e.toString().replaceFirst('ApiException: ', '');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    await _sendMessage(
      type: SupportMessageType.text,
      content: content,
      optimistic: SupportMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        senderRole: SupportSenderRole.user,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendSticker(String stickerId) async {
    final sticker = findSupportSticker(stickerId);
    if (sticker == null) return;
    await _sendMessage(
      type: SupportMessageType.sticker,
      stickerId: stickerId,
      content: sticker.emoji,
      optimistic: SupportMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        senderRole: SupportSenderRole.user,
        messageType: SupportMessageType.sticker,
        content: sticker.emoji,
        stickerId: stickerId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendImage(List<int> bytes, String mimeType) async {
    if (_sending || _conversation == null) return;

    _sending = true;
    _error = null;
    notifyListeners();

    try {
      final mediaUrl = await _service.uploadImage(bytes, mimeType);
      await _sendMessage(
        type: SupportMessageType.image,
        mediaUrl: mediaUrl,
        content: '[图片]',
        optimistic: SupportMessage(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          senderRole: SupportSenderRole.user,
          messageType: SupportMessageType.image,
          content: '[图片]',
          mediaUrl: mediaUrl,
          createdAt: DateTime.now(),
        ),
        skipSendingFlag: true,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '');
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _sendMessage({
    required SupportMessageType type,
    required SupportMessage optimistic,
    String content = '',
    String? mediaUrl,
    String? stickerId,
    bool skipSendingFlag = false,
  }) async {
    if (_sending && !skipSendingFlag) return;
    if (_conversation == null) return;

    if (!skipSendingFlag) {
      _sending = true;
      _error = null;
    }

    final tempId = optimistic.id;
    _messages.add(optimistic);
    notifyListeners();

    try {
      final message = await _service.sendMessage(
        _conversation!.id,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        stickerId: stickerId,
      );
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index >= 0) {
        _messages[index] = message;
      } else if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
      }
      await _persistCache();
    } catch (e) {
      _messages.removeWhere((m) => m.id == tempId);
      _error = e.toString().replaceFirst('ApiException: ', '');
    } finally {
      if (!skipSendingFlag) {
        _sending = false;
      }
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollNewMessages());
  }

  Future<void> _pollNewMessages() async {
    final conv = _conversation;
    if (conv == null || _loading) return;

    try {
      // 全量拉取而不是只拉新增：撤回改的是旧消息的状态（recalledAt），
      // 只按时间拉新增，对方撤回了这边永远看不到。客服会话消息量小，
      // 全量换状态同步划算；合并按 id 原位更新状态、新消息追加，
      // 发送中的本地临时消息不在服务端列表里，不受影响。
      final incoming = await _service.fetchMessages(conv.id);
      if (incoming.isEmpty) return;

      var changed = false;
      var hasNewAdmin = false;
      final existingIds = _messages.map((m) => m.id).toSet();
      for (final serverMessage in incoming) {
        if (existingIds.contains(serverMessage.id)) {
          final index = _messages.indexWhere((m) => m.id == serverMessage.id);
          if (index >= 0 && _messages[index].recalledAt != serverMessage.recalledAt) {
            _messages[index] = serverMessage;
            changed = true;
          }
        } else {
          _messages.add(serverMessage);
          existingIds.add(serverMessage.id);
          changed = true;
          if (serverMessage.senderRole == SupportSenderRole.admin) {
            hasNewAdmin = true;
          }
        }
      }
      if (!changed) return;

      if (hasNewAdmin) {
        await _service.markRead(conv.id);
      }
      await _persistCache();
      notifyListeners();
    } catch (_) {}
  }

  // 撤回自己发的消息：调服务端接口，成功后原位换成撤回态并落缓存。
  // 输入：要撤回的消息；输出：成功返回 null，失败返回给用户看的文案（页面弹提示）。
  Future<String?> recallMessage(SupportMessage target) async {
    final conv = _conversation;
    if (conv == null) return '会话不存在';
    try {
      final updated = await _service.recallMessage(conv.id, target.id);
      final index = _messages.indexWhere((m) => m.id == target.id);
      if (index >= 0) {
        _messages[index] = updated;
      }
      await _persistCache();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '');
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> resetSession() async {
    _stopPolling();
    final userKey = _userKey;
    if (userKey != null) {
      await _storage.clearUser(userKey);
    }
    _userKey = null;
    _activeSessionKey = null;
    _conversation = null;
    _conversationSummaries = [];
    _messages.clear();
    _loading = false;
    _sending = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
