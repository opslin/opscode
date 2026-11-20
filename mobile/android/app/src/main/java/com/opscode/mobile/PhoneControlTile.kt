package com.opscode.mobile

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class PhoneControlTile : TileService() {
    override fun onTileAdded() {
        getSharedPreferences("phone-setup", MODE_PRIVATE).edit().putBoolean("tile", true).apply()
    }

    override fun onTileRemoved() {
        getSharedPreferences("phone-setup", MODE_PRIVATE).edit().putBoolean("tile", false).apply()
    }

    override fun onStartListening() {
        qsTile?.apply {
            state = if (PhoneAccessibility.active != null) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            updateTile()
        }
    }

    @Suppress("DEPRECATION")
    override fun onClick() {
        // A command only becomes eligible after the user opens the tile on an unlocked phone.
        if (isLocked) return
        val intent = Intent(this, ScreenCommandActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 87, intent, PendingIntent.FLAG_IMMUTABLE))
        } else startActivityAndCollapse(intent)
    }
}
