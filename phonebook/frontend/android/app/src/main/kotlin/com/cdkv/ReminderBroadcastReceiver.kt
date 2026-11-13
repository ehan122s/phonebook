package com.cdkv

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class ReminderBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleKey = intent.getStringExtra("scheduleKey") ?: return
        val notificationId = intent.getIntExtra("notificationId", scheduleKey.hashCode())
        val title = intent.getStringExtra("title") ?: "Pengingat Jadwal Kegiatan"
        val body = intent.getStringExtra("body") ?: "Agenda kegiatan Anda akan segera dimulai."

        val prefs = context.getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString("rem_$scheduleKey", null)
        if (raw != null) {
            try {
                val obj = JSONObject(raw)
                // Hindari notifikasi ganda untuk satu jadwal yang sama
                if (obj.optBoolean("triggered", false)) {
                    return
                }
                obj.put("triggered", true)
                obj.put("triggeredAtMillis", System.currentTimeMillis())
                prefs.edit().putString("rem_$scheduleKey", obj.toString()).apply()
            } catch (_: Exception) {
            }
        }

        MainActivity.showSystemNotification(
            context = context,
            notificationId = notificationId,
            title = title,
            body = body
        )
    }
}
