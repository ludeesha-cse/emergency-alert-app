package com.example.emergency_alert

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class MainActivity : FlutterActivity(), MethodCallHandler {
    private val CHANNEL = "com.emergency_alert/sms"
    private val SMS_PERMISSION_CODE = 100
    private val SENT_SMS_ACTION = "EMERGENCY_ALERT_SMS_SENT"
    private val DELIVERED_SMS_ACTION = "EMERGENCY_ALERT_SMS_DELIVERED"
    
    // Store pending SMS operations
    private data class PendingSms(val phoneNumber: String, val message: String, val result: Result)
    private var pendingSmsOperations: MutableList<PendingSms> = mutableListOf()
    private var smsChannel: MethodChannel? = null
    
    // Track current operation for status callbacks
    private var currentSmsResult: Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.i("EmergencyAlert", "🚀 Configuring Flutter engine and SMS channel")
        smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        smsChannel?.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.i("EmergencyAlert", "📞 Method called: ${call.method}")
        
        when (call.method) {
            "sendSMS" -> {
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                val message = call.argument<String>("message") ?: ""
                
                if (phoneNumber.isEmpty()) {
                    Log.e("EmergencyAlert", "❌ Phone number is empty")
                    result.error("INVALID_PHONE", "Phone number cannot be empty", null)
                    return
                }
                
                if (message.isEmpty()) {
                    Log.e("EmergencyAlert", "❌ Message is empty")
                    result.error("INVALID_MESSAGE", "Message cannot be empty", null)
                    return
                }
                
                Log.d("EmergencyAlert", "📱 Attempting to send SMS to $phoneNumber")
                // Print the sanitized phone number for debugging
                val sanitizedPhoneNumber = phoneNumber.replace(Regex("[^0-9+]"), "")
                Log.d("EmergencyAlert", "📱 Sanitized phone number: $sanitizedPhoneNumber")
                
                if (checkSmsPermission()) {
                    Log.d("EmergencyAlert", "✅ SMS permission already granted")
                    sendSMSDirectly(sanitizedPhoneNumber, message, result)
                } else {
                    Log.d("EmergencyAlert", "⚠️ SMS permission not granted, requesting...")
                    pendingSmsOperations.add(PendingSms(sanitizedPhoneNumber, message, result))
                    requestSmsPermission()
                }
            }
            else -> {
                Log.w("EmergencyAlert", "⚠️ Method not implemented: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun checkSmsPermission(): Boolean {
        val permissionCheck = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.SEND_SMS
        )
        val isGranted = permissionCheck == PackageManager.PERMISSION_GRANTED
        Log.d("EmergencyAlert", "📋 SMS permission status: $isGranted")
        return isGranted
    }

    private fun requestSmsPermission() {
        Log.d("EmergencyAlert", "🔐 Requesting SMS permission")
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            SMS_PERMISSION_CODE
        )
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && 
                          grantResults[0] == PackageManager.PERMISSION_GRANTED
            
            if (granted) {
                Log.d("EmergencyAlert", "✅ SMS permission granted, processing ${pendingSmsOperations.size} pending operations")
                // Process pending SMS operations
                val pendingOps = pendingSmsOperations.toList()
                pendingSmsOperations.clear()
                
                for (operation in pendingOps) {
                    sendSMSDirectly(operation.phoneNumber, operation.message, operation.result)
                }
            } else {
                Log.e("EmergencyAlert", "❌ SMS permission denied")
                // Notify all pending operations of failure
                for (operation in pendingSmsOperations) {
                    operation.result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                }
                pendingSmsOperations.clear()
            }
        }
    }

    private fun sendSMSDirectly(phoneNumber: String, message: String, result: Result) {
        try {
            Log.d("EmergencyAlert", "📤 Sending SMS to $phoneNumber")
            currentSmsResult = result
            
            // Extra check for permission - just to be safe
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                Log.e("EmergencyAlert", "❌ SMS permission not granted when trying to send")
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }
            
            // Register receivers for status updates
            registerSmsStatusReceivers()
            
            // Get the SmsManager instance based on Android version
            val smsManager = getSmsManager()
            
            Log.d("EmergencyAlert", "📱 Using SmsManager: ${smsManager.javaClass.name}")
            
            // Create pending intents for sent and delivered status with unique request codes
            val requestCode = System.currentTimeMillis().toInt()
            
            val sentPI = PendingIntent.getBroadcast(
                this, requestCode, Intent(SENT_SMS_ACTION),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
            )
            
            val deliveredPI = PendingIntent.getBroadcast(
                this, requestCode + 1, Intent(DELIVERED_SMS_ACTION),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
            )
            
            // First check carrier/SIM status for better debugging
            try {
                val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
                val simState = telephonyManager.simState
                val networkOperator = telephonyManager.networkOperatorName ?: "unknown"
                Log.d("EmergencyAlert", "📱 SIM state: $simState, Network: $networkOperator")
                
                // Check if device has SMS capability
                if (packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
                    Log.d("EmergencyAlert", "✅ Device has telephony feature")
                } else {
                    Log.w("EmergencyAlert", "⚠️ Device does not have telephony feature")
                }
            } catch (e: Exception) {
                Log.e("EmergencyAlert", "Error checking telephony status: ${e.message}")
            }
            
            // Try multiple SMS sending approaches
            var smsSuccess = false
            var lastError: Exception? = null
            
            // Approach 1: Standard API with PendingIntents
            if (!smsSuccess) {
                try {
                    if (message.length > 160) {
                        Log.d("EmergencyAlert", "📝 [Approach 1] Message is long, dividing into parts")
                        val messageParts = smsManager.divideMessage(message)
                        
                        val sentIntents = ArrayList<PendingIntent>().apply { 
                            for (i in messageParts.indices) {
                                add(PendingIntent.getBroadcast(
                                    this@MainActivity, requestCode + (i * 2),
                                    Intent(SENT_SMS_ACTION),
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
                                ))
                            }
                        }
                        
                        val deliveredIntents = ArrayList<PendingIntent>().apply { 
                            for (i in messageParts.indices) { 
                                add(PendingIntent.getBroadcast(
                                    this@MainActivity, requestCode + (i * 2) + 1,
                                    Intent(DELIVERED_SMS_ACTION),
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
                                ))
                            }
                        }
                        
                        Log.d("EmergencyAlert", "📤 [Approach 1] Sending multipart SMS")
                        smsManager.sendMultipartTextMessage(
                            phoneNumber, 
                            null, 
                            messageParts, 
                            sentIntents, 
                            deliveredIntents
                        )
                        
                        Log.d("EmergencyAlert", "📧 [Approach 1] Multipart SMS queued successfully")
                        smsSuccess = true
                    } else {
                        Log.d("EmergencyAlert", "📤 [Approach 1] Sending single part SMS")
                        smsManager.sendTextMessage(phoneNumber, null, message, sentPI, deliveredPI)
                        
                        Log.d("EmergencyAlert", "📧 [Approach 1] SMS queued successfully")
                        smsSuccess = true
                    }
                } catch (e: Exception) {
                    lastError = e
                    Log.e("EmergencyAlert", "❌ [Approach 1] Failed: ${e.message}", e)
                }
            }
            
            // Approach 2: Basic API without PendingIntents
            if (!smsSuccess) {
                try {
                    Log.d("EmergencyAlert", "� [Approach 2] Trying basic SMS sending without PendingIntents")
                    
                    if (message.length > 160) {
                        val messageParts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phoneNumber, null, messageParts, null, null)
                    } else {
                        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                    }
                    
                    Log.d("EmergencyAlert", "📱 [Approach 2] Basic SMS sending completed")
                    smsSuccess = true
                } catch (e: Exception) {
                    lastError = e
                    Log.e("EmergencyAlert", "❌ [Approach 2] Failed: ${e.message}", e)
                }
            }
            
            // Approach 3: Try via Intent
            if (!smsSuccess) {
                try {
                    Log.d("EmergencyAlert", "🔄 [Approach 3] Trying via Intent.ACTION_SENDTO")
                    
                    // This won't actually send the SMS but will tell us if we can
                    val intent = Intent(Intent.ACTION_SENDTO)
                    intent.data = Uri.parse("smsto:$phoneNumber")
                    intent.putExtra("sms_body", message)
                    
                    if (intent.resolveActivity(packageManager) != null) {
                        Log.d("EmergencyAlert", "✅ [Approach 3] SMS app available")
                        // Don't actually launch it, just checking if possible
                        // If we get here, SMS sending is theoretically possible
                        // We'll consider this a "check" success
                    } else {
                        Log.e("EmergencyAlert", "❌ [Approach 3] No SMS app available")
                    }
                } catch (e: Exception) {
                    Log.e("EmergencyAlert", "❌ [Approach 3] Error checking SMS intent: ${e.message}", e)
                }
            }
            
            // Final result
            if (smsSuccess) {
                Log.d("EmergencyAlert", "✅ SMS operation completed successfully (at least queued)")
                result.success(true)
            } else {
                Log.e("EmergencyAlert", "❌ All SMS sending approaches failed")
                if (lastError != null) {
                    result.error("SMS_FAILED", "Failed to send SMS: ${lastError.message}", null)
                } else {
                    result.error("SMS_FAILED", "Failed to send SMS: Unknown error", null)
                }
                currentSmsResult = null
            }
        } catch (e: Exception) {
            Log.e("EmergencyAlert", "❌ Failed to send SMS: ${e.message}", e)
            e.printStackTrace()
            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
            currentSmsResult = null
        }
    }
    
    private fun registerSmsStatusReceivers() {
        // SMS sent status receiver
        try {
            val sentFilter = IntentFilter(SENT_SMS_ACTION)
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            Log.d("EmergencyAlert", "✅ SMS sent successfully")
                            // We already returned success when initiating the SMS
                        }
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                            // Try to get the more detailed error from the extras
                            val extraError = intent.getIntExtra("errorCode", -1)
                            val errorDetails = when (extraError) {
                                1 -> "SMS_NETWORK_ERROR"
                                2 -> "SMS_RATE_EXCEEDED_ERROR"
                                3 -> "SMS_TRANSPORT_ERROR"
                                4 -> "SMS_INTERNAL_ERROR"
                                else -> "UNKNOWN_ERROR ($extraError)"
                            }
                            Log.e("EmergencyAlert", "❌ SMS send failed: Generic failure - Details: $errorDetails")
                            
                            // Check if radio is powered
                            try {
                                val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
                                val simState = telephonyManager.simState
                                val networkOperator = telephonyManager.networkOperatorName ?: "unknown"
                                val serviceState = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    telephonyManager.serviceState?.state?.toString() ?: "unknown"
                                } else {
                                    "API too old to check"
                                }
                                Log.d("EmergencyAlert", "📱 SIM state: $simState, Network: $networkOperator, Service: $serviceState")
                            } catch (e: Exception) {
                                Log.e("EmergencyAlert", "Error checking telephony status: ${e.message}")
                            }
                        }
                        SmsManager.RESULT_ERROR_NO_SERVICE -> {
                            Log.e("EmergencyAlert", "❌ SMS send failed: No service - Device may be in airplane mode or have no cellular signal")
                        }
                        SmsManager.RESULT_ERROR_NULL_PDU -> {
                            Log.e("EmergencyAlert", "❌ SMS send failed: Null PDU - Protocol data unit error")
                        }
                        SmsManager.RESULT_ERROR_RADIO_OFF -> {
                            Log.e("EmergencyAlert", "❌ SMS send failed: Radio off - Cellular radio may be powered off")
                        }
                    }
                    
                    try {
                        context.unregisterReceiver(this)
                    } catch (e: IllegalArgumentException) {
                        Log.e("EmergencyAlert", "Error unregistering sent receiver: ${e.message}")
                    }
                }
            }, sentFilter)
            Log.d("EmergencyAlert", "✅ Registered SMS sent status receiver")
            
            // SMS delivered status receiver
            val deliveredFilter = IntentFilter(DELIVERED_SMS_ACTION)
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            Log.d("EmergencyAlert", "✅ SMS delivered successfully")
                        }
                        Activity.RESULT_CANCELED -> {
                            Log.e("EmergencyAlert", "⚠️ SMS not delivered")
                        }
                    }
                    
                    try {
                        context.unregisterReceiver(this)
                    } catch (e: IllegalArgumentException) {
                        Log.e("EmergencyAlert", "Error unregistering delivered receiver: ${e.message}")
                    }
                }
            }, deliveredFilter)
            Log.d("EmergencyAlert", "✅ Registered SMS delivered status receiver")
        } catch (e: Exception) {
            Log.e("EmergencyAlert", "❌ Failed to register SMS receivers: ${e.message}", e)
        }
    }
    
    private fun getSmsManager(): SmsManager {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Log.d("EmergencyAlert", "📱 Using Android 12+ SmsManager API")
                this.getSystemService(SmsManager::class.java)
            } else {
                Log.d("EmergencyAlert", "📱 Using legacy SmsManager API")
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        } catch (e: Exception) {
            Log.e("EmergencyAlert", "❌ Error getting SmsManager: ${e.message}", e)
            // Default to deprecated method as fallback
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }
}
