package com.aqademiq.aqademiq

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * "Start 5" from the notification shade.
 *
 * The Android half of the same intent the Focus widget's button and iOS's
 * Control Centre carry: five minutes, not twenty-five, and the lowest possible
 * barrier between an idle thumb and a started session.
 *
 * It deliberately opens the app rather than starting the session behind the
 * scenes. Starting one needs the timer, Prism and the backend, none of which a
 * tile can spin up — and a tile that silently claimed to have started a session
 * it had not would be worse than one that takes a second longer.
 */
@RequiresApi(Build.VERSION_CODES.N)
class StartFiveTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            label = "Focus"
            subtitle = "5 min"
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("aqademiq://focus/start5"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ refuses a plain startActivity from a tile; this is the
            // sanctioned route and it also collapses the shade for us.
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }
}
