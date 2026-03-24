package com.booxchat.app

import android.app.Activity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.booxchat.app/eink"

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
}
