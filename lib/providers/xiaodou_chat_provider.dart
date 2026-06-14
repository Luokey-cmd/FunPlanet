import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../data/product_data.dart';
import '../data/xiaodou_welcome.dart';
import '../models/chat_message.dart';
import '../models/xiaodou_chat_session.dart';
import '../services/xiaodou_chat_history_storage.dart';
import '../services/xiaodou_chat_service.dart';

class XiaodouChatProvider extends ChangeNotifier {
  XiaodouChatProvider({XiaodouChatService? service, XiaodouChatHistoryStorage? storage})
      : _service = service ?? XiaodouChatService(),
        _storage = storage ?? XiaodouChatHistoryStorage() {
    _initSession();
    _loadHistory();
  }

  final XiaodouChatService _service;
  final XiaodouChatHistoryStorage _storage;

  String? _userKey;
  String _currentSessionId = _newSessionId();
  final List<ChatMessage> _messages = [];
  List<XiaodouChatSession> _sessions = [];
  bool _sending = false;
  String? _error;
  bool _historyReady = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<XiaodouChatSession> get sessions => List.unmodifiable(_sessions);
  bool get sending => _sending;
  String? get error => _error;
  bool get historyReady => _historyReady;
  String? get currentSessionId => _currentSessionId;

  Future<void> bindUser(String? userId) async {
    if (_userKey == userId) return;
    await _persistCurrentSession();
    _userKey = userId;
    await _loadHistory();
    _initSession();
    notifyListeners();
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || _sending) return;

    _messages.add(ChatMessage(role: ChatRole.user, content: content));
    _messages.add(const ChatMessage(role: ChatRole.assistant, content: '思考中…', isLoading: true));
    _sending = true;
    _error = null;
    notifyListeners();

    final assistantIndex = _messages.length - 1;

