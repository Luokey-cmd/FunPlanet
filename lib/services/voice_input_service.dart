import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'api_client.dart';

/// 语音输入的可用性结论：调用方（输入栏）按这三种分别给提示，不许混成一句。
enum VoiceAvailability { ready, unavailable, permissionDenied }

enum _AndroidVoiceMode { intent, cloud }

/// 小豆语音输入。
///
/// Android：
/// - 有系统 RECOGNIZE_SPEECH 弹窗 → Intent
/// - 华为等无弹窗、只有 FakeRecognitionService → 本地录音 + `/api/voice/transcribe`（千问 ASR）
/// - 进程内绝不碰 speech_to_text（会杀进程）
///
/// iOS：speech_to_text 连续听写。
class VoiceInputService {
  static const _androidChannel = MethodChannel('funplanet/voice_input');

  SpeechToText? _speech;
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  _AndroidVoiceMode? _androidMode;
  Timer? _cloudMaxTimer;
  final ApiClient _api;

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
