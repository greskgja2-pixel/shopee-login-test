package br.com.superanuncio.super_anuncio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat

class ReanalysisReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 7001)
        val title = intent.getStringExtra("title") ?: "Seu anúncio"
        val url = intent.getStringExtra("url") ?: ""

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("reanalyze_url", url)
            putExtra("reanalyze_title", title)
        }
        val pending = PendingIntent.getActivity(
            context,
            id,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "super_anuncio_reanalysis"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Reanálise de anúncios", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Lembretes para revisar anúncios após 7 dias"
                }
            )
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setColor(Color.rgb(255, 90, 31))
            .setContentTitle("Hora de reanalisar seu anúncio 📈")
            .setContentText(title)
            .setStyle(NotificationCompat.BigTextStyle().bigText("Já passaram 7 dias. Reanalise “$title” e compare a nova nota com a anterior."))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pending)
            .build()

        manager.notify(id, notification)
        ReminderScheduler.remove(context, id)
    }
}
