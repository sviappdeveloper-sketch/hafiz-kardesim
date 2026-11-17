package com.hatimkardesim.hatim_kardesim

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

/** Ana ekran namaz vakti widget'ı: bugünün altı vakti ve sıradaki vakit. */
class PrayerWidgetProvider : HomeWidgetProvider() {

    private val ids = intArrayOf(R.id.pw0, R.id.pw1, R.id.pw2, R.id.pw3, R.id.pw4, R.id.pw5)
    private val nameIds = intArrayOf(R.id.pn0, R.id.pn1, R.id.pn2, R.id.pn3, R.id.pn4, R.id.pn5)
    private val timeIds = intArrayOf(R.id.pt0, R.id.pt1, R.id.pt2, R.id.pt3, R.id.pt4, R.id.pt5)

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val names = (widgetData.getString("pw_names", null) ?: "İmsak|Güneş|Öğle|İkindi|Akşam|Yatsı").split("|")
        val city = widgetData.getString("pw_city", "") ?: ""
        val nextLabel = widgetData.getString("pw_next", null) ?: "Sıradaki"
        val empty = widgetData.getString("pw_empty", null) ?: "İl seçmek için dokunun"
        val enabled = widgetData.getBoolean("pw_enabled", true)
        val now = System.currentTimeMillis()

        var today: LongArray? = null
        var nextAt = 0L
        var nextName = ""
        var nextIdx = -1
        try {
            val days = JSONArray(widgetData.getString("pw_times", "[]") ?: "[]")
            val nowCal = Calendar.getInstance()
            for (d in 0 until days.length()) {
                val arr = days.getJSONArray(d)
                if (arr.length() < 6) continue
                val ts = LongArray(6) { arr.getLong(it) }
                val c = Calendar.getInstance().apply { timeInMillis = ts[0] }
                val isToday = c.get(Calendar.YEAR) == nowCal.get(Calendar.YEAR) &&
                    c.get(Calendar.DAY_OF_YEAR) == nowCal.get(Calendar.DAY_OF_YEAR)
                if (isToday) today = ts
                if (nextAt == 0L) {
                    for (i in 0 until 6) {
                        if (ts[i] > now) {
                            nextAt = ts[i]; nextName = names.getOrElse(i) { "" }
                            if (isToday) nextIdx = i
                            break
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }

        val gold = Color.parseColor("#F2C14A")
        val muted = Color.parseColor("#95B5A2")
        val ivory = Color.parseColor("#FBF3DF")

        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.prayer_widget)
            v.setOnClickPendingIntent(R.id.pw_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            val t = today
            if (!enabled || city.isEmpty() || t == null) {
                v.setViewVisibility(R.id.pw_row, View.GONE)
                v.setViewVisibility(R.id.pw_empty, View.VISIBLE)
                v.setTextViewText(R.id.pw_empty, empty)
                v.setTextViewText(R.id.pw_city, if (enabled) city else "")
                v.setTextViewText(R.id.pw_nexttxt, "")
            } else {
                v.setViewVisibility(R.id.pw_row, View.VISIBLE)
                v.setViewVisibility(R.id.pw_empty, View.GONE)
                v.setTextViewText(R.id.pw_city, city)
                v.setTextViewText(R.id.pw_nexttxt, if (nextAt > 0) "$nextLabel: $nextName ${hm(nextAt)}" else "")
                for (i in 0 until 6) {
                    v.setTextViewText(nameIds[i], names.getOrElse(i) { "" })
                    v.setTextViewText(timeIds[i], hm(t[i]))
                    val on = i == nextIdx
                    v.setTextColor(nameIds[i], if (on) gold else muted)
                    v.setTextColor(timeIds[i], if (on) gold else ivory)
                    v.setInt(ids[i], "setBackgroundResource", if (on) R.drawable.widget_cell_on else R.drawable.widget_cell)
                }
            }
            appWidgetManager.updateAppWidget(id, v)
        }

        // Sıradaki vakit girince widget kendini yeniler.
        if (nextAt > 0) schedule(context, nextAt + 1000)
    }

    private fun hm(ms: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = ms }
        return String.format("%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun schedule(context: Context, at: Long) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            val all = mgr.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, all)
            }
            val pi = PendingIntent.getBroadcast(context, 4711, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.set(AlarmManager.RTC, at, pi)
        } catch (_: Exception) {
        }
    }
}
