package com.example.figmamake

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.RecognizerIntent
import android.util.Base64
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// 小豆语音：
/// 1) 有系统 RECOGNIZE_SPEECH Activity → Intent 弹窗
/// 2) 华为等只有 FakeRecognitionService、无弹窗 → MediaRecorder 录音，Dart 走千问 ASR
/// 绝不创建 SpeechRecognizer（会绑 FakeRecognitionService 杀进程）
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "funplanet/voice_input"
    private var pendingRecognize: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null

    private var mediaRecorder: MediaRecorder? = null
    private var recordFile: File? = null

    // 流式识别的 PCM 推流（EventChannel funplanet/voice_stream）
    private val streamChannelName = "funplanet/voice_stream"
    private var pcmRecord: AudioRecord? = null
    private var pcmThread: Thread? = null

    @Volatile
    private var pcmStreaming = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val speechLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { activityResult ->
            val result = pendingRecognize
            pendingRecognize = null
            if (result == null) return@registerForActivityResult
            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.success(null)
                return@registerForActivityResult
            }
            val matches =
                activityResult.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            result.success(matches?.firstOrNull())
        }

    private val micPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val result = pendingPermission
            pendingPermission = null
            result?.success(granted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            @Suppress("UNCHECKED_CAST")
            val clazz = Class.forName("com.csdcorp.speech_to_text.SpeechToTextPlugin")
                    as Class<out FlutterPlugin>
            flutterEngine.plugins.remove(clazz)
        } catch (_: Throwable) {
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        val activities = packageManager.queryIntentActivities(intent, 0)
                        result.success(activities.isNotEmpty())
                    }
                    "ensureMicPermission" -> ensureMicPermission(result)
                    "recognize" -> launchRecognize(call.argument("prompt"), result)
                    "startRecord" -> startRecord(result)
                    "stopRecord" -> stopRecord(result)
                    "cancelRecord" -> {
                        cancelRecord()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, streamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startPcmStream(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopPcmStream()
                }
            })
    }

    private fun ensureMicPermission(result: MethodChannel.Result) {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.error("busy", "permission request in flight", null)
            return
        }
        pendingPermission = result
        micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun launchRecognize(prompt: String?, result: MethodChannel.Result) {
        if (pendingRecognize != null) {
            result.error("busy", "already recognizing", null)
            return
        }
        if (!hasMicPermission()) {
            result.error("permission", "RECORD_AUDIO denied", null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt ?: "请说话")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            pendingRecognize = result
            speechLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            pendingRecognize = null
            result.error("unavailable", "no recognizer activity", null)
        } catch (e: Exception) {
            pendingRecognize = null
            result.error("unavailable", e.message, null)
        }
    }

    private fun startRecord(result: MethodChannel.Result) {
        if (mediaRecorder != null) {
            result.error("busy", "already recording", null)
            return
        }
        if (!hasMicPermission()) {
            result.error("permission", "RECORD_AUDIO denied", null)
            return
        }
        try {
            val file = File(cacheDir, "xiaodou_voice_${System.currentTimeMillis()}.m4a")
            if (file.exists()) file.delete()
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(16000)
            recorder.setAudioEncodingBitRate(64000)
            recorder.setAudioChannels(1)
            recorder.setOutputFile(file.absolutePath)
            recorder.prepare()
            recorder.start()
            mediaRecorder = recorder
            recordFile = file
            result.success(true)
        } catch (e: Exception) {
            cancelRecord()
            result.error("record_failed", e.message, null)
        }
    }

    private fun stopRecord(result: MethodChannel.Result) {
        val recorder = mediaRecorder
        val file = recordFile
        mediaRecorder = null
        recordFile = null
        if (recorder == null || file == null) {
            result.error("not_recording", "not recording", null)
            return
        }
        try {
            recorder.stop()
        } catch (_: Exception) {
        }
        try {
            recorder.release()
        } catch (_: Exception) {
        }
        try {
            if (!file.exists() || file.length() < 64) {
                file.delete()
                result.success(null)
                return
            }
            val bytes = file.readBytes()
            file.delete()
            val map = hashMapOf<String, Any>(
                "audioBase64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
                "mimeType" to "audio/mp4",
            )
            result.success(map)
        } catch (e: Exception) {
            try {
                file.delete()
            } catch (_: Exception) {
            }
            result.error("record_failed", e.message, null)
        }
    }

    /// 流式识别的录音：AudioRecord 采 PCM 原始片（16kHz 单声道 16bit），
    /// 每约 100ms 一片经 EventChannel 给 Dart 转发到服务端做实时识别。
    /// 只采裸音频、不碰任何系统识别服务，不会触发 FakeRecognitionService
    /// 杀进程的老问题。订阅取消（onCancel）即停采。
    private fun startPcmStream(events: EventChannel.EventSink?) {
        if (events == null) return
        if (pcmStreaming) {
            events.error("busy", "already streaming", null)
            return
        }
        if (!hasMicPermission()) {
            events.error("permission", "RECORD_AUDIO denied", null)
            return
        }
        val sampleRate = 16000
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val chunkBytes = 3200 // 100ms 的数据量：16000 样本/秒 × 2 字节 × 0.1 秒
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, chunkBytes * 4),
            )
        } catch (e: Exception) {
            events.error("record_failed", e.message, null)
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            try {
                record.release()
            } catch (_: Exception) {
            }
            events.error("record_failed", "AudioRecord init failed", null)
            return
        }
        pcmRecord = record
        pcmStreaming = true
        try {
            record.startRecording()
        } catch (e: Exception) {
            pcmStreaming = false
            pcmRecord = null
            try {
                record.release()
            } catch (_: Exception) {
            }
            events.error("record_failed", e.message, null)
            return
        }
        pcmThread = Thread {
            val buffer = ByteArray(chunkBytes)
            while (pcmStreaming) {
                val read = try {
                    record.read(buffer, 0, buffer.size)
                } catch (_: Exception) {
                    break
                }
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    // EventSink 回调切回主线程，符合平台通道的线程要求；
                    // 已停流时不再投递，防取消后还往 Dart 塞数据。
                    mainHandler.post {
                        if (pcmStreaming) {
                            try {
                                events.success(chunk)
                            } catch (_: Exception) {
                            }
                        }
                    }
                } else if (read < 0) {
                    break
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun stopPcmStream() {
        pcmStreaming = false
        val record = pcmRecord
        pcmRecord = null
        pcmThread = null
        if (record != null) {
            try {
                record.stop()
            } catch (_: Exception) {
            }
            try {
                record.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun cancelRecord() {
        val recorder = mediaRecorder
        val file = recordFile
        mediaRecorder = null
        recordFile = null
        try {
            recorder?.stop()
        } catch (_: Exception) {
        }
        try {
            recorder?.release()
        } catch (_: Exception) {
        }
        try {
            file?.delete()
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopPcmStream()
        cancelRecord()
        super.onDestroy()
    }
}
