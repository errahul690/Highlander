package com.highlanders.highlanders

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Generate bounded, cached posters without starting an audio/video player. */
class VideoThumbnailChannel(context: Context, messenger: BinaryMessenger) {
    private val cache = File(context.cacheDir, "video-posters").apply { mkdirs() }
    private val workers = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "highlanders/video_thumbnail")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "extract") {
                result.notImplemented()
            } else {
                val source = call.argument<String>("source") ?: ""
                val local = call.argument<Boolean>("local") == true
                workers.execute {
                    val path = try { extract(source, local) } catch (_: Exception) { null }
                    main.post { result.success(path) }
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        workers.shutdownNow()
    }

    private fun extract(source: String, local: Boolean): String? {
        if (source.isBlank()) return null
        val inputFile = if (local) File(source) else null
        val identity = source + if (local) ":${inputFile!!.length()}:${inputFile.lastModified()}" else ""
        val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val poster = File(cache, "$digest.jpg")
        if (poster.length() > 0) {
            poster.setLastModified(System.currentTimeMillis())
            return poster.absolutePath
        }
        val temporary = if (local) null else File.createTempFile("video-", ".tmp", cache)
        val retriever = MediaMetadataRetriever()
        var frame: Bitmap? = null
        try {
            val video = inputFile ?: temporary!!.also { download(source, it) }
            retriever.setDataSource(video.absolutePath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            val timestamp = minOf(1_000L, duration / 3) * 1_000L
            frame = if (Build.VERSION.SDK_INT >= 27) {
                val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull()?.coerceAtLeast(1) ?: 640
                val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull()?.coerceAtLeast(1) ?: 360
                val ratio = minOf(1.0, 640.0 / maxOf(width, height))
                retriever.getScaledFrameAtTime(timestamp, MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    (width * ratio).toInt().coerceAtLeast(1), (height * ratio).toInt().coerceAtLeast(1))
            } else {
                retriever.getFrameAtTime(timestamp, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            }
            if (frame == null) return null
            val output = File.createTempFile("poster-", ".tmp", cache)
            try {
                output.outputStream().use { frame!!.compress(Bitmap.CompressFormat.JPEG, 82, it) }
                if (!output.renameTo(poster)) output.copyTo(poster, overwrite = true)
            } finally { output.delete() }
            // A small disk cache keeps scrolling from downloading the same video again.
            cache.listFiles()?.filter { it.extension == "jpg" }
                ?.sortedByDescending { it.lastModified() }?.drop(60)?.forEach { it.delete() }
            return poster.absolutePath
        } finally {
            frame?.recycle()
            try { retriever.release() } catch (_: Exception) { }
            temporary?.delete()
        }
    }

    private fun download(source: String, output: File) {
        var uri = URI(source)
        val deadline = System.currentTimeMillis() + 25_000L
        repeat(6) {
            check(!Thread.currentThread().isInterrupted && System.currentTimeMillis() < deadline)
            require(uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank())
            val connection = uri.toURL().openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 8_000
                connection.readTimeout = 8_000
                connection.instanceFollowRedirects = false
                val status = connection.responseCode
                if (status in listOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location") ?: error("Missing redirect")
                    uri = uri.resolve(location)
                } else {
                    require(status == 200)
                    val maximum = 20L * 1024 * 1024
                    require(connection.contentLengthLong <= maximum)
                    connection.inputStream.use { input ->
                        output.outputStream().use { target ->
                            val buffer = ByteArray(32 * 1024)
                            var total = 0L
                            while (true) {
                                check(!Thread.currentThread().isInterrupted && System.currentTimeMillis() < deadline)
                                val count = input.read(buffer)
                                if (count < 0) break
                                total += count
                                require(total <= maximum)
                                target.write(buffer, 0, count)
                            }
                        }
                    }
                    return
                }
            } finally { connection.disconnect() }
        }
        error("Too many redirects")
    }
}
