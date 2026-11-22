import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, WebSocket;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// 语音输入的可用性结论：调用方（输入栏）按这三种分别给提示，不许混成一句。
enum VoiceAvailability { ready, unavailable, permissionDenied }

enum _AndroidVoiceMode { intent, cloud }

/// 小豆语音输入。
///
/// Android（按优先级）：
/// - 流式识别（首选）：原生 AudioRecord 采 PCM 片，经自家服务端 WebSocket
///   中转到通义实时识别，边说边往输入框出字；服务端就绪前失败则静默回落。
/// - 有系统 RECOGNIZE_SPEECH 弹窗 → Intent（整段交付）
/// - 华为等无弹窗、只有 FakeRecognitionService → 本地录音 + `/api/voice/transcribe`（千问 ASR）
/// - 进程内绝不碰 speech_to_text（会杀进程）
///
/// iOS：speech_to_text 连续听写（本身就带中间结果）。
class VoiceInputService {
  static const _androidChannel = MethodChannel('funplanet/voice_input');

  SpeechToText? _speech;
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  _AndroidVoiceMode? _androidMode;
  Timer? _cloudMaxTimer;
  final ApiClient _api;

  // 流式识别（Android 首选）的连接与会话状态。
  static const _streamChannel = EventChannel('funplanet/voice_stream');
  WebSocket? _streamSocket;
  StreamSubscription<dynamic>? _streamSub;
  StreamSubscription<dynamic>? _audioSub;
  Completer<bool>? _streamReady;
  Completer<void>? _streamDone;
  Timer? _streamMaxTimer;
  bool _streamActive = false;
  bool _streamGotResult = false;
  bool _streamFailed = false;

  void Function(String words, bool isFinal)? _onResult;
  void Function(bool listening)? _onListeningChanged;
  void Function(String errorCode)? _onError;

  VoiceInputService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  bool get _useAndroid => !kIsWeb && Platform.isAndroid;

  bool get isListening =>
      _useAndroid ? _listening : (_speech?.isListening ?? false);

  SpeechToText get _speechOrThrow {
    return _speech ??= SpeechToText();
  }

  Future<VoiceAvailability> prepare() async {
    if (_useAndroid) {
      return _prepareAndroid();
    }
    return _prepareSpeechToText();
  }

  Future<VoiceAvailability> _prepareAndroid() async {
    try {
      final granted =
          await _androidChannel.invokeMethod<bool>('ensureMicPermission');
      if (granted != true) return VoiceAvailability.permissionDenied;

      final intentOk = await _androidChannel.invokeMethod<bool>('isAvailable');
      _androidMode =
          intentOk == true ? _AndroidVoiceMode.intent : _AndroidVoiceMode.cloud;
      return VoiceAvailability.ready;
    } on PlatformException catch (e) {
      if (e.code == 'permission') return VoiceAvailability.permissionDenied;
      return VoiceAvailability.unavailable;
    } catch (_) {
      return VoiceAvailability.unavailable;
    }
  }

