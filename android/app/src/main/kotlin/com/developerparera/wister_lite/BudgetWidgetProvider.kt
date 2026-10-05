package com.developerparera.wister_lite

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.ColorRes
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Widget "Anggaran": sisa anggaran bulan ini + bar terpakai; diperbesar
 * (≥ 4×3) ikut menampilkan tiga kategori dengan rasio terpakai tertinggi.
 *
 * Rasio (per mil) dihitung Dart (HomeWidgetService). Pace (posisi hari ini di
 * bulan) dihitung di sini agar tetap benar tiap hari tanpa membuka aplikasi;
 * ditampilkan sebagai secondaryProgress di belakang bar terpakai.
 * Ambang warna sama dengan BudgetProgress: ≥ 80% hampir habis, > 100% lewat.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id, widgetData)) }
  }

  override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    if (Build.VERSION.SDK_INT < 31) {
      appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context)))
    }
  }

  private fun build(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences): RemoteViews {
    if (Build.VERSION.SDK_INT >= 31) {
      return RemoteViews(
          mapOf(
              SizeF(180f, 110f) to render(context, data, large = false),
              SizeF(250f, 250f) to render(context, data, large = true),
          )
      )
    }
    val options = manager.getAppWidgetOptions(id)
    val large = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 250 && options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) >= 250
    return render(context, data, large)
  }

  private fun render(context: Context, data: SharedPreferences, large: Boolean): RemoteViews {
    val views = RemoteViews(context.packageName, if (large) R.layout.widget_budget_large else R.layout.widget_budget_small)
    views.setOnClickPendingIntent(R.id.root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("wisterlite://budget")))

    val now = Calendar.getInstance()
    val sameMonth = data.getString("budget_month", null) == SimpleDateFormat("yyyy-MM", Locale.US).format(now.time)
    val count = data.number("budget_count")
    // Anggaran disimpan per bulan: bulan baru belum punya anggaran sampai diatur.
    if (!sameMonth || count == 0) {
      views.setViewVisibility(R.id.content, View.GONE)
      views.setViewVisibility(R.id.empty, View.VISIBLE)
      return views
    }
    views.setViewVisibility(R.id.content, View.VISIBLE)
    views.setViewVisibility(R.id.empty, View.GONE)

    val day = now.get(Calendar.DAY_OF_MONTH)
    val daysInMonth = now.getActualMaximum(Calendar.DAY_OF_MONTH)
    val pace = day * 1000 / daysInMonth
    val ratio = data.number("budget_ratio")
    val over = data.getBoolean("budget_over", false)

    views.setTextViewText(R.id.remaining_label, if (over) "Lewat anggaran" else "Sisa bulan ini")
    views.setColor(context, R.id.remaining_label, "setTextColor", if (over) R.color.widget_danger else R.color.widget_ink_muted)
    views.setTextViewText(R.id.remaining, data.getString("budget_remaining", null) ?: "Rp 0")
    views.setColor(context, R.id.remaining, "setTextColor", if (over) R.color.widget_danger else R.color.widget_ink)
    views.bindBar(context, R.id.total_bar, ratio, pace)
    views.setTextViewText(R.id.status, "${percent(ratio)} terpakai · hari ke-$day dari $daysInMonth")

    // Dompi hanya di momen aman (sama seperti halaman Anggaran).
    val allUnderPace = !over && data.number("budget_max_ratio") <= pace
    views.setViewVisibility(R.id.dompi, if (allUnderPace) View.VISIBLE else View.GONE)

    if (large) {
      val rows = listOf(
          Triple(R.id.cat0, R.id.cat0_label, R.id.cat0_percent) to R.id.cat0_bar,
          Triple(R.id.cat1, R.id.cat1_label, R.id.cat1_percent) to R.id.cat1_bar,
          Triple(R.id.cat2, R.id.cat2_label, R.id.cat2_percent) to R.id.cat2_bar,
      )
      rows.forEachIndexed { i, (ids, bar) ->
        val label = data.getString("budget_cat${i}_label", null)
        if (i >= count || label == null) {
          views.setViewVisibility(ids.first, View.GONE)
          return@forEachIndexed
        }
        val catRatio = data.number("budget_cat${i}_ratio")
        views.setViewVisibility(ids.first, View.VISIBLE)
        views.setTextViewText(ids.second, label)
        views.setTextViewText(ids.third, percent(catRatio))
        views.setColor(context, ids.third, "setTextColor", textColor(catRatio))
        views.bindBar(context, bar, catRatio, pace)
      }
    }
    return views
  }

  private fun RemoteViews.bindBar(context: Context, id: Int, ratio: Int, pace: Int) {
    setProgressBar(id, 1000, ratio.coerceIn(0, 1000), false)
    // secondaryProgress = jatah sampai hari ini; tidak ada setter RemoteViews khusus.
    setInt(id, "setSecondaryProgress", pace)
    if (Build.VERSION.SDK_INT >= 31) setColorStateList(id, "setProgressTintList", barColor(ratio))
  }

  private fun RemoteViews.setColor(context: Context, id: Int, method: String, @ColorRes color: Int) {
    // Android 12+ me-resolve warna di launcher, jadi ikut mode gelap sistem.
    if (Build.VERSION.SDK_INT >= 31) setColorStateList(id, method, color) else setTextColor(id, context.getColor(color))
  }

  private fun percent(ratio: Int) = "${(ratio + 5) / 10}%"

  @ColorRes private fun barColor(ratio: Int) = when {
    ratio > 1000 -> R.color.widget_danger
    ratio >= 800 -> R.color.widget_warning_fill
    else -> R.color.widget_brand
  }

  @ColorRes private fun textColor(ratio: Int) = when {
    ratio > 1000 -> R.color.widget_danger
    ratio >= 800 -> R.color.widget_warning
    else -> R.color.widget_ink_muted
  }

  private fun SharedPreferences.number(key: String) = (all[key] as? Number)?.toInt() ?: 0
}
