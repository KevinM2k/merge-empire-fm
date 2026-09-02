package com.mergeempirefc.app

import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "com.mergeempirefc.app/legacy_save"

// Matches @capacitor/preferences: SharedPreferences file "CapacitorStorage",
// keys stored unprefixed.
private const val CAPACITOR_STORE = "CapacitorStorage"
private const val LEGACY_SAVE_KEY = "mergeEmpireFC_save_native"

class MainActivity : FlutterActivity() {
    /**
     * **ASK FOR THE PANEL'S REAL REFRESH RATE.**
     *
     * Measured on a 120Hz device: the display sat in its 60Hz mode for the
     * whole of this app's life — `dumpsys display` reported `mode 10,
     * renderFrameRate 60.0` on a screen whose `defaultMode` is the 120Hz one —
     * while every other app on the phone ran at 120. That is the whole of the
     * "the bounce feels choppy" report: a spring animation at half the rate the
     * system UI beside it is running at reads as stutter, and no amount of
     * Dart-side work can fix it because the frames are not being asked for.
     *
     * Flutter's Android embedding does not request a mode, so the window asks:
     * the highest-refresh mode at the CURRENT resolution, which on a folding
     * phone is not the same list on both screens.
     *
     * **On the device this was found on it changes nothing**, and that is worth
     * writing down rather than deleting the code over: that phone hands the app
     * a mode list of 60Hz and below and never offers the 120 its panel is
     * capable of, at `onCreate` and again once the window has focus. The
     * decision is the system's, and no `preferredDisplayModeId` can override a
     * mode that was never offered. The request stands because it is correct and
     * costs nothing, and because a device that DOES offer 120 gets it.
     *
     * Guarded by the platform check because `preferredDisplayModeId` is M+, and
     * done in `onCreate` so the first frame is already at the right rate.
     */
    private fun preferHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return
        val current = display.mode ?: return
        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        if (best.modeId == current.modeId) return
        // A fresh copy, applied back: `getAttributes` hands out the live object
        // and mutating it in place does not always trigger the relayout that
        // actually asks for the mode.
        val params = window.attributes
        params.preferredDisplayModeId = best.modeId
        window.attributes = params
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // **AND AGAIN ONCE THE WINDOW IS ATTACHED.** The mode list a display
        // hands back before the window has focus can be a restricted one.
        if (hasFocus) preferHighRefreshRate()
    }

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
