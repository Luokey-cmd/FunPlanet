import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../data/product_data.dart';
import '../data/xiaodou_copy.dart';
import '../models/agent_records.dart';
import '../models/chat_message.dart';
import '../models/xiaodou_chat_session.dart';
import '../services/xiaodou_chat_history_storage.dart';
import '../services/user_cloud_api_service.dart';
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
    // 照片落盘用的压缩副本异步备好：原图最大 4MB，整份会话记录
    // 存在一份 JSON 里，原图 base64 塞进去会撑爆，所以存档只收
    // 压缩副本（最长边 512，见 _compressImageForStorage）。下面发
    // 服务端的请求用的仍是原图字节（本方法开头捕获的 imageBytes，
    // 副本替换只动消息列表、不动这个局部变量），看图质量不受影响。
    final userIndex = assistantIndex - 1;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      unawaited(_shrinkMessageImage(userIndex, imageBytes));
    }

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
            // 分组选项（optionSet）优先：有它就走分组渲染，单组 options 照旧。
            if (event.optionSet != null) {
              _messages[assistantIndex] = current.copyWith(optionSet: event.optionSet);
            } else if (event.options.isNotEmpty) {
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
          case XiaodouStreamKind.couponChoices:
            // 可领券清单：整卡挂到这条回复上，领取状态后续原地更新。
            if (event.couponChoices.isNotEmpty) {
              _messages[assistantIndex] = current.copyWith(couponChoices: event.couponChoices);
            }
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

  // 照片存档副本的最长边：聊天气泡里照片显示宽度约 200 逻辑像素，
  // 512 覆盖高清屏 2 倍采样还留余量，肉眼看不出糊；再大只是白白
  // 撑大存档 JSON。编码用 PNG 无损——512 尺寸下体积只有几十 KB，
  // 且 dart:ui 直接支持、不引第三方压缩包。
  static const int _storedImageMaxEdge = 512;

  /// 给指定下标的用户消息备一份压缩副本并换上，然后触发一次存档，
  /// 让会话记录里存的是小图而不是原图。
  ///
  /// 输入：消息下标 + 原图字节。输出：无（副作用是替换消息并存档）。
  /// 坑与取舍：压缩失败、或期间列表已被清空/重开对话导致对不上号，
  /// 一律静默放弃——这张图就不落盘，但发送与回复流程分毫不受影响；
  /// 已经比原图小的字节原样保留，不重复编码。换图只认内容签名
  /// （长度+首尾字节），不靠下标硬认，防止流式回复期间下标漂移认
  /// 错消息（用户消息在发送期间不会被改动，签名足够可靠）。
  Future<void> _shrinkMessageImage(int index, Uint8List original) async {
    final small = await _compressImageForStorage(original);
    if (small == null || small.length >= original.length) return;
    if (index < 0 || index >= _messages.length) return;
    final current = _messages[index];
    if (current.role != ChatRole.user || !_sameBytes(current.imageBytes, original)) return;
    _messages[index] = current.copyWith(imageBytes: small);
    await _persistCurrentSession();
  }

  /// 把图片字节缩到最长边 [_storedImageMaxEdge] 并以 PNG 重新编码；
  /// 本来就不超边时直接返回原字节。解码/编码任何一步失败返回 null，
  /// 调用方按「不落盘」处理。
  Future<Uint8List?> _compressImageForStorage(Uint8List bytes) async {
    ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _storedImageMaxEdge,
        targetHeight: _storedImageMaxEdge,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      // 两条边都没超：不用重编码（PNG 重编码可能反而比原图大）。
      if (image.width <= _storedImageMaxEdge && image.height <= _storedImageMaxEdge) {
        return bytes;
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// 轻量字节签名比对：整段逐字节比对太贵，长度 + 首尾各 16 字节
  /// 足以区分「还是不是当初那张图」（选图字节来自同一份内存数据）。
  bool _sameBytes(Uint8List? a, Uint8List b) {
    if (a == null || a.length != b.length) return false;
    final head = a.length < 16 ? a.length : 16;
    for (var i = 0; i < head; i++) {
      if (a[i] != b[i]) return false;
    }
    for (var i = 1; i <= head; i++) {
      if (a[a.length - i] != b[b.length - i]) return false;
    }
    return true;
  }

  // 点提问选项 = 用选项文字替用户发一句。先把这组选项标记用过
  // （整组撤掉、防重复点），再走正常发送流程；发送中直接忽略。
  Future<void> chooseOption(int messageIndex, String text) async {
    if (_sending) return;
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final target = _messages[messageIndex];
    // 分组选项的消息 options 是空的、答案在 optionSet 里，同样放行。
    if ((target.options.isEmpty && target.optionSet == null) || target.optionsUsed) return;
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

  /// 新手引导的直接抽牌（2026-11-27，主聊复核后改口径）：
  /// 引导三问是 App 自己亮的专用选项，不经模型提问——提交后按用户点的
  /// 条件直接调 draw-batch 接口抽第一批，再写成和流式亮牌同一形态的
  /// 命运消息（命运三翻的牌板/翻页/调档全靠这些字段）。输入是用户在
  /// 引导面板里点的三个条件；输出无（结果进消息列表）。
  /// 坑：_sending 期间不能走这里，引导提交时必须确认没有别的发送在跑；
  /// 抽空（0 件）也如实写消息，引导据此给兜底；功课段只写一句真实的
  /// 筛选条件，不编数据。
  Future<void> drawGuideCards({
    required String summary,
    required String majorCategory,
    required String query,
    required int? maxPrice,
  }) async {
    if (_sending) return;
    _messages.add(ChatMessage(role: ChatRole.user, content: summary));
    _messages.add(const ChatMessage(role: ChatRole.assistant, content: '按你的条件挑牌中…', isLoading: true));
    _sending = true;
    notifyListeners();
    final assistantIndex = _messages.length - 1;
    try {
      final args = <String, dynamic>{
        'majorCategory': majorCategory,
        'query': query,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };
      final result = await _service.drawBatch(args: args, excludeIds: const []);
      final products = result.products;
      _messages[assistantIndex] = ChatMessage(
        role: ChatRole.assistant,
        content: products.length >= 3
            ? '三张牌已经亮出来了，本命、遇见、余韵都在，点任意一张就能看详情。'
            : products.isEmpty
                ? '按这三个条件暂时没找到合适的牌，换个条件再试试。'
                : '牌已经亮出来了，点任意一张就能看详情。',
        homework: [
          HomeworkEntry(
            text: '按你的条件筛选：类型 $majorCategory · 系列 $query · 预算${maxPrice == null ? '不限' : '$maxPrice元内'}',
          ),
        ],
        products: products,
        starRoles: result.roles,
        fateBatches: products.isEmpty ? const [] : [products],
        fateRolesBatches: products.isEmpty ? const [] : [result.roles],
        fateIndex: 0,
        fateTotal: result.meta.totalCount,
        fateHasMore: result.meta.hasMore,
        drawArgs: result.meta.drawArgs,
        traits: result.meta.traits,
      );
      await _persistCurrentSession();
    } catch (_) {
      // 抽牌失败：留一条如实说明，不让对话停在「挑牌中…」。
      _messages[assistantIndex] = _messages[assistantIndex].copyWith(
        content: '抽牌这一下没成功，点「下一批」或换个条件再试试。',
        isLoading: false,
      );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

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

  /// 点券卡上的「领取」：走领券中心同款接口领这一组，领完把卡片
  /// 那行翻成已领取；失败把原因写回那一行（要开会员的翻成会员态、
  /// 其实已领过的翻成已领取）。返回是否领成，页面据此刷新券包。
  Future<bool> claimCouponChoice(int msgIndex, String group) async {
    if (msgIndex < 0 || msgIndex >= _messages.length) return false;
    final message = _messages[msgIndex];
    final at = message.couponChoices.indexWhere((c) => c.group == group);
    if (at < 0) return false;
    final choice = message.couponChoices[at];
    if (choice.status != 'claimable') return false;
    _patchCouponChoice(msgIndex, choice.copyWith(status: 'claiming', clearFailReason: true));
    try {
      final api = UserCloudApiService();
      switch (group) {
        case 'newcomer':
          await api.claimNewcomer();
        case 'member_monthly':
          await api.claimMemberMonthly();
        case 'center':
          await api.claimCenter();
        case 'center_200':
          await api.claimCenter200();
        case 'center_300':
          await api.claimCenter300();
        default:
          throw Exception('这张券不能在这里领');
      }
      _patchCouponChoice(
        msgIndex,
        choice.copyWith(status: 'claimed', statusText: '已领取', clearFailReason: true),
      );
      return true;
    } catch (e) {
      final reason = e.toString().replaceFirst('Exception: ', '');
      if (reason.contains('开通会员')) {
        _patchCouponChoice(
          msgIndex,
          choice.copyWith(status: 'member', statusText: '开通 VIP2 后可领', clearFailReason: true),
        );
      } else if (reason.contains('已领取')) {
        _patchCouponChoice(
          msgIndex,
          choice.copyWith(status: 'claimed', statusText: '已领取', clearFailReason: true),
        );
      } else {
        _patchCouponChoice(msgIndex, choice.copyWith(status: 'claimable', failReason: reason));
      }
      return false;
    }
  }

  void _patchCouponChoice(int msgIndex, CouponChoice next) {
    if (msgIndex < 0 || msgIndex >= _messages.length) return;
    final message = _messages[msgIndex];
    final list = List<CouponChoice>.from(message.couponChoices);
    final at = list.indexWhere((c) => c.group == next.group);
    if (at < 0) return;
    list[at] = next;
    _messages[msgIndex] = message.copyWith(couponChoices: list);
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
            // 照片已随存档落盘，重建时必须一并带回，漏了它从历史
            // 列表点开旧对话照片照样不显示（本批修复的主场景之一）。
            imageBytes: m.imageBytes,
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
