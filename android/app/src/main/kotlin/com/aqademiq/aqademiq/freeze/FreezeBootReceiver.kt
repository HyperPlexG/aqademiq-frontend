package com.aqademiq.aqademiq.freeze

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings [FreezeMonitorService] back after a reboot or an app update
 * (APP_FREEZE.md §6). Both kill the process, and a frost is meant to keep
 * running whether or not the student ever opens Aqademiq again.
 *
 * These two broadcasts are also two of the few moments Android 12+ lets an
 * app start a foreground service from the background, and `specialUse` is
 * not among the types Android 15 bars from BOOT_COMPLETED. The service is
 * started only if the stored policy still needs it.
 */
class FreezeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> FreezeMonitorService.sync(context, refresh = false)
        }
    }
}
