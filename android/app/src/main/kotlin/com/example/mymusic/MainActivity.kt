package com.example.mymusic

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.stream.StreamInfo

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.mymusic/youtube_android"
    private val PERMISSION_CHANNEL = "com.mymusic/notification_permission"
    private val NOTIFICATION_PERMISSION_CODE = 999
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val TAG = "NewPipeResolver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            NewPipe.init(DownloaderImpl.getInstance())
            Log.d(TAG, "NewPipe Extractor successfully initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing NewPipe Extractor", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolveVideo" -> {
                    val rawInput = call.argument<String>("videoId") ?: call.argument<String>("url")
                    if (rawInput.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "videoId / url YouTube tidak boleh kosong", null)
                        return@setMethodCallHandler
                    }

                    val cleanInput = rawInput.trim()
                    val videoUrl = if (cleanInput.startsWith("http://") || cleanInput.startsWith("https://")) {
                        cleanInput
                    } else {
                        "https://www.youtube.com/watch?v=$cleanInput"
                    }

                    Log.d(TAG, "[YouTube][Android][NewPipe] Resolving: $cleanInput")

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val streamInfo = StreamInfo.getInfo(ServiceList.YouTube, videoUrl)
                            val audioStreams = streamInfo.audioStreams

                            if (audioStreams.isNullOrEmpty()) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "NO_AUDIO_STREAMS",
                                        "Tidak ada audio stream yang dapat diekstrak oleh NewPipe",
                                        null
                                    )
                                }
                                return@launch
                            }

                            // Choose the audio stream with highest bitrate
                            val bestAudio = audioStreams.maxByOrNull {
                                if (it.averageBitrate > 0) it.averageBitrate else it.bitrate
                            } ?: audioStreams.first()

                            val audioUrl = bestAudio.content
                            if (audioUrl.isNullOrBlank()) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "EMPTY_STREAM_URL",
                                        "Stream URL yang diekstrak kosong",
                                        null
                                    )
                                }
                                return@launch
                            }

                            val videoId = streamInfo.id ?: cleanInput
                            val title = streamInfo.name ?: ""
                            val artist = streamInfo.uploaderName ?: ""
                            val duration = streamInfo.duration.toInt()
                            val thumbnail = streamInfo.thumbnails.firstOrNull()?.url ?: ""
                            val mimeType = bestAudio.format?.mimeType ?: "audio/mp4"
                            val bitrate = if (bestAudio.averageBitrate > 0) bestAudio.averageBitrate else bestAudio.bitrate

                            val headers = hashMapOf<String, String>(
                                "User-Agent" to DownloaderImpl.USER_AGENT
                            )

                            val responseMap = hashMapOf<String, Any?>(
                                "videoId" to videoId,
                                "title" to title,
                                "artist" to artist,
                                "duration" to duration,
                                "thumbnail" to thumbnail,
                                "audioUrl" to audioUrl,
                                "mimeType" to mimeType,
                                "bitrate" to bitrate,
                                "headers" to headers
                            )

                            Log.d(TAG, "[YouTube][Android][NewPipe] Successfully resolved videoId=$videoId, bitrate=$bitrate, duration=$duration")

                            withContext(Dispatchers.Main) {
                                result.success(responseMap)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "[YouTube][Android][NewPipe] Extraction error: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error(
                                    "NEWPIPE_EXTRACTION_FAILED",
                                    "NewPipe extraction failed: ${e.message}",
                                    e.localizedMessage
                                )
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_CODE)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(isGranted)
            pendingPermissionResult = null
        }
    }
}
