package com.highlanders.highlanders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import androidx.core.content.FileProvider
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.app.Activity
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
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
    private var splashReadyAt: Long? = null
    private var splashMinimumDurationMs = 0L
    private val splashReadyRequests = mutableListOf<MethodChannel.Result>()
    private var skipButton: TextView? = null
    private var pendingSkip = false
    private var pendingAttachmentResult: MethodChannel.Result? = null
    private val attachmentRequestCode = 9042

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Dart loads the bundled splash before starting the animation.
    }

    private fun showSplashHtml(selected: JSONObject?) {
        // Hot restart reuses this Activity; each prepare needs fresh playback state.
        hideCachedHtmlSplash()
        var html: String? = null
        var allowSkip = false
        if (selected != null) {
            try {
                val settings = selected
                if (!settings.optBoolean("enabled", true)) return
                if (settings.optString("type") != "html") return
                allowSkip = settings.optBoolean("allow_skip", false)
                html = settings.optString("html_content").takeIf { it.isNotBlank() }
                val localHtml = settings.optString("_local_html_path")
                if (html == null && localHtml.isNotBlank() && File(localHtml).exists()) {
                    html = File(localHtml).readText()
                }
                if (html == null) return
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
        splashMinimumDurationMs = 4000L
        val overlay = FrameLayout(this)
        val webView = WebView(this)
        overlay.setBackgroundColor(Color.parseColor("#0E1014"))
        webView.setBackgroundColor(Color.parseColor("#0E1014"))
        webView.settings.javaScriptEnabled = true
        webView.settings.allowFileAccess = true
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                if (splashOverlay !== overlay) return
                if (splashReadyAt == null) splashReadyAt = SystemClock.uptimeMillis()
                val requests = splashReadyRequests.toList()
                splashReadyRequests.clear()
                requests.forEach { it.success(splashPlaybackState()) }
            }
        }
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
        if (allowSkip) addSkipButton(overlay)
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

    private fun addSkipButton(overlay: FrameLayout) {
        if (skipButton != null) return
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

    private fun removeSkipButton() {
        val button = skipButton ?: return
        skipButton = null
        (button.parent as? ViewGroup)?.removeView(button)
    }

    private fun hideCachedHtmlSplash() {
        val overlay = splashOverlay
        splashOverlay = null
        splashReadyAt = null
        splashMinimumDurationMs = 0L
        pendingSkip = false
        removeSkipButton()
        splashReadyRequests.forEach { it.success(null) }
        splashReadyRequests.clear()
        if (overlay != null) {
            (overlay.parent as? ViewGroup)?.removeView(overlay)
            for (index in 0 until overlay.childCount) {
                (overlay.getChildAt(index) as? WebView)?.apply {
                    stopLoading()
                    destroy()
                }
            }
            overlay.removeAllViews()
        }
    }

    private fun splashPlaybackState(): Map<String, Any> = mapOf(
        "active" to (splashOverlay != null),
        "elapsedMs" to (splashReadyAt?.let { SystemClock.uptimeMillis() - it } ?: 0L),
        "minimumDurationMs" to splashMinimumDurationMs,
    )

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
        PostLinkStore(this).capture(intent.dataString)
        intent.dataString?.let { linksChannel?.invokeMethod("incomingLink", it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoThumbnails = VideoThumbnailChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        linksChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/app_links")
        splashChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/splash")
        splashChannel?.setMethodCallHandler { call, result ->
            if (call.method == "prepare") {
                val selected = (call.arguments as? Map<*, *>)?.let { JSONObject(it) }
                showSplashHtml(selected)
                result.success(null)
            } else if (call.method == "waitUntilReady") {
                if (splashOverlay == null) result.success(null)
                else if (splashReadyAt != null) result.success(splashPlaybackState())
                else splashReadyRequests.add(result)
            } else if (call.method == "hide") {
                hideCachedHtmlSplash()
                result.success(null)
            } else if (call.method == "setAllowSkip") {
                val allow = call.argument<Boolean>("allow") == true
                val overlay = splashOverlay
                if (allow && overlay != null) addSkipButton(overlay) else removeSkipButton()
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
                    PostLinkStore(this).initialLink(intent.dataString, result)
                    return@setMethodCallHandler
                }
                if (call.method == "consumePostLink") {
                    PostLinkStore(this).consume(call.argument<String>("postId"))
                    result.success(null)
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
                            "video/mp4", "video/quicktime", "video/webm",
                            "application/pdf", "text/plain",
                            "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                            "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                            "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation"
                        ))
                    }
                    startActivityForResult(picker, attachmentRequestCode)
                    return@setMethodCallHandler
                }
                if (call.method == "openChatFile") {
                    try {
                        val file = File(call.argument<String>("path") ?: "").canonicalFile
                        val root = File(filesDir, "chat-files/open").canonicalFile
                        require(file.isFile && file.path.startsWith(root.path + File.separator)) { "Invalid local file" }
                        val uri = FileProvider.getUriForFile(this, "$packageName.chat_files", file)
                        val mime = call.argument<String>("mime")?.takeIf { it.contains("/") } ?: "application/octet-stream"
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mime)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("open_failed", "Could not open this downloaded file", null)
                    }
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
