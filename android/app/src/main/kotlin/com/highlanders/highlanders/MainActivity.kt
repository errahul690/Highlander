package com.highlanders.highlanders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.app.Activity
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebChromeClient
import android.webkit.WebViewClient
import android.webkit.JavascriptInterface
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.ImageView
import java.io.File
import java.util.UUID
import org.json.JSONObject
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability

class MainActivity : FlutterActivity() {
    private var launchStadium: FrameLayout? = null
    private var launchFrameDisplayed = false
    private var launchImageFading = false
    private var launchImageFadeDurationMs = 0L
    private val launchImageReleaseRequests = mutableListOf<MethodChannel.Result>()

    private fun applyLaunchViewport() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        if (launchStadium != null) applyLaunchViewport()
    }

    // Texture mode lets Android draw the native first still while Dart starts.
    // Surface mode delays the whole Activity's first draw until Flutter paints.
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        if (launchStadium == null || launchFrameDisplayed) return
        launchFrameDisplayed = true
        // API 31+ launches with a translucent theme to suppress the system's
        // separate starting window. Flutter already applied the opaque NormalTheme.
        // Once a real frame exists, also restore opaque Activity/task semantics.
        if (android.os.Build.VERSION.SDK_INT >= 31) {
            // Already-opaque instances can return false, so this is idempotent.
            setTranslucent(false)
        }
        releaseLaunchImageIfReady()
    }

    private fun releaseLaunchImageIfReady() {
        val cover = launchStadium ?: return
        if (!launchFrameDisplayed || launchImageFading || launchImageReleaseRequests.isEmpty()) return
        launchImageFading = true
        // The native and Flutter copies share a centered cover viewport. Blend
        // their decoder/color differences while Flutter holds the same first still.
        cover.postOnAnimation {
            if (launchStadium !== cover) return@postOnAnimation
            cover.animate()
                .alpha(0f)
                .setDuration(launchImageFadeDurationMs)
                .setInterpolator(android.view.animation.AccelerateDecelerateInterpolator())
                .withEndAction { finishLaunchImageRelease() }
                .start()
        }
    }

    private fun finishLaunchImageRelease() {
        launchStadium?.let { cover ->
            (cover.parent as? ViewGroup)?.removeView(cover)
        }
        launchStadium = null
        val requests = launchImageReleaseRequests.toList()
        launchImageReleaseRequests.clear()
        requests.forEach { it.success(null) }
    }
    private var linksChannel: MethodChannel? = null
    private var videoThumbnails: VideoThumbnailChannel? = null
    private var splashChannel: MethodChannel? = null
    private var splashOverlay: FrameLayout? = null
    private var splashReadyAt: Long? = null
    private var splashFinished = false
    private var splashMinimumDurationMs = 0L
    private val splashReadyRequests = mutableListOf<MethodChannel.Result>()
    private var skipButton: TextView? = null
    private var pendingSkip = false
    private var pendingAttachmentResult: MethodChannel.Result? = null
    private val attachmentRequestCode = 9042

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLaunchViewport()
        val firstStill = ImageView(this).apply {
            setBackgroundColor(Color.rgb(22, 11, 9))
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageResource(R.drawable.stadium_launch)
            importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val cover = FrameLayout(this)
        cover.addView(firstStill, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        // Match AndroidNavigationBackground without shrinking the media viewport.
        val navigationBackground = android.view.View(this).apply {
            setBackgroundColor(Color.BLACK)
        }
        cover.addView(navigationBackground, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, Gravity.BOTTOM,
        ))
        ViewCompat.setOnApplyWindowInsetsListener(cover) { _, insets ->
            val height = insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom
            navigationBackground.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, height, Gravity.BOTTOM,
            )
            insets
        }
        launchStadium = cover
        addContentView(cover, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        ViewCompat.requestApplyInsets(cover)
        if (android.os.Build.VERSION.SDK_INT >= 31) {
            // Remove an OEM system-splash fallback as soon as the native still draws.
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
        // Flutter continues the same stadium after its first decoded still paints.
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
        splashMinimumDurationMs = 6000L
        val overlay = FrameLayout(this)
        val webView = WebView(this)
        overlay.setBackgroundColor(Color.rgb(14, 16, 20))
        webView.setBackgroundColor(Color.rgb(14, 16, 20))
        webView.settings.javaScriptEnabled = true
        webView.settings.mediaPlaybackRequiresUserGesture = false
        webView.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(message: String) {
                runOnUiThread {
                    if (splashOverlay !== overlay) return@runOnUiThread
                    if (message == "playing") {
                        splashChannel?.invokeMethod("playing", null)
                    }
                    if (message == "ended") {
                        android.util.Log.i("SplashPlayback", "video_ended")
                        splashFinished = true
                        splashChannel?.invokeMethod("finished", null)
                    }
                }
            }
        }, "SplashPlayback")
        webView.webChromeClient = object : WebChromeClient() {
            // Never show WebView's default play poster before the first frame.
            override fun getDefaultVideoPoster(): Bitmap =
                Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        }
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

    private fun hideCachedHtmlSplash(deferDisposal: Boolean = false) {
        val overlay = splashOverlay
        splashOverlay = null
        splashReadyAt = null
        splashFinished = false
        splashMinimumDurationMs = 0L
        pendingSkip = false
        removeSkipButton()
        splashReadyRequests.forEach { it.success(null) }
        splashReadyRequests.clear()
        if (overlay != null) {
            (overlay.parent as? ViewGroup)?.removeView(overlay)
            val dispose = Runnable {
                for (index in 0 until overlay.childCount) {
                    (overlay.getChildAt(index) as? WebView)?.apply {
                        stopLoading()
                        destroy()
                    }
                }
                overlay.removeAllViews()
            }
            // WebView.destroy can block the Android UI thread. Let the popup's
            // 450 ms entrance finish before disposing the detached view.
            if (deferDisposal) Handler(Looper.getMainLooper()).postDelayed(dispose, 650L)
            else dispose.run()
        }
    }

    private fun splashPlaybackState(): Map<String, Any> = mapOf(
        "active" to (splashOverlay != null),
        "elapsedMs" to (splashReadyAt?.let { SystemClock.uptimeMillis() - it } ?: 0L),
        "minimumDurationMs" to splashMinimumDurationMs,
        "finished" to splashFinished,
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "neufc/store_update").setMethodCallHandler { call, result ->
            if (call.method != "check") {
                result.notImplemented()
            } else {
                AppUpdateManagerFactory.create(this).appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(mapOf(
                            "available" to (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
                            "version" to info.availableVersionCode().toString(),
                            "url" to "https://play.google.com/store/apps/details?id=$packageName"
                        ))
                    }
                    .addOnFailureListener { error ->
                        result.error("store_update_failed", error.message, null)
                    }
            }
        }
        videoThumbnails = VideoThumbnailChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        linksChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/app_links")
        splashChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highlanders/splash")
        splashChannel?.setMethodCallHandler { call, result ->
            if (call.method == "releaseLaunchImage") {
                if (launchStadium == null) {
                    result.success(null)
                } else {
                    if (!launchImageFading) {
                        launchImageFadeDurationMs = (call.argument<Number>("durationMs")?.toLong() ?: 0L)
                            .coerceAtLeast(0L)
                    }
                    launchImageReleaseRequests.add(result)
                    releaseLaunchImageIfReady()
                }
            } else if (call.method == "prepare") {
                val selected = (call.arguments as? Map<*, *>)?.let { JSONObject(it) }
                // Reuse the launch playback. Dart must not restart its video.
                if (splashOverlay == null) showSplashHtml(selected)
                else android.util.Log.i("SplashPlayback", "reused_native_launch")
                result.success(null)
            } else if (call.method == "waitUntilReady") {
                if (splashOverlay == null) result.success(null)
                else if (splashReadyAt != null) result.success(splashPlaybackState())
                else splashReadyRequests.add(result)
            } else if (call.method == "hide") {
                hideCachedHtmlSplash(deferDisposal = true)
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
                if (call.method == "getShareTargets") {
                    try {
                        result.success(PostShareTargets(this).list())
                    } catch (error: Exception) {
                        result.error("share_failed", "Could not load share apps", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "sharePost") {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        PostShareTargets(this).share(text, call.argument<String>("target"))
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
        launchStadium?.animate()?.cancel()
        finishLaunchImageRelease()
        videoThumbnails?.close()
        super.onDestroy()
    }
}
