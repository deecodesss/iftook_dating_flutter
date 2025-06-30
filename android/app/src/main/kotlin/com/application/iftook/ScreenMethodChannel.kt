package com.application.iftook

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.content.Intent

class ScreenMethodChannel(private val context: Context) : MethodCallHandler {
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "wakeUpDevice" -> {
                wakeUpDevice()
                result.success(true)
            }
            "keepScreenOn" -> {
                try {
                    val activity = MainActivity.instance
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
            "allowScreenOff" -> {
                try {
                    val activity = MainActivity.instance
                    activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
            else -> result.notImplemented()
        }
    }
    
    private fun wakeUpDevice() {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "iftook:WakeLock"
            )
            
            // Acquire wake lock for 10 seconds to ensure device wakes up
            wakeLock.acquire(10*1000L)
            
            // Release after a delay
            android.os.Handler().postDelayed({
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }, 10000)
            
            // Also try to dismiss keyguard
            dismissKeyguard()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun dismissKeyguard() {
        try {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                keyguardManager.requestDismissKeyguard(
                    MainActivity.instance,
                    null
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
