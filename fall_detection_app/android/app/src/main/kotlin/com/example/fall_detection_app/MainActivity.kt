package com.example.fall_detection_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "fall_detection_channel", // Must match your service config
                "Fall Detection",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Notifications for fall detection foreground service"
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
