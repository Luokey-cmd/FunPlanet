package com.example.figmamake

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.speech.RecognizerIntent
import android.util.Base64
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
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
        cancelRecord()
        super.onDestroy()
    }
}
