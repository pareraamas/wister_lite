package com.developerparera.wister_lite

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Tile Quick Settings "Catat transaksi": pengganti widget lock screen yang
 * tidak didukung Android di HP. Ketuk membuka form pengeluaran; di lock
 * screen sistem meminta buka kunci dulu. Subjudul menampilkan keluar hari ini
 * dari data widget Ringkasan.
 */
class CatatTileService : TileService() {

  override fun onStartListening() {
    super.onStartListening()
    val tile = qsTile ?: return
    tile.state = Tile.STATE_INACTIVE
    if (Build.VERSION.SDK_INT >= 29) {
      val data = HomeWidgetPlugin.getData(this)
      val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
      val amount = if (data.getString("widget_date", null) == today) data.getString("widget_today_expense", null) else null
      tile.subtitle = "Hari ini ${amount ?: "Rp 0"}"
    }
    tile.updateTile()
  }

  override fun onClick() {
    super.onClick()
    if (isLocked) unlockAndRun { openForm() } else openForm()
  }

  @SuppressLint("StartActivityAndCollapseDeprecated")
  private fun openForm() {
    val uri = Uri.parse("wisterlite://create?type=expense")
    if (Build.VERSION.SDK_INT >= 34) {
      startActivityAndCollapse(HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java, uri))
    } else {
      val intent = Intent(this, MainActivity::class.java).apply {
        data = uri
        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      @Suppress("DEPRECATION")
      startActivityAndCollapse(intent)
    }
  }
}
