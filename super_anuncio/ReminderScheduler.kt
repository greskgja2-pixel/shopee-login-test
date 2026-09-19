package br.com.superanuncio.super_anuncio

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

object ReminderScheduler {
    private const val PREFS = "super_anuncio_reminders"
    private const val KEY = "items"

    fun schedule(context: Context, id: Int, title: String, url: String, at: Long, persist: Boolean = true) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReanalysisReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("url", url)
        }

        if (at <= System.currentTimeMillis()) {
            if (persist) remove(context, id)
            context.sendBroadcast(intent)
            return
        }

        val pending = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarm.canScheduleExactAlarms()) {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } else {
            alarm.set(AlarmManager.RTC_WAKEUP, at, pending)
        }

        if (persist) save(context, id, title, url, at)
    }

    private fun save(context: Context, id: Int, title: String, url: String, at: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY, emptySet())?.toMutableSet() ?: mutableSetOf()
        items.removeAll { it.startsWith("$id|") }
        items.add("$id|$at|${Uri.encode(title)}|${Uri.encode(url)}")
        prefs.edit().putStringSet(KEY, items).apply()
    }

    fun remove(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY, emptySet())?.toMutableSet() ?: mutableSetOf()
        items.removeAll { it.startsWith("$id|") }
        prefs.edit().putStringSet(KEY, items).apply()
    }

    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY, emptySet()) ?: emptySet()
        val now = System.currentTimeMillis()

        for (entry in items.toList()) {
            val p = entry.split("|", limit = 4)
            if (p.size != 4) continue
            val id = p[0].toIntOrNull() ?: continue
            val at = p[1].toLongOrNull() ?: continue
            val title = Uri.decode(p[2])
            val url = Uri.decode(p[3])

            if (at <= now) {
                schedule(context, id, title, url, now + 1500L, persist = false)
            } else {
                schedule(context, id, title, url, at, persist = false)
            }
        }
    }
}
