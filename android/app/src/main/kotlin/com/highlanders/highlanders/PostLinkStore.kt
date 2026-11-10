package com.highlanders.highlanders

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.MethodChannel

/** Keep the destination through installation, login and activity recreation. */
class PostLinkStore(context: Context) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences("shared_post_link", Context.MODE_PRIVATE)

    private fun postId(link: String?): String? {
        if (link == null) return null
        val uri = Uri.parse(link)
        val segments = uri.pathSegments
        val id = when {
            uri.scheme == "highlanders" && uri.host == "post" && segments.size == 1 -> segments[0]
            uri.scheme == "https" && uri.host == "highlanders.app" && segments.size == 2 && segments[0] == "post" -> segments[1]
            else -> null
        }
        return id?.takeIf { it.matches(Regex("[a-fA-F0-9]{24}")) }
    }

    fun capture(link: String?) {
        val id = postId(link) ?: return
        preferences.edit()
            .putString("pending", "highlanders://post/$id")
            .putBoolean("referrer_checked", true)
            .apply()
    }

    fun consume(id: String?) {
        if (id != null && postId(preferences.getString("pending", null)) == id) {
            preferences.edit().remove("pending").apply()
        }
    }

    fun initialLink(direct: String?, result: MethodChannel.Result) {
        if (postId(direct) != null) {
            capture(direct)
            result.success(direct)
            return
        }
        val pending = preferences.getString("pending", null)
        if (pending != null || preferences.getBoolean("referrer_checked", false)) {
            result.success(pending)
            return
        }
        val client = InstallReferrerClient.newBuilder(appContext).build()
        val handler = Handler(Looper.getMainLooper())
        var finished = false
        fun finish() {
            if (finished) return
            finished = true
            try { client.endConnection() } catch (_: Exception) {}
            result.success(preferences.getString("pending", null))
        }
        // A missing Play Store or slow service must never block startup.
        handler.postDelayed({ finish() }, 3000)
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (finished) return
                    try {
                        if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                            // A newer incoming link takes precedence over an old install referrer.
                            if (!preferences.getBoolean("referrer_checked", false)) {
                                val referrer = Uri.parse("https://highlanders.app/?" + client.installReferrer.installReferrer)
                                capture(referrer.getQueryParameter("link"))
                                preferences.edit().putBoolean("referrer_checked", true).apply()
                            }
                        } else if (responseCode == InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED) {
                            preferences.edit().putBoolean("referrer_checked", true).apply()
                        }
                    } catch (_: Exception) {}
                    finish()
                }

                override fun onInstallReferrerServiceDisconnected() { finish() }
            })
        } catch (_: Exception) { finish() }
    }
}
