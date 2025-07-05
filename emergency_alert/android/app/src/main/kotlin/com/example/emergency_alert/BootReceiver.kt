package com.example.emergency_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Broadcast receiver that listens for system boot completion and package updates.
 * Used to restart the application's background services when the device boots or the app is updated.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "EmergencyAlert"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "🚀 BootReceiver: Received intent action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                Log.i(TAG, "📱 BootReceiver: Device boot or app update detected. Starting background services.")
                
                try {
                    // Start Flutter background service directly using the proper class reference
                    val serviceClass = Class.forName("id.flutter.flutter_background_service.BackgroundService")
                    val serviceIntent = Intent(context, serviceClass)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Log.i(TAG, "Starting as foreground service (Android O+)")
                        context.startForegroundService(serviceIntent)
                    } else {
                        Log.i(TAG, "Starting as regular service (pre-Android O)")
                        context.startService(serviceIntent)
                    }
                    
                    Log.i(TAG, "✅ BootReceiver: Background service start requested")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ BootReceiver: Failed to start background service", e)
                    e.printStackTrace()
                }
            }
            else -> {
                Log.d(TAG, "ℹ️ BootReceiver: Ignoring unhandled intent action: ${intent.action}")
            }
        }
    }
}