    try {
      final history = _messages.where((m) => !m.isLoading).toList();
      var received = false;

      await for (final event in _service.sendMessageStream(history)) {
        if (event.isText) {
          received = true;
          if (_messages[assistantIndex].isLoading) {
            _messages[assistantIndex] = ChatMessage(role: ChatRole.assistant, content: event.content);
          } else {
            final current = _messages[assistantIndex];
            _messages[assistantIndex] = current.copyWith(content: current.content + event.content);
          }
        } else if (event.isProducts) {
          received = true;
          final current = _messages[assistantIndex];
          _messages[assistantIndex] = current.copyWith(
            content: current.isLoading ? '为你找到了这些商品～' : current.content,
            isLoading: false,
            products: event.products,
          );
        }
        notifyListeners();
      }

      if (!received) {
        _messages[assistantIndex] = const ChatMessage(
          role: ChatRole.assistant,
          content: '抱歉，我没有想好怎么说…',
        );
      }
    } catch (e) {
      _messages.removeAt(assistantIndex);
      _error = e.toString();
      ApiConfig.reset();
      final tried = ApiConfig.lastUsedUrl ?? ApiConfig.lastTriedUrl ?? '未知';
      final detail = ApiConfig.lastError ?? e.toString();
      _messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          content: kReleaseMode
              ? '抱歉，小豆暂时无法连接服务器。\n'
                  '原因：${_shortError(detail)}\n\n'
                  '请检查网络，或稍后再试。'
              : '抱歉，小豆连不上后端。\n'
                  '地址：$tried\n'
                  '原因：${_shortError(detail)}\n\n'
                  '请确认：① server 目录 npm run dev 已运行；'
                  '② 电脑调试先运行 scripts/adb-reverse.ps1（设备重连后会失效）；'
                  '③ 手机 APK 模式需同一 WiFi 并重新打包。',
        ),
      );
    } finally {
      _sending = false;
      await _persistCurrentSession();
      notifyListeners();
    }
  }

  Future<void> startNewChat() async {
    if (_sending) return;
    await _persistCurrentSession();
    _initSession();
    notifyListeners();
  }

  Future<void> openSession(String sessionId) async {
    if (_sending) return;
    final target = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (target == null) return;

    await _persistCurrentSession();

    _currentSessionId = target.id;
    _messages
      ..clear()
      ..addAll(target.messages.map((m) => ChatMessage(
            role: m.role,
            content: m.content,
            products: List<Product>.from(m.products),
          )));
    _error = null;
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _storage.save(_userKey, _sessions);

    if (_currentSessionId == sessionId) {
      _initSession();
    }
    notifyListeners();
  }

  Future<void> clearAllSessions() async {
    _sessions.clear();
    await _storage.save(_userKey, _sessions);
    _initSession();
    notifyListeners();
  }

  Future<void> togglePin(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;
    _sessions[index].pinned = !_sessions[index].pinned;
    _sortSessions();
    await _storage.save(_userKey, _sessions);
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;
    _sessions[index].title = trimmed;
    _sessions[index].updatedAt = DateTime.now();
    _sortSessions();
    await _storage.save(_userKey, _sessions);
    notifyListeners();
  }

  List<XiaodouChatSession> searchSessions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.from(_sessions);
    return _sessions.where((s) {
      if (s.title.toLowerCase().contains(q)) return true;
      if (s.preview.toLowerCase().contains(q)) return true;
      return s.messages.any((m) => m.content.toLowerCase().contains(q));
    }).toList();
  }

  String exportSessionText(String sessionId) {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return exportCurrentChatText();
    return _formatExport(session.title, session.messages);
  }

  String exportCurrentChatText() {
    final title = XiaodouChatSession.titleFromMessages(_messages);
    return _formatExport(title, _messages);
  }

  void resetConversation() {
    _initSession();
    _error = null;
    _sending = false;
    notifyListeners();
  }

  Future<void> refreshHistory() => _loadHistory();

  void _initSession() {
    _currentSessionId = _newSessionId();
    _messages
      ..clear()
      ..add(ChatMessage(role: ChatRole.assistant, content: XiaodouWelcome.pick()));
    _error = null;
    _sending = false;
  }

  Future<void> _loadHistory() async {
    _sessions = await _storage.load(_userKey);
    _historyReady = true;
    notifyListeners();
  }

  Future<void> _persistCurrentSession() async {
    if (!_hasUserMessages(_messages)) return;

    final storable = _messages.where((m) => !m.isLoading).toList();
    if (storable.isEmpty) return;

    final now = DateTime.now();
    final index = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (index >= 0) {
      _sessions[index]
        ..messages = List.from(storable)
        ..updatedAt = now;
      if (_sessions[index].title == '新对话' || _sessions[index].title.trim().isEmpty) {
        _sessions[index].title = XiaodouChatSession.titleFromMessages(storable);
      }
    } else {
      _sessions.insert(
        0,
        XiaodouChatSession(
          id: _currentSessionId,
          title: XiaodouChatSession.titleFromMessages(storable),
          messages: List.from(storable),
          updatedAt: now,
          createdAt: now,
        ),
      );
    }
    _sortSessions();
    await _storage.save(_userKey, _sessions);
  }

  void _sortSessions() {
    _sessions.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  bool _hasUserMessages(List<ChatMessage> messages) {
    return messages.any((m) => m.role == ChatRole.user && m.content.trim().isNotEmpty);
  }

  String _formatExport(String title, List<ChatMessage> messages) {
    final buffer = StringBuffer('【$title】\n\n');
    for (final m in messages) {
      if (m.isLoading || m.content.trim().isEmpty) continue;
      final speaker = m.role == ChatRole.user ? '我' : '小豆';
      buffer.writeln('$speaker：${m.content}');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static String _newSessionId() => 'xd_${DateTime.now().millisecondsSinceEpoch}';

  static String _shortError(String raw) {
    final text = raw.replaceFirst('Exception: ', '').replaceFirst('ClientException: ', '');
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}…';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
