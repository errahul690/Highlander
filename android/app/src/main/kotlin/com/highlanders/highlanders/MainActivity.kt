package com.highlanders.highlanders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.app.Activity
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.TextView
import java.io.File
import java.util.UUID
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var linksChannel: MethodChannel? = null
    private var videoThumbnails: VideoThumbnailChannel? = null
    private var splashChannel: MethodChannel? = null
    private var splashOverlay: FrameLayout? = null
    private var skipButton: TextView? = null
    private var pendingSkip = false
    private var pendingAttachmentResult: MethodChannel.Result? = null
    private val attachmentRequestCode = 9042

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showSplashHtml()
    }

    private fun showSplashHtml() {
        val downloaded = File(filesDir, "splash/active.html")
        val settingsFile = File(filesDir, "splash/settings.json")
        var html: String? = null
        var allowSkip = true
        if (settingsFile.exists()) {
            try {
                val settings = JSONObject(settingsFile.readText())
                if (!settings.optBoolean("enabled", true)) return
                allowSkip = settings.optBoolean("allow_skip", true)
                if (settings.optString("type") == "html" && downloaded.exists() && downloaded.length() > 0) {
                    html = downloaded.readText()
                }
            } catch (_: Exception) {
            }
        }
        if (html == null) {
            try {
                html = assets.open("splash/default.html").bufferedReader().use { it.readText() }
            } catch (_: Exception) {
                return
            }
        }
        val page = html ?: return
        val overlay = FrameLayout(this)
        val webView = WebView(this)
        overlay.setBackgroundColor(Color.parseColor("#0E1014"))
        webView.setBackgroundColor(Color.parseColor("#0E1014"))
        webView.settings.javaScriptEnabled = true
        webView.settings.allowFileAccess = true
        webView.loadDataWithBaseURL(
            "file:///android_asset/splash/",
            page,
            "text/html",
            "utf-8",
            null,
        )
        overlay.addView(
            webView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        if (allowSkip) {
            val density = resources.displayMetrics.density
            fun dp(value: Int) = (value * density).toInt()
            val skip = TextView(this)
            skip.text = "SKIP"
            skip.setTextColor(Color.WHITE)
            skip.setTypeface(skip.typeface, Typeface.BOLD)
            skip.textSize = 13f
            skip.letterSpacing = 0.16f
            skip.gravity = Gravity.CENTER
            skip.setPadding(dp(28), dp(12), dp(28), dp(12))
            skip.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(0xE616181D.toInt())
                setStroke(dp(1), 0x66FFFFFF)
            }
            skip.elevation = dp(8).toFloat()
            skip.setOnClickListener { requestSkip() }
            skipButton = skip
            val params = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            )
            params.bottomMargin = dp(36)
            overlay.addView(skip, params)
        }
        addContentView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        splashOverlay = overlay
        overlay.bringToFront()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        splashOverlay?.bringToFront()
    }

    private fun requestSkip() {
        val channel = splashChannel
        if (channel == null) {
            pendingSkip = true
            return
        }
        channel.invokeMethod("skip", null)
    }

    private fun removeSkipButton() {
        val button = skipButton ?: return
        skipButton = null
        (button.parent as? ViewGroup)?.removeView(button)
    }

    private fun hideCachedHtmlSplash() {
        val overlay = splashOverlay ?: return
        splashOverlay = null
        (overlay.parent as? ViewGroup)?.removeView(overlay)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != attachmentRequestCode) return
        val result = pendingAttachmentResult
        pendingAttachmentResult = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri = data.data!!
            var name = "attachment"
            var size = 0L
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: name
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
                }
            }
            if (size > 15L * 1024L * 1024L) {
                result.error("file_too_large", "Choose a file smaller than 15 MB", null)
                return
            }
            val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val directory = File(cacheDir, "chat_attachments").apply { mkdirs() }
            val target = File(directory, "${UUID.randomUUID()}-$safeName")
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) throw IllegalStateException("Could not read this file")
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.length() > 15L * 1024L * 1024L) {
                target.delete()
                result.error("file_too_large", "Choose a file smaller than 15 MB", null)
                return
            }
            result.success(mapOf(
                "path" to target.absolutePath,
                "name" to name,
                "type" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                "size" to target.length()
            ))
        } catch (error: Exception) {
            result.error("pick_failed", error.message ?: "Could not read this file", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { linksChannel?.invokeMethod("incomingLink", it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoThumbnails = VideoThumbnailChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        linksChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/app_links")
        splashChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/splash")
        splashChannel?.setMethodCallHandler { call, result ->
            if (call.method == "hide") {
                hideCachedHtmlSplash()
                result.success(null)
            } else if (call.method == "setAllowSkip") {
                if (call.argument<Boolean>("allow") == false) removeSkipButton()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        if (pendingSkip) {
            pendingSkip = false
            splashChannel?.invokeMethod("skip", null)
        }
        linksChannel?.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(intent.dataString)
                    return@setMethodCallHandler
                }
                if (call.method == "sharePost") {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(share, "Share post"))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("share_failed", "Could not open share options", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "pickChatAttachment") {
                    if (pendingAttachmentResult != null) {
                        result.error("picker_busy", "File picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pendingAttachmentResult = result
                    val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                            "image/jpeg", "image/png", "image/gif", "image/webp", "image/avif",
                            "application/pdf", "text/plain",
                            "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                            "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                            "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation"
                        ))
                    }
                    startActivityForResult(picker, attachmentRequestCode)
                    return@setMethodCallHandler
                }
                if (call.method != "openUrl") {
                    result.notImplemented()
                } else {
                    try {
                        val uri = Uri.parse(call.argument<String>("url") ?: "")
                        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
                            result.error("invalid_url", "Enter a valid website link", null)
                        } else {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(null)
                        }
                    } catch (error: Exception) {
                        result.error("open_failed", "Could not open this link", null)
                    }
                }
            }
    }

    override fun onDestroy() {
        videoThumbnails?.close()
        super.onDestroy()
    }
}
