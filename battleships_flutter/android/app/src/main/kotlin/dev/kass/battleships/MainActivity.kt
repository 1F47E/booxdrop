package dev.kass.battleships

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val OTA_CHANNEL = "dev.kass.ota/install"
    private val BT_HOST_CHANNEL = "battleships/bt_host"

    private var serverSocket: BluetoothServerSocket? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // OTA install channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> result.success(canInstallPackages())
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

        // Bluetooth host channel — server socket for accepting guest connections
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BT_HOST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listen" -> {
                        val uuid = call.argument<String>("uuid")
                            ?: "00001101-0000-1000-8000-00805F9B34FB"
                        Thread {
                            try {
                                val adapter = BluetoothAdapter.getDefaultAdapter()
                                if (adapter == null) {
                                    runOnUiThread { result.error("BT_UNAVAILABLE", "No Bluetooth adapter", null) }
                                    return@Thread
                                }
                                serverSocket = adapter.listenUsingRfcommWithServiceRecord(
                                    "Battleships", UUID.fromString(uuid)
                                )
                                val socket = serverSocket!!.accept()
                                val guestAddress = socket.remoteDevice.address
                                // Close the server socket — we only accept one guest
                                serverSocket?.close()
                                serverSocket = null
                                // Close the accepted socket — Dart will reconnect via toAddress
                                socket.close()
                                runOnUiThread { result.success(guestAddress) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BT_LISTEN_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "disconnect" -> {
                        try {
                            serverSocket?.close()
                            serverSocket = null
                        } catch (_: Exception) {}
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

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