  Future<VoiceAvailability> _prepareSpeechToText() async {
    final speech = _speechOrThrow;
    if (!_initialized) {
      try {
        _available = await speech.initialize(
          onStatus: _dispatchStatus,
          onError: _dispatchError,
        );
      } catch (_) {
        _available = false;
      } finally {
        _initialized = true;
      }
    }
    if (!_available) return VoiceAvailability.unavailable;
    try {
      final granted = await speech.hasPermission;
      if (!granted) return VoiceAvailability.permissionDenied;
    } catch (_) {
      return VoiceAvailability.unavailable;
    }
    return VoiceAvailability.ready;
  }

  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    required void Function(bool listening) onListeningChanged,
    void Function(String errorCode)? onError,
  }) async {
    if (isListening) return false;
    _onResult = onResult;
    _onListeningChanged = onListeningChanged;
    _onError = onError;
    if (_useAndroid) {
      // 首选流式（边说边出字）；没起来（没登录、连不上、服务端没就绪）
      // 时静默回落到原路线，弹窗/整段识别的行为与之前完全一致。
      if (await _startAndroidStream()) return true;
      if (_androidMode == _AndroidVoiceMode.intent) {
        return _startAndroidIntent();
      }
      return _startAndroidCloud();
    }
    return _startSpeechToText();
  }

  Future<bool> _startAndroidIntent() async {
    _listening = true;
    _onListeningChanged?.call(true);
    try {
      final text = await _androidChannel.invokeMethod<String>(
        'recognize',
        <String, dynamic>{'prompt': '说你想要的，小豆在听'},
      );
      _listening = false;
      _onListeningChanged?.call(false);
      final words = (text ?? '').trim();
      if (words.isEmpty) return true;
      _onResult?.call(words, true);
      return true;
    } on PlatformException catch (e) {
      _listening = false;
      _onListeningChanged?.call(false);
      // 弹窗不可用时自动切云识别再试一次。
      if (e.code == 'unavailable') {
        _androidMode = _AndroidVoiceMode.cloud;
        return _startAndroidCloud();
      }
      if (e.code == 'permission') {
        _onError?.call('error_permission');
      } else {
        _onError?.call(e.code);
      }
      return false;
    } catch (_) {
      _listening = false;
      _onListeningChanged?.call(false);
      return false;
    }
  }

  Future<bool> _startAndroidCloud() async {
    try {
      final ok = await _androidChannel.invokeMethod<bool>('startRecord');
      if (ok != true) return false;
      _listening = true;
      _onListeningChanged?.call(true);
      _cloudMaxTimer?.cancel();
      _cloudMaxTimer = Timer(const Duration(seconds: 30), () {
        if (_listening) {
          stopListening();
        }
      });
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'permission') {
        _onError?.call('error_permission');
      } else {
        _onError?.call(e.code);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── 流式识别（Android 首选）──────────────────────────────────────
  // 链路：原生 AudioRecord 采 PCM 片（EventChannel）→ 本服务 WebSocket
  // → 服务端中转 → 通义实时识别 → 中间结果经 _onResult 实时回填。
  // 服务端先回 ready 才算开听成功；ready 之前任何失败都返回 false，
  // 由 startListening 静默回落原路线，这条路只许变好、不许变坏。

  Future<bool> _startAndroidStream() async {
    try {
      final token = await TokenStorage().loadToken();
      if (token == null || token.isEmpty) return false;
      final base = await ApiConfig.baseUrl();
      final wsUrl =
          '${base.replaceFirst(RegExp(r'^http'), 'ws')}/api/voice/stream';
      final socket = await WebSocket.connect(
        wsUrl,
        headers: <String, dynamic>{'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));
      _streamSocket = socket;
      _streamReady = Completer<bool>();
      _streamDone = Completer<void>();
      _streamSub = socket.listen(
        _handleStreamEvent,
        onError: (_) => _handleStreamGone(),
        onDone: () => _handleStreamGone(),
      );
      final ready = await _streamReady!.future
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (!ready) {
        await _closeStreamSocket();
        return false;
      }
      // 开原生录音流：PCM 片送达后转手进 WebSocket（二进制帧）。
      _audioSub = _streamChannel.receiveBroadcastStream().listen(
        (Object? chunk) {
          final ws = _streamSocket;
          if (chunk is Uint8List &&
              ws != null &&
              ws.readyState == WebSocket.open) {
            ws.add(chunk);
          }
        },
        onError: (Object _) {
          // 录音流出错（权限中途被撤等）：按连接断开收口，已出字保住。
          _handleStreamGone();
        },
      );
      _streamActive = true;
      _streamFailed = false;
      _streamGotResult = false;
      _listening = true;
      _onListeningChanged?.call(true);
      _streamMaxTimer?.cancel();
      _streamMaxTimer = Timer(const Duration(seconds: 60), () {
        if (_streamActive) stopListening();
      });
      return true;
    } catch (_) {
      await _closeStreamSocket();
      return false;
    }
  }

  // 服务端小消息分发：partial 是本句中间结果（整段替换本句），final 是
  // 本句定稿；done 表示服务端收尾完成；error 已出字就当正常收尾保住
  // 文字，没出字才记失败，收口时统一报「不可用」。
  void _handleStreamEvent(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> event;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      event = decoded;
    } catch (_) {
      return;
    }
    switch (event['type']) {
      case 'ready':
        if (_streamReady != null && !_streamReady!.isCompleted) {
          _streamReady!.complete(true);
        }
      case 'partial':
        _streamGotResult = true;
        _onResult?.call(event['text']?.toString() ?? '', false);
      case 'final':
        _streamGotResult = true;
        _onResult?.call(event['text']?.toString() ?? '', true);
      case 'done':
        if (_streamDone != null && !_streamDone!.isCompleted) {
          _streamDone!.complete();
        }
      case 'error':
        if (!_streamGotResult) _streamFailed = true;
        if (_streamDone != null && !_streamDone!.isCompleted) {
          _streamDone!.complete();
        }
    }
  }

  // 连接自己断了（不是用户点停的收口）：先放行等结果的人，再收口。
  void _handleStreamGone() {
    if (_streamReady != null && !_streamReady!.isCompleted) {
      _streamReady!.complete(false);
    }
    if (_streamDone != null && !_streamDone!.isCompleted) {
      _streamDone!.complete();
    }
    if (!_streamActive) return;
    _streamActive = false;
    if (!_streamGotResult) _streamFailed = true;
    _finishStreamTeardown();
  }

  // 用户点停：先停录音，再通知服务端收尾，等最后一句定稿回来（最多
  // 3 秒）才关连接——直接关会把没说完的半句丢掉。
  Future<void> _stopAndroidStream() async {
    _streamActive = false; // 先摘牌，防连接关闭回调重入收口
    _streamMaxTimer?.cancel();
    _streamMaxTimer = null;
    final audioSub = _audioSub;
    _audioSub = null;
    try {
      await audioSub?.cancel();
    } catch (_) {}
    final socket = _streamSocket;
    if (socket != null && socket.readyState == WebSocket.open) {
      try {
        socket.add(jsonEncode(<String, String>{'type': 'stop'}));
      } catch (_) {}
      try {
        await _streamDone?.future.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    _finishStreamTeardown();
  }

  // 流式收口的公共部分：停计时、退订、关连接、切聆听态、统一报错。
  void _finishStreamTeardown() {
    _streamMaxTimer?.cancel();
    _streamMaxTimer = null;
    final audioSub = _audioSub;
    _audioSub = null;
    unawaited(audioSub?.cancel() ?? Future<void>.value());
    final sub = _streamSub;
    _streamSub = null;
    unawaited(sub?.cancel() ?? Future<void>.value());
    final socket = _streamSocket;
    _streamSocket = null;
    if (socket != null) {
      unawaited(() async {
        try {
          await socket.close();
        } catch (_) {}
      }());
    }
    if (_listening) {
      _listening = false;
      _onListeningChanged?.call(false);
    }
    if (_streamFailed && !_streamGotResult) {
      _onError?.call('unavailable');
    }
  }

  Future<void> _closeStreamSocket() async {
    final sub = _streamSub;
    _streamSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    final socket = _streamSocket;
    _streamSocket = null;
    try {
      await socket?.close();
    } catch (_) {}
  }

  Future<bool> _startSpeechToText() async {
    if (!_available) return false;
    final speech = _speechOrThrow;
    try {
      final localeId = await _pickChineseLocale();
      await speech.listen(
        onResult: (result) {
          _onResult?.call(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      _onListeningChanged?.call(false);
      return false;
    }
    return true;
  }

  Future<void> stopListening() async {
    if (_useAndroid) {
      if (_streamActive) {
        await _stopAndroidStream();
        return;
      }
      if (_androidMode == _AndroidVoiceMode.cloud && _listening) {
        await _finishAndroidCloud();
        return;
      }
      if (_listening) {
        _listening = false;
        _onListeningChanged?.call(false);
      }
      return;
    }
    try {
      final speech = _speech;
      if (speech != null && speech.isListening) {
        await speech.stop();
      }
    } catch (_) {}
  }

  Future<void> _finishAndroidCloud() async {
    _cloudMaxTimer?.cancel();
    _cloudMaxTimer = null;
    if (!_listening) return;
    _listening = false;
    _onListeningChanged?.call(false);

    Map<dynamic, dynamic>? payload;
    try {
      final raw = await _androidChannel.invokeMethod<dynamic>('stopRecord');
      if (raw is Map) payload = raw;
    } catch (_) {
      _onError?.call('record_failed');
      return;
    }
    if (payload == null) return;

    final audioBase64 = payload['audioBase64']?.toString() ?? '';
    final mimeType = payload['mimeType']?.toString() ?? 'audio/mp4';
    if (audioBase64.isEmpty) return;

    try {
      final data = await _api.post(
        '/api/voice/transcribe',
        {
          'audioBase64': audioBase64,
          'mimeType': mimeType,
        },
        auth: true,
        timeout: const Duration(seconds: 45),
      );
      final text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty) {
        _onError?.call('error_no_match');
        return;
      }
      _onResult?.call(text, true);
    } on ApiException catch (e) {
      if ((e.message).contains('未登录')) {
        _onError?.call('error_permission');
      } else {
        _onError?.call('unavailable');
      }
    } catch (_) {
      _onError?.call('unavailable');
    }
  }

  Future<String?> _pickChineseLocale() async {
    try {
      final locales = await _speechOrThrow.locales();
      String? fallback;
      for (final locale in locales) {
        final id = locale.localeId;
        final normalized = id.replaceAll('-', '_').toLowerCase();
        if (normalized == 'zh_cn') return id;
        if (normalized.startsWith('zh') && fallback == null) fallback = id;
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  void _dispatchStatus(String status) {
    if (status == 'listening') {
      _onListeningChanged?.call(true);
    } else if (status == 'notListening' ||
        status == 'done' ||
        status == 'doneNoResult') {
      _onListeningChanged?.call(false);
    }
  }

  void _dispatchError(SpeechRecognitionError error) {
    _onListeningChanged?.call(false);
    _onError?.call(error.errorMsg);
  }
}
