package id.tafseer.app

import android.app.Activity
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "id.tafseer.app/ringtone_picker"
    private var pendingResult: MethodChannel.Result? = null
    private var currentRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    pendingResult = result
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Tone")
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                    }
                    startActivityForResult(intent, 999)
                }
                "playRingtone" -> {
                    val uriString = call.argument<String>("uri")
                    try {
                        currentRingtone?.stop()
                        val uri = if (uriString.isNullOrEmpty()) {
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        } else {
                            Uri.parse(uriString)
                        }
                        currentRingtone = RingtoneManager.getRingtone(applicationContext, uri)
                        currentRingtone?.play()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopRingtone" -> {
                    try {
                        currentRingtone?.stop()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isAutoStartSupported" -> {
                    val manufacturer = android.os.Build.MANUFACTURER.lowercase()
                    val supported = listOf("xiaomi", "oppo", "vivo", "huawei", "oneplus").contains(manufacturer)
                    result.success(supported)
                }
                "openAutoStartSettings" -> {
                    try {
                        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
                        val intent = Intent()
                        when (manufacturer) {
                            "xiaomi" -> {
                                intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                            }
                            "oppo" -> {
                                intent.component = ComponentName("com.oppo.safe", "com.oppo.safe.permission.floatwindow.FloatWindowListActivity")
                            }
                            "vivo" -> {
                                intent.component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
                            }
                            "huawei" -> {
                                intent.component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                            }
                            else -> {
                                intent.action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                intent.data = Uri.parse("package:$packageName")
                            }
                        }
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("ERROR", ex.message, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 999) {
            if (resultCode == Activity.RESULT_OK) {
                val uri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                }
                if (uri != null) {
                    val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                    val title = ringtone?.getTitle(applicationContext) ?: "Custom Tone"
                    pendingResult?.success(mapOf("uri" to uri.toString(), "title" to title))
                } else {
                    pendingResult?.success(mapOf("uri" to "", "title" to "Silent"))
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}
