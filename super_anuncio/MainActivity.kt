package br.com.superanuncio.super_anuncio

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "super_anuncio/share"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialSharedText" -> result.success(sharedTextFromIntent(intent))
                "initialReanalysis" -> result.success(reanalysisFromIntent(intent))
                "cacheDir" -> result.success(cacheDir.absolutePath)
                "shareText" -> {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) {
                        result.error("EMPTY_TEXT", "Nada para compartilhar", null)
                    } else {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(sendIntent, "Compartilhar análise"))
                        result.success(true)
                    }
                }
                "shareImage" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String
                    val text = args?.get("text") as? String
                    if (path.isNullOrBlank()) {
                        result.error("EMPTY_FILE", "Imagem não encontrada", null)
                    } else {
                        try {
                            val file = File(path)
                            val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(sendIntent, "Compartilhar conquista"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_IMAGE", e.message, null)
                        }
                    }
                }
                "scheduleReanalysis" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title") as? String ?: "Seu anúncio"
                    val url = args?.get("url") as? String ?: ""
                    val at = (args?.get("at") as? Number)?.toLong()
                    if (at == null) {
                        result.error("INVALID_TIME", "Data do lembrete inválida", null)
                    } else {
                        requestNotificationPermissionIfNeeded()
                        val id = (url + at.toString()).hashCode() and 0x7fffffff
                        ReminderScheduler.schedule(this, id, title, url, at)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = sharedTextFromIntent(intent)
        if (!text.isNullOrBlank()) channel?.invokeMethod("sharedText", text)
        val reminder = reanalysisFromIntent(intent)
        if (reminder != null) channel?.invokeMethod("reanalysisReminder", reminder)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8123)
        }
    }

    private fun sharedTextFromIntent(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }

    private fun reanalysisFromIntent(intent: Intent?): Map<String, String>? {
        val url = intent?.getStringExtra("reanalyze_url") ?: return null
        val title = intent.getStringExtra("reanalyze_title") ?: "Seu anúncio"
        return mapOf("url" to url, "title" to title)
    }
}
