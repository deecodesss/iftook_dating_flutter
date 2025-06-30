package com.application.iftook

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class AudioMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isVibrating = false
    private var isPlaying = false

    init {
        // Initialize vibrator based on Android version
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibrator = vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "playRingtone" -> {
                val ringtoneType = call.argument<Int>("ringtoneType") ?: RingtoneManager.TYPE_RINGTONE
                val loop = call.argument<Boolean>("loop") ?: true
                playRingtone(ringtoneType, loop)
                result.success(null)
            }
            "stopRingtone" -> {
                stopRingtone()
                result.success(null)
            }
            "startVibration" -> {
                val pattern = call.argument<LongArray>("pattern")
                val repeat = call.argument<Int>("repeat") ?: -1
                startVibration(pattern, repeat)
                result.success(null)
            }
            "stopVibration" -> {
                stopVibration()
                result.success(null)
            }
            "checkRingtoneAccess" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun playRingtone(ringtoneType: Int, loop: Boolean) {
        try {
            stopRingtone() // Stop any existing playback
            
            val ringtone = RingtoneManager.getRingtone(context, RingtoneManager.getDefaultUri(ringtoneType))
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, RingtoneManager.getDefaultUri(ringtoneType))
                isLooping = loop
                prepare()
                start()
            }
            isPlaying = true
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    private fun stopRingtone() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            isPlaying = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startVibration(pattern: LongArray?, repeat: Int) {
        if (vibrator == null) return
        
        stopVibration() // Stop any existing vibration
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (pattern != null) {
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, repeat))
                } else {
                    vibrator?.vibrate(VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE))
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern ?: longArrayOf(0, 1000, 1000), repeat)
            }
            isVibrating = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopVibration() {
        try {
            vibrator?.cancel()
            isVibrating = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
