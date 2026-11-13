package com.cdkv

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            val prefs = context.getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()

            for ((key, value) in prefs.all) {
                if (key.startsWith("rem_") && value is String) {
                    try {
                        val obj = JSONObject(value)
                        val triggered = obj.optBoolean("triggered", false)
                        val triggerAtMillis = obj.optLong("triggerAtMillis", 0L)
                        val scheduleKey = obj.optString("scheduleKey", "")
                        val notificationId = obj.optInt("notificationId", scheduleKey.hashCode())
                        val title = obj.optString("title", "Pengingat Jadwal Kegiatan")
                        val body = obj.optString("body", "")

                        if (!triggered && scheduleKey.isNotEmpty() && triggerAtMillis > now - 60000L) {
                            val effectiveTrigger = if (triggerAtMillis <= now) now + 3000L else triggerAtMillis
                            MainActivity.scheduleExactAlarm(
                                context = context,
                                scheduleKey = scheduleKey,
                                notificationId = notificationId,
                                triggerAtMillis = effectiveTrigger,
                                title = title,
                                body = body
                            )
                        }
                    } catch (_: Exception) {
                    }
                }
            }
        }
    }
}
