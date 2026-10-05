package com.developerparera.wister_lite

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget "Ringkasan": 3×1 menampilkan keluar hari ini + tombol catat,
 * diperbesar (≥ 4×2) ikut menampilkan saldo dan masuk/keluar bulan ini.
 *
 * Nominal sudah diformat oleh Dart (HomeWidgetService). Provider hanya
 * mengecek tanggal: data kemarin/bulan lalu ditampilkan sebagai Rp 0 sampai
 * aplikasi dibuka lagi, karena total harian/bulanan memang mulai dari nol.
 */
class SummaryWidgetProvider : HomeWidgetProvider() {

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
    // Android 12+ memilih layout sendiri dari peta ukuran; versi lama perlu digambar ulang.
    if (Build.VERSION.SDK_INT < 31) {
      appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context)))
    }
  }

  private fun build(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences): RemoteViews {
    val summary = Summary.from(data)
    if (Build.VERSION.SDK_INT >= 31) {
      return RemoteViews(
          mapOf(
              SizeF(180f, 40f) to small(context, summary),
              SizeF(250f, 110f) to large(context, summary),
          )
      )
    }
    val options = manager.getAppWidgetOptions(id)
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    return if (width >= 250 && height >= 110) large(context, summary) else small(context, summary)
  }

  private fun small(context: Context, s: Summary) =
      RemoteViews(context.packageName, R.layout.widget_summary_small).apply {
        setTextViewText(R.id.today_expense, s.todayExpenseShort)
        bindActions(context)
      }

  private fun large(context: Context, s: Summary) =
      RemoteViews(context.packageName, R.layout.widget_summary_large).apply {
        setTextViewText(R.id.month_label, s.monthLabel)
        setTextViewText(R.id.balance, s.balance)
        setTextViewText(R.id.month_income, s.monthIncome)
        setTextViewText(R.id.month_expense, s.monthExpense)
        setTextViewText(R.id.today_expense, s.todayExpense)
        bindActions(context)
      }

  private fun RemoteViews.bindActions(context: Context) {
    setOnClickPendingIntent(R.id.root, launch(context, "wisterlite://home"))
    setOnClickPendingIntent(R.id.add_expense, launch(context, "wisterlite://create?type=expense"))
    setOnClickPendingIntent(R.id.add_income, launch(context, "wisterlite://create?type=income"))
  }

  private fun launch(context: Context, uri: String) = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

  private data class Summary(
      val monthLabel: String,
      val balance: String,
      val monthIncome: String,
      val monthExpense: String,
      val todayExpense: String,
      val todayExpenseShort: String,
  ) {
    companion object {
      private const val ZERO = "Rp 0"
      private val locale = Locale("id", "ID")

      fun from(data: SharedPreferences): Summary {
        val now = Date()
        val sameDay = data.getString("widget_date", null) == SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val sameMonth = data.getString("widget_month", null) == SimpleDateFormat("yyyy-MM", Locale.US).format(now)
        return Summary(
            monthLabel = "Bulan " + SimpleDateFormat("MMMM", locale).format(now),
            balance = data.getString("widget_balance", null) ?: ZERO,
            monthIncome = if (sameMonth) data.getString("widget_month_income", null) ?: ZERO else ZERO,
            monthExpense = if (sameMonth) data.getString("widget_month_expense", null) ?: ZERO else ZERO,
            todayExpense = if (sameDay) data.getString("widget_today_expense", null) ?: ZERO else ZERO,
            todayExpenseShort = if (sameDay) data.getString("widget_today_expense_short", null) ?: ZERO else ZERO,
        )
      }
    }
  }
}
