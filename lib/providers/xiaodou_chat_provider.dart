import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../data/product_data.dart';
import '../data/xiaodou_copy.dart';
import '../models/agent_records.dart';
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
  Map<String, dynamic>? _starwish;

  // 进门盘点（长记性）：进小豆页时拉一次，没办完的事挂在首页区顶部；
  // 用户点叉关掉就不再打扰（本次打开内有效）。
  List<BriefingMatter> _briefingMatters = [];
  bool _briefingDismissed = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<XiaodouChatSession> get sessions => List.unmodifiable(_sessions);
  bool get sending => _sending;
  String? get error => _error;
  bool get historyReady => _historyReady;
  String? get currentSessionId => _currentSessionId;
  List<BriefingMatter> get briefingMatters => List.unmodifiable(_briefingMatters);
  bool get briefingDismissed => _briefingDismissed;

  // 每次打开小豆页都重新盘一遍（页面 initState 调）：刚付完的订单
  // 不再挂着、刚建的待付款能及时出现，别拿旧盘点糊弄人。
  void refreshBriefing() {
    if (_userKey == null) return;
    _loadBriefing();
  }

  void dismissBriefing() {
    if (_briefingDismissed) return;
    _briefingDismissed = true;
    notifyListeners();
  }

  // 盘点是锦上添花：拉不到就当没事发生，绝不挡聊天、不报错。
  Future<void> _loadBriefing() async {
    try {
      final matters = await _service.fetchBriefing();
      _briefingMatters = matters;
      _briefingDismissed = false;
      notifyListeners();
    } catch (_) {
      _briefingMatters = [];
    }
  }

  Future<void> bindUser(String? userId) async {
    if (_userKey == userId) return;
    await _persistCurrentSession();
    _userKey = userId;
    await _loadHistory();
    _initSession();
    notifyListeners();
    // 换人/首次绑定后盘一遍没办完的事（不 await，回来自己刷新界面）。
    if (userId != null) {
      _loadBriefing();
    } else {
      _briefingMatters = [];
    }
  }

  Future<void> send(
    String text, {
    Uint8List? imageBytes,
    String? mimeType,
    Map<String, dynamic>? starwish,
    Map<String, String>? vision,
  }) async {
    var content = text.trim();
    if (content.isEmpty && imageBytes != null && imageBytes.isNotEmpty) {
      content = '帮我看看店里有没有同款或同类';
    }
    if (content.isEmpty || _sending) return;
    if (starwish != null) _starwish = starwish;

    _messages.add(ChatMessage(role: ChatRole.user, content: content, imageBytes: imageBytes));
    _messages.add(const ChatMessage(role: ChatRole.assistant, content: '思考中…', isLoading: true));
    _sending = true;
    _error = null;
    notifyListeners();

    final assistantIndex = _messages.length - 1;

    try {
      final history = _messages.where((m) => !m.isLoading).toList();
      var received = false;
      final imageBase64 = imageBytes != null && imageBytes.isNotEmpty ? base64Encode(imageBytes) : null;

      await for (final event in _service.sendMessageStream(
        history,
        imageBase64: imageBase64,
        mimeType: mimeType,
        starwish: _starwish,
        vision: vision,
      )) {
        received = true;
        final current = _messages[assistantIndex];
        switch (event.kind) {
          case XiaodouStreamKind.text:
            if (current.isLoading) {
              // 第一片答案：换掉占位文案，但保住已收到的思考过程。
              _messages[assistantIndex] = current.copyWith(content: event.content, isLoading: false);
            } else {
              _messages[assistantIndex] = current.copyWith(content: current.content + event.content);
            }
          case XiaodouStreamKind.status:
            // 状态提示只在还没正式内容时换占位文案（如「联网搜索中…」）。
            if (current.isLoading) {
              _messages[assistantIndex] = current.copyWith(content: event.content);
            }
          case XiaodouStreamKind.thinking:
            // 思考过程往本条消息上累计，气泡单独渲染，不混进答案正文。
            _messages[assistantIndex] = current.copyWith(
              thinking: current.thinking + event.content,
            );
          case XiaodouStreamKind.products:
            _messages[assistantIndex] = current.copyWith(
              content: current.isLoading ? XiaodouCopy.pick(XiaodouCopy.moreShelf) : current.content,
              isLoading: false,
              products: event.products,
              starRoles: const [],
            );
          case XiaodouStreamKind.fate:
            _messages[assistantIndex] = current.copyWith(
              // 货架不足三件时别硬说三张牌（2026-11-23 自查修）。
              content: current.isLoading
                  ? (event.products.length >= 3
                        ? '三张牌已经亮出来了，本命、遇见、余韵都在，点任意一张就能看详情。'
                        : '牌已经亮出来了，点任意一张就能看详情。')
                  : current.content,
              isLoading: false,
              products: event.products,
              starRoles: event.roles,
              fateBatches: [event.products],
              fateRolesBatches: [event.roles],
              fateIndex: 0,
              fateTotal: event.batch?.totalCount ?? event.products.length,
              fateHasMore: event.batch?.hasMore ?? false,
              drawArgs: event.batch?.drawArgs ?? const {},
              traits: event.batch?.traits ?? const {},
            );
          case XiaodouStreamKind.actions:
            // 办事清单：按 id 追加或覆盖（同轮改量合并、付款后翻状态都靠它）
            final incoming = event.action;
            if (incoming != null && incoming.id.isNotEmpty) {
              final list = List<AgentAction>.from(current.actions);
              final at = list.indexWhere((a) => a.id == incoming.id);
              if (at >= 0) {
                list[at] = incoming;
              } else {
                list.add(incoming);
              }
              _messages[assistantIndex] = current.copyWith(actions: list);
            }
          case XiaodouStreamKind.homework:
            final entry = event.homeworkEntry;
            if (entry != null && entry.text.isNotEmpty) {
              _messages[assistantIndex] = current.copyWith(
                homework: [...current.homework, entry],
              );
            }
          case XiaodouStreamKind.options:
            // 提问选项挂到这条回复上，页面在气泡下方渲染成按钮。
            if (event.options.isNotEmpty) {
              _messages[assistantIndex] = current.copyWith(options: event.options);
            }
          case XiaodouStreamKind.cart:
            _messages[assistantIndex] = current.copyWith(
              content: current.isLoading ? XiaodouCopy.confirmCart : current.content,
              isLoading: false,
              pendingCart: event.pendingCart,
            );
          case XiaodouStreamKind.appraisal:
            _messages[assistantIndex] = current.copyWith(
              content: event.content.isEmpty ? '光已经落进瓶子里。' : event.content,
              isLoading: false,
              isAppraisal: true,
              visionPayload: event.vision,
            );
          case XiaodouStreamKind.giftNote:
            _messages[assistantIndex] = current.copyWith(
              content: current.isLoading ? event.content : current.content,
              isLoading: false,
              giftNote: event.content,
            );
        }
        notifyListeners();
      }

      if (!received) {
        _messages[assistantIndex] = const ChatMessage(
          role: ChatRole.assistant,
          content: '抱歉，我没有想好怎么说…',
        );
      } else if (_messages[assistantIndex].isLoading) {
        // 只收到状态/思考/清单事件就断了流：不能把转圈占位永远留着，
        // 收成一句兜底。已收到的办事清单、功课、卡片必须原样保住
        // ——以前这里整条重建消息，纯办事轮次（只办事、没正文）会
        // 把办好的事连清单一起抹掉、只剩一句抱歉（2026-11-23
        // 全面自查修）。
        final tail = _messages[assistantIndex];
        _messages[assistantIndex] = tail.copyWith(
          content: tail.hasAgentCard ? '办好了，清单在下面，你看看。' : '抱歉，我没有想好怎么说…',
          isLoading: false,
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

  // 点提问选项 = 用选项文字替用户发一句。先把这组选项标记用过
  // （整组撤掉、防重复点），再走正常发送流程；发送中直接忽略。
  Future<void> chooseOption(int messageIndex, String text) async {
    if (_sending) return;
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final target = _messages[messageIndex];
    if (target.options.isEmpty || target.optionsUsed) return;
    _messages[messageIndex] = target.copyWith(optionsUsed: true);
    notifyListeners();
    await send(text);
  }

  List<Product> get lastRecommendedProducts {
    for (final message in _messages.reversed) {
      if (message.role == ChatRole.assistant && message.products.isNotEmpty) {
        return message.products;
      }
    }
    return const [];
  }

  List<Product> get pendingCartProducts {
    for (final message in _messages.reversed) {
      if (message.hasPendingCart) return message.pendingCart;
    }
    return const [];
  }

  void clearPendingCart() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].hasPendingCart) {
        _messages[i] = _messages[i].copyWith(pendingCart: const []);
        notifyListeners();
        return;
      }
    }
  }

  Future<void> requestAnotherBatch() async {
    final products = lastRecommendedProducts;
    if (products.isEmpty || _sending) return;
    final ids = products.map((p) => p.id).join('、');
    final category = products.first.majorCategory;
    await send('换一批，不要这些商品：$ids。优先同一分类「$category」。');
  }

  Future<void> requestSimilar() async {
    final products = lastRecommendedProducts;
    if (products.isEmpty || _sending) return;
    final ids = products.map((p) => p.id).join('、');
    final category = products.first.majorCategory;
    await send('再看看「$category」里的同类，排除这些：$ids');
  }

  // 正在拉下一批的消息下标（防重复点），界面拿它转圈。
  final Set<int> _batchLoading = {};

  bool isBatchLoading(int index) => _batchLoading.contains(index);

  /// 亮牌「下一批」：拿服务端回带的抽牌条件 + 已展示的全部商品 id
  /// 接着抽，抽到的新一批原样存下并切过去；池子空了就把 hasMore 关掉。
  Future<void> nextFateBatch(int index) async {
    if (index < 0 || index >= _messages.length || _batchLoading.contains(index)) return;
    final message = _messages[index];
    if (!message.fateHasMore || message.fateBatches.isEmpty) return;
    _batchLoading.add(index);
    notifyListeners();
    try {
      final excludeIds = message.fateBatches.expand((b) => b).map((p) => p.id).toList();
      final result = await _service.drawBatch(args: message.drawArgs, excludeIds: excludeIds);
      final current = _messages[index];
      if (result.products.isEmpty) {
        _messages[index] = current.copyWith(fateHasMore: false);
      } else {
        final batches = [...current.fateBatches, result.products];
        final roleBatches = [...current.fateRolesBatches, result.roles];
        _messages[index] = current.copyWith(
          fateBatches: batches,
          fateRolesBatches: roleBatches,
          fateIndex: batches.length - 1,
          products: result.products,
          starRoles: result.roles,
          fateHasMore: result.meta.hasMore,
          fateTotal: current.fateTotal > 0 ? current.fateTotal : result.meta.totalCount + excludeIds.length,
          traits: {...current.traits, ...result.meta.traits},
        );
      }
      await _persistCurrentSession();
    } catch (_) {
      // 拉下一批失败不打断聊天：按钮还在，用户可以再点一次
    } finally {
      _batchLoading.remove(index);
      notifyListeners();
    }
  }

  /// 上一批/下一批切换：只动下标，牌都是存好的，不发请求。
  void setFateBatchIndex(int index, int batchIndex) {
    if (index < 0 || index >= _messages.length) return;
    final message = _messages[index];
    if (batchIndex < 0 || batchIndex >= message.fateBatches.length) return;
    _messages[index] = message.copyWith(
      fateIndex: batchIndex,
      products: message.fateBatches[batchIndex],
      starRoles: batchIndex < message.fateRolesBatches.length
          ? message.fateRolesBatches[batchIndex]
          : message.starRoles,
    );
    notifyListeners();
  }

  /// 牌面调档（预算/路线）：按新条件从第一批重新抽，旧批次作废。
  Future<void> refilterFate(int index, {int? maxPrice, String? sort}) async {
    if (index < 0 || index >= _messages.length || _batchLoading.contains(index)) return;
    final message = _messages[index];
    final args = Map<String, dynamic>.from(message.drawArgs);
    if (maxPrice != null) {
      if (maxPrice <= 0) {
        args.remove('maxPrice');
      } else {
        args['maxPrice'] = maxPrice;
      }
    }
    if (sort != null) args['sort'] = sort;
    _batchLoading.add(index);
    notifyListeners();
    try {
      final result = await _service.drawBatch(args: args, excludeIds: const []);
      if (result.products.isEmpty) return;
      _messages[index] = _messages[index].copyWith(
        fateBatches: [result.products],
        fateRolesBatches: [result.roles],
        fateIndex: 0,
        products: result.products,
        starRoles: result.roles,
        fateHasMore: result.meta.hasMore,
        fateTotal: result.meta.totalCount,
        drawArgs: args,
        traits: result.meta.traits,
      );
      await _persistCurrentSession();
    } catch (_) {
      // 调档失败保持原样，用户可再试
    } finally {
      _batchLoading.remove(index);
      notifyListeners();
    }
  }

  /// 清单里的待付款订单被用户付掉后回写：状态翻成已办好，
  /// 明细补一句已付款（清单是快照，这里只动这一条的状态）。
  void markActionPaid(int index, String actionId) {
    if (index < 0 || index >= _messages.length) return;
    final message = _messages[index];
    final at = message.actions.indexWhere((a) => a.id == actionId);
    if (at < 0) return;
    final list = List<AgentAction>.from(message.actions);
    final action = list[at];
    list[at] = action.copyWith(
      status: 'done',
      detail: action.detail.contains('已付款') ? action.detail : '${action.detail} · 已付款',
    );
    _messages[index] = message.copyWith(actions: list);
    _persistCurrentSession();
    notifyListeners();
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
            starRoles: List<String>.from(m.starRoles),
            giftNote: m.giftNote,
            actions: List<AgentAction>.from(m.actions),
            homework: List<HomeworkEntry>.from(m.homework),
            fateBatches: m.fateBatches.map((b) => List<Product>.from(b)).toList(),
            fateRolesBatches: m.fateRolesBatches.map((r) => List<String>.from(r)).toList(),
            fateIndex: m.fateIndex,
            fateTotal: m.fateTotal,
            fateHasMore: m.fateHasMore,
            drawArgs: Map<String, dynamic>.from(m.drawArgs),
            traits: Map<String, String>.from(m.traits),
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
      ..add(ChatMessage(role: ChatRole.assistant, content: XiaodouCopy.pick(XiaodouCopy.openings)));
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
