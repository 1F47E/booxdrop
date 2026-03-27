package com.booxchat.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.booxchat.app/eink"
    private val OTA_CHANNEL = "dev.kass.ota/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Apply REGAL mode immediately — best for text/reading on e-ink
        setRegalMode()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestFullRefresh" -> {
                        requestFullRefresh()
                        result.success(null)
                    }
                    "setRegalMode" -> {
                        setRegalMode()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        result.success(canInstallPackages())
                    }
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            installApk(path)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARG", "path is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Sets the app's e-ink refresh mode to REGAL — optimised for text rendering.
     * Uses reflection so the APK runs on all Android devices, not just BOOX.
     * On non-BOOX devices the class is simply not found and the call is skipped.
     */
    private fun setRegalMode() {
        try {
            val cls = Class.forName("com.onyx.android.sdk.api.device.epd.EpdController")
            val modeClass = Class.forName(
                "com.onyx.android.sdk.api.device.epd.EpdController\$UpdateMode"
            )
            @Suppress("UNCHECKED_CAST")
            val regalMode = (modeClass.enumConstants as Array<Enum<*>>)
                .firstOrNull { it.name == "REGAL" }
                ?: return
            cls.getMethod("setApplicationUpdateMode", Activity::class.java, modeClass)
                .invoke(null, this, regalMode)
        } catch (_: Exception) {
            // Not a BOOX device — silent fallback
        }
    }

    /**
     * Triggers a full e-ink screen refresh to clear ghosting residue.
     * Should be called after major content changes (new message received, etc.).
     */
    private fun requestFullRefresh() {
        try {
            val cls = Class.forName("com.onyx.android.sdk.api.device.epd.EpdController")
            cls.getMethod("updateScreenNow", Activity::class.java)
                .invoke(null, this)
        } catch (_: Exception) {
            // Not a BOOX device — silent fallback
        }
    }

    // -- OTA install helpers --------------------------------------------------

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
