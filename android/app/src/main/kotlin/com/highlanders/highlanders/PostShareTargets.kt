package com.highlanders.highlanders

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream

/** Only activities that accept our text share; never enumerate all installed apps. */
class PostShareTargets(private val activity: Activity) {
    private fun intent(text: String = "") = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }

    @Suppress("DEPRECATION")
    private fun targets() = activity.packageManager
        .queryIntentActivities(intent(), PackageManager.MATCH_DEFAULT_ONLY)
        .filter { it.activityInfo.exported && it.activityInfo.packageName != activity.packageName }
        .distinctBy { it.activityInfo.packageName }
        .sortedWith(compareBy({
            when (it.activityInfo.packageName) {
                "com.whatsapp" -> 0
                "com.whatsapp.w4b" -> 1
                "org.telegram.messenger" -> 2
                "com.facebook.orca" -> 3
                "com.google.android.gm" -> 4
                else -> 5
            }
        }, { it.loadLabel(activity.packageManager).toString().lowercase() }))

    fun list(): List<Map<String, Any>> = targets().take(5).map { target ->
        val drawable = target.loadIcon(activity.packageManager)
        val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, 96, 96)
        drawable.draw(Canvas(bitmap))
        val bytes = ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
        bitmap.recycle()
        mapOf("id" to ComponentName(target.activityInfo.packageName, target.activityInfo.name).flattenToString(),
            "label" to target.loadLabel(activity.packageManager).toString(), "icon" to bytes)
    }

    fun share(text: String, targetId: String?) {
        val share = intent(text)
        if (targetId.isNullOrEmpty()) {
            activity.startActivity(Intent.createChooser(share, "Share post"))
        } else {
            val target = targets().firstOrNull {
                ComponentName(it.activityInfo.packageName, it.activityInfo.name).flattenToString() == targetId
            } ?: throw IllegalArgumentException("This app is no longer available")
            share.component = ComponentName(target.activityInfo.packageName, target.activityInfo.name)
            activity.startActivity(share)
        }
    }
}
