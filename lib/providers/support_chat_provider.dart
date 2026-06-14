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
      final after = _messages.isEmpty ? null : _messages.last.createdAt;
      final incoming = await _service.fetchMessages(conv.id, after: after);
      if (incoming.isEmpty) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final fresh = incoming.where((m) => !existingIds.contains(m.id)).toList();
      if (fresh.isEmpty) return;

      final hasAdmin = fresh.any((m) => m.senderRole == SupportSenderRole.admin);
      _messages.addAll(fresh);
      if (hasAdmin) {
        await _service.markRead(conv.id);
      }
      await _persistCache();
      notifyListeners();
    } catch (_) {}
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
