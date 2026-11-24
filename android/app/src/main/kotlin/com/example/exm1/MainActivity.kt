package com.example.exm1

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.exm1/apk_import"
    private val requestCode = 7102
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAndInspectApk" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "An APK selection is already in progress.", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/vnd.android.package-archive"
                        }
                        try {
                            startActivityForResult(intent, requestCode)
                        } catch (error: Exception) {
                            pendingResult = null
                            result.error("PICKER_UNAVAILABLE", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android, retained for compatibility with the document picker result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            result.success(copyAndInspectApk(data.data!!))
        } catch (error: Exception) {
            result.error("APK_INSPECTION_FAILED", error.message ?: "Could not inspect the selected APK.", null)
        }
    }

    private fun copyAndInspectApk(uri: Uri): Map<String, Any> {
        val originalName = queryDisplayName(uri) ?: "selected.apk"
        val safeName = originalName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            .let { if (it.endsWith(".apk", ignoreCase = true)) it else "$it.apk" }
        val importDirectory = File(filesDir, "imported_apks").apply { mkdirs() }
        val destination = File(importDirectory, "${System.currentTimeMillis()}_$safeName")

        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "The selected file could not be opened." }
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }

        require(destination.length() > 0L) { "The selected APK is empty." }

        @Suppress("DEPRECATION")
        val packageInfo = packageManager.getPackageArchiveInfo(destination.absolutePath, 0)
            ?: throw IllegalArgumentException("This file is not a valid, readable APK.")

        val appInfo = packageInfo.applicationInfo
            ?: throw IllegalArgumentException("The APK does not contain application information.")
        appInfo.sourceDir = destination.absolutePath
        appInfo.publicSourceDir = destination.absolutePath

        val label = packageManager.getApplicationLabel(appInfo).toString()
        val icon = try {
            packageManager.getApplicationIcon(appInfo)
        } catch (_: Exception) {
            null
        }

        val versionCode = if (android.os.Build.VERSION.SDK_INT >= 28) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }

        return mapOf(
            "appName" to label,
            "packageName" to packageInfo.packageName,
            "versionName" to (packageInfo.versionName ?: "نامشخص"),
            "versionCode" to versionCode,
            "fileName" to originalName,
            "filePath" to destination.absolutePath,
            "fileSize" to destination.length(),
            "iconBase64" to (icon?.let { drawableToBase64(it) } ?: "")
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            .use { cursor ->
                if (cursor != null && cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) return cursor.getString(index)
                }
            }
        return uri.lastPathSegment
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val width = drawable.intrinsicWidth.coerceIn(1, 256)
        val height = drawable.intrinsicHeight.coerceIn(1, 256)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, width, height)
        drawable.draw(canvas)
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    }
}
