package com.hatimkardesim.hatim_kardesim

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.util.Calendar

/**
 * Bildirim çubuğunda sürekli duran namaz vakti bildirimi: sıradaki vakit, ona geri sayım ve
 * o günün altı vakti. Vakitler uygulamanın widget için yazdığı verilerden okunur; sıradaki vakit
 * girince alarm bu alıcıyı yeniden çalıştırır, telefon yeniden başlayınca da kendini kurar.
 */
class PrayerBarReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL = "vakit_cubugu"
        private const val NOTIF_ID = 4800
        private const val ALARM_CODE = 4712
        private const val DELETE_CODE = 4713
        const val ACTION_TICK = "com.hatimkardesim.hatim_kardesim.PRAYER_BAR_TICK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            update(context)
        } catch (_: Exception) {
        }
    }

    private fun update(context: Context) {
        val data = HomeWidgetPlugin.getData(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!data.getBoolean("pb_enabled", false)) {
            nm.cancel(NOTIF_ID)
            cancelAlarm(context)
            return
        }

        val names = (data.getString("pw_names", null) ?: "İmsak|Güneş|Öğle|İkindi|Akşam|Yatsı").split("|")
        val city = data.getString("pw_city", "") ?: ""
        val nextLabel = data.getString("pw_next", null) ?: "Sıradaki"
        val now = System.currentTimeMillis()

        // Sıradaki vakti ve o vaktin bulunduğu günü bul.
        var day: LongArray? = null
        var nextAt = 0L
        var nextIdx = -1
        val days = JSONArray(data.getString("pw_times", "[]") ?: "[]")
        loop@ for (d in 0 until days.length()) {
            val arr = days.getJSONArray(d)
            if (arr.length() < 6) continue
            val ts = LongArray(6) { arr.getLong(it) }
            for (i in 0 until 6) {
                if (ts[i] > now) {
                    day = ts; nextAt = ts[i]; nextIdx = i
                    break@loop
                }
            }
        }
        val t = day
        if (t == null || city.isEmpty()) {
            nm.cancel(NOTIF_ID)
            cancelAlarm(context)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL,
                data.getString("pb_channel", null) ?: "Bildirim çubuğunda vakitler",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            nm.createNotificationChannel(ch)
        }

        val nextName = names.getOrElse(nextIdx) { "" }
        val list = (0 until 6).joinToString("  ·  ") { i -> "${names.getOrElse(i) { "" }} ${hm(t[i])}" }
        val leftLabel = data.getString("pb_left", null) ?: "kalan"

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val open = if (launch != null) PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        ) else null

        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(context, CHANNEL) else Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        b.setSmallIcon(R.drawable.ic_stat_vakit)
            .setColor(Color.parseColor("#C9962E"))
            .setContentTitle("$nextLabel: $nextName ${hm(nextAt)}")
            .setContentText(list)
            .setSubText(city)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (open != null) b.setContentIntent(open)
        // Android 14+ sürekli bildirimlerin de kaydırılıp kaldırılmasına izin veriyor:
        // kullanıcı kaydırırsa bildirim hemen yeniden gösterilir. Kapatmak uygulama ayarlarından.
        val again = Intent(context, PrayerBarReceiver::class.java).setAction(ACTION_TICK)
        b.setDeleteIntent(PendingIntent.getBroadcast(context, DELETE_CODE, again,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Kendi düzenimiz: kapalıyken tek satır, açınca altı vakit kutucukları.
            val night = (context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val accent = Color.parseColor(if (night) "#F2C14A" else "#A87A12")
            val base = SystemClock.elapsedRealtime() + (nextAt - now)

            fun header(v: RemoteViews) {
                v.setTextViewText(R.id.pb_name, nextName)
                v.setTextViewText(R.id.pb_time, hm(nextAt))
                v.setTextViewText(R.id.pb_left, leftLabel)
                v.setChronometer(R.id.pb_timer, base, null, true)
                v.setChronometerCountDown(R.id.pb_timer, true)
            }

            val small = RemoteViews(context.packageName, R.layout.prayer_bar_small).also(::header)
            val big = RemoteViews(context.packageName, R.layout.prayer_bar_big).also(::header)
            val cells = intArrayOf(R.id.pb_c0, R.id.pb_c1, R.id.pb_c2, R.id.pb_c3, R.id.pb_c4, R.id.pb_c5)
            val ns = intArrayOf(R.id.pb_n0, R.id.pb_n1, R.id.pb_n2, R.id.pb_n3, R.id.pb_n4, R.id.pb_n5)
            val ts = intArrayOf(R.id.pb_t0, R.id.pb_t1, R.id.pb_t2, R.id.pb_t3, R.id.pb_t4, R.id.pb_t5)
            for (i in 0 until 6) {
                big.setTextViewText(ns[i], names.getOrElse(i) { "" })
                big.setTextViewText(ts[i], hm(t[i]))
                if (i == nextIdx) {
                    big.setInt(cells[i], "setBackgroundResource", R.drawable.prayer_bar_cell_on)
                    big.setTextColor(ns[i], accent)
                    big.setTextColor(ts[i], accent)
                }
            }
            b.setStyle(Notification.DecoratedCustomViewStyle())
                .setCustomContentView(small)
                .setCustomBigContentView(big)
                .setShowWhen(false)
        } else {
            b.setStyle(Notification.BigTextStyle().bigText(list))
                .setShowWhen(true)
                .setWhen(nextAt)
                .setUsesChronometer(true)
        }
        nm.notify(NOTIF_ID, b.build())

        // Sıradaki vakit girince bildirimi yenile.
        schedule(context, nextAt + 1000)
    }

    private fun hm(ms: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = ms }
        return String.format("%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun tick(context: Context): PendingIntent {
        val i = Intent(context, PrayerBarReceiver::class.java).setAction(ACTION_TICK)
        return PendingIntent.getBroadcast(context, ALARM_CODE, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun schedule(context: Context, at: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = tick(context)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        try {
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun cancelAlarm(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(tick(context))
    }
}
