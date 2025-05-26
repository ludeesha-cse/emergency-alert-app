package com.example.emergency_alert

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.emergency_alert/sms"
    private val SMS_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val message = call.argument<String>("message")
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                    
                    if (message != null && phoneNumbers != null) {
                        sendSMS(message, phoneNumbers, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Message or phone numbers are null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun sendSMS(message: String, phoneNumbers: List<String>, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_CODE)
            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
            return
        }

        try {
            val smsManager = SmsManager.getDefault()
            var allSent = true
            
            for (phoneNumber in phoneNumbers) {
                try {
                    // Split long messages if needed
                    val parts = smsManager.divideMessage(message)
                    if (parts.size == 1) {
                        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                    } else {
                        smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                    }
                } catch (e: Exception) {
                    allSent = false
                    android.util.Log.e("MainActivity", "Failed to send SMS to $phoneNumber: ${e.message}")
                }
            }
            
            result.success(allSent)
        } catch (e: Exception) {
            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }
}
