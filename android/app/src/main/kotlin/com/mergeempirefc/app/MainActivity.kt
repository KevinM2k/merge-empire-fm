package com.mergeempirefc.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "com.mergeempirefc.app/legacy_save"

// Matches @capacitor/preferences: SharedPreferences file "CapacitorStorage",
// keys stored unprefixed.
private const val CAPACITOR_STORE = "CapacitorStorage"
private const val LEGACY_SAVE_KEY = "mergeEmpireFC_save_native"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readLegacySave" -> result.success(readLegacySave())
                    "writeLegacySaveForTest" -> {
                        writeLegacySave(call.argument<String>("value"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readLegacySave(): String? =
        getSharedPreferences(CAPACITOR_STORE, Context.MODE_PRIVATE)
            .getString(LEGACY_SAVE_KEY, null)

    // Test-only seam so the integration test can plant a save the way the
    // Capacitor build would have written it.
    private fun writeLegacySave(value: String?) {
        getSharedPreferences(CAPACITOR_STORE, Context.MODE_PRIVATE)
            .edit()
            .apply { if (value == null) remove(LEGACY_SAVE_KEY) else putString(LEGACY_SAVE_KEY, value) }
            .apply()
    }
}
