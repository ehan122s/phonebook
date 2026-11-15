package com.cdkv

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_NAME = "com.cdkv.phonebook/notifications"
        const val STORAGE_CHANNEL_NAME = "com.cdkv.phonebook/storage"
        const val NOTIFICATION_CHANNEL_ID = "phonebook_reminder_channel_v2"
        const val NOTIFICATION_CHANNEL_NAME = "Notifikasi & Pengingat Jadwal Phonebook"
        const val PREFS_NAME = "phonebook_native_reminders"
        const val PERMISSION_REQUEST_CODE = 10021

        fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val existing = manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
                if (existing == null) {
                    val channel = NotificationChannel(
                        NOTIFICATION_CHANNEL_ID,
                        NOTIFICATION_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description =
                            "Saluran notifikasi laporan, jadwal, dan pengingat otomatis aplikasi Phonebook Kehutanan"
                        enableVibration(true)
                        enableLights(true)
                    }
                    manager.createNotificationChannel(channel)
                }
            }
        }

        fun showSystemNotification(
            context: Context,
            notificationId: Int,
            title: String,
            body: String
        ) {
            ensureNotificationChannel(context)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                notificationId,
                launchIntent,
                pendingFlags
            )

            val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setAutoCancel(true)
                .setContentIntent(contentIntent)

            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(notificationId, builder.build())
        }

        fun scheduleExactAlarm(
            context: Context,
            scheduleKey: String,
            notificationId: Int,
            triggerAtMillis: Long,
            title: String,
            body: String
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, ReminderBroadcastReceiver::class.java).apply {
                action = "com.cdkv.phonebook.ACTION_TRIGGER_REMINDER_$notificationId"
                putExtra("scheduleKey", scheduleKey)
                putExtra("notificationId", notificationId)
                putExtra("title", title)
                putExtra("body", body)
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                flags
            )

            val showIntent = PendingIntent.getActivity(
                context,
                notificationId,
                Intent(context, MainActivity::class.java),
                flags
            )

            // Batalkan alarm sebelumnya dengan ID yang sama agar tidak ada notifikasi ganda
            alarmManager.cancel(pendingIntent)

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    // setAlarmClock tidak pernah di-throttle oleh Doze mode Android
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent)
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
            } catch (_: SecurityException) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    } else {
                        alarmManager.set(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    }
                } catch (_: Exception) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    }
                }
            }
        }

        fun cancelScheduledAlarm(context: Context, scheduleKey: String, notificationId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, ReminderBroadcastReceiver::class.java).apply {
                action = "com.cdkv.phonebook.ACTION_TRIGGER_REMINDER_$notificationId"
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                flags
            )
            alarmManager.cancel(pendingIntent)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove("rem_$scheduleKey").apply()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureNotificationChannel(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                PERMISSION_REQUEST_CODE
                            )
                        }
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }

                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "Notifikasi Phonebook"
                    val body = call.argument<String>("body") ?: ""
                    showSystemNotification(applicationContext, id, title, body)
                    result.success(true)
                }

                "scheduleReminder" -> {
                    val scheduleKey = call.argument<String>("scheduleKey") ?: ""
                    val notificationId = call.argument<Int>("notificationId") ?: scheduleKey.hashCode()
                    val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                    val title = call.argument<String>("title") ?: "Pengingat Jadwal Kegiatan"
                    val body = call.argument<String>("body") ?: ""
                    val reminderSignature = call.argument<String>("signature") ?: scheduleKey

                    if (scheduleKey.isNotEmpty() && triggerAtMillis > 0L) {
                        val prefs = applicationContext.getSharedPreferences(
                            PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        val existingRaw = prefs.getString("rem_$scheduleKey", null)
                        var alreadyTriggeredForSameSignature = false
                        if (existingRaw != null) {
                            try {
                                val existingObj = JSONObject(existingRaw)
                                if (existingObj.optString("signature") == reminderSignature &&
                                    existingObj.optBoolean("triggered", false)
                                ) {
                                    alreadyTriggeredForSameSignature = true
                                }
                            } catch (_: Exception) {
                            }
                        }

                        if (!alreadyTriggeredForSameSignature) {
                            val obj = JSONObject().apply {
                                put("scheduleKey", scheduleKey)
                                put("notificationId", notificationId)
                                put("triggerAtMillis", triggerAtMillis)
                                put("title", title)
                                put("body", body)
                                put("signature", reminderSignature)
                                put("triggered", false)
                            }
                            prefs.edit().putString("rem_$scheduleKey", obj.toString()).apply()

                            scheduleExactAlarm(
                                applicationContext,
                                scheduleKey,
                                notificationId,
                                triggerAtMillis,
                                title,
                                body
                            )
                        }
                    }
                    result.success(true)
                }

                "cancelReminder" -> {
                    val scheduleKey = call.argument<String>("scheduleKey") ?: ""
                    val notificationId = call.argument<Int>("notificationId") ?: scheduleKey.hashCode()
                    if (scheduleKey.isNotEmpty()) {
                        cancelScheduledAlarm(applicationContext, scheduleKey, notificationId)
                    }
                    result.success(true)
                }

                "cancelAllReminders" -> {
                    val prefs = applicationContext.getSharedPreferences(
                        PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val allEntries = prefs.all
                    for ((key, value) in allEntries) {
                        if (key.startsWith("rem_") && value is String) {
                            try {
                                val obj = JSONObject(value)
                                val scheduleKey = obj.optString("scheduleKey")
                                val notificationId = obj.optInt("notificationId")
                                cancelScheduledAlarm(applicationContext, scheduleKey, notificationId)
                            } catch (_: Exception) {
                            }
                        }
                    }
                    prefs.edit().clear().apply()
                    result.success(true)
                }

                "getTriggeredReminders" -> {
                    val prefs = applicationContext.getSharedPreferences(
                        PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val triggeredList = mutableListOf<String>()
                    for ((key, value) in prefs.all) {
                        if (key.startsWith("rem_") && value is String) {
                            try {
                                val obj = JSONObject(value)
                                if (obj.optBoolean("triggered", false)) {
                                    triggeredList.add(obj.optString("signature"))
                                }
                            } catch (_: Exception) {
                            }
                        }
                    }
                    result.success(triggeredList)
                }

                else -> result.notImplemented()
            }
        }

        // Saluran Khusus Penyimpanan & Unduhan Berkas ke Folder Download HP (Scoped Storage & MediaStore)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFileToDownloads" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "download_${System.currentTimeMillis()}"
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val subfolder = call.argument<String>("subfolder") ?: ""

                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_BYTES", "Bytes file kosong atau tidak valid", null)
                            return@setMethodCallHandler
                        }

                        val res = saveToPublicDownloads(bytes, fileName, mimeType, subfolder)
                        result.success(res)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message ?: "Gagal menyimpan berkas ke folder Download", null)
                    }
                }

                "openFile" -> {
                    try {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        val file = File(filePath)

                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File tidak ditemukan di $filePath", null)
                            return@setMethodCallHandler
                        }

                        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            try {
                                FileProvider.getUriForFile(
                                    applicationContext,
                                    "${applicationContext.packageName}.fileProvider.com.crazecoder.openfile",
                                    file
                                )
                            } catch (_: Exception) {
                                Uri.fromFile(file)
                            }
                        } else {
                            Uri.fromFile(file)
                        }

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", e.message ?: "Gagal membuka berkas dengan aplikasi eksternal", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Menyimpan berkas biner langsung ke folder publik Download HP Android.
     * Menggunakan MediaStore.Downloads API resmi untuk Android 10 (Q) hingga Android 15+,
     * sehingga berkas 100% muncul di File Manager HP tanpa memicu batasan Scoped Storage.
     */
    private fun saveToPublicDownloads(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        subfolder: String?
    ): Map<String, Any?> {
        val relFolder = if (!subfolder.isNullOrBlank()) {
            Environment.DIRECTORY_DOWNLOADS + "/" + subfolder.trim('/')
        } else {
            Environment.DIRECTORY_DOWNLOADS
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relFolder)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IllegalStateException("Tidak dapat mendaftarkan berkas di MediaStore Downloads")

            resolver.openOutputStream(uri)?.use { os ->
                os.write(bytes)
                os.flush()
            } ?: throw IllegalStateException("Tidak dapat membuka output stream ke berkas tujuan")

            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            val fullPath = "/storage/emulated/0/$relFolder/$fileName"

            try {
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(fullPath),
                    arrayOf(mimeType),
                    null
                )
            } catch (_: Exception) {}

            return mapOf(
                "success" to true,
                "filePath" to fullPath,
                "uri" to uri.toString(),
                "fileName" to fileName,
                "displayPath" to "$relFolder/$fileName"
            )
        } else {
            val baseDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val targetDir = if (!subfolder.isNullOrBlank()) {
                File(baseDir, subfolder.trim('/'))
            } else {
                baseDir
            }

            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            var destFile = File(targetDir, fileName)
            if (destFile.exists()) {
                val dotIndex = fileName.lastIndexOf('.')
                val base = if (dotIndex != -1) fileName.substring(0, dotIndex) else fileName
                val ext = if (dotIndex != -1) fileName.substring(dotIndex) else ""
                var counter = 1
                while (destFile.exists()) {
                    destFile = File(targetDir, "$base ($counter)$ext")
                    counter++
                }
            }

            FileOutputStream(destFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }

            try {
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(destFile.absolutePath),
                    arrayOf(mimeType),
                    null
                )
            } catch (_: Exception) {}

            val display = "Download/" + (if (!subfolder.isNullOrBlank()) "${subfolder.trim('/')}/" else "") + destFile.name

            return mapOf(
                "success" to true,
                "filePath" to destFile.absolutePath,
                "uri" to Uri.fromFile(destFile).toString(),
                "fileName" to destFile.name,
                "displayPath" to display
            )
        }
    }
}
