package com.application.iftook

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException

class AudioMethodChannel(private val context: Context) : MethodCallHandler {
    private var mediaPlayer: MediaPlayer? = null
    private val TAG = "AudioMethodChannel"
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            Log.d(TAG, "Received method call: ${call.method}")
            when (call.method) {
                "playRingtone" -> {
                    playRingtone()
                    result.success(true)
                }
                "playRingtoneAsCall" -> {
                    playRingtoneAsCall()
                    result.success(true)
                }
                "stopRingtone" -> {
                    stopRingtone()
                    result.success(true)
                }
                "checkRingtoneAccess" -> {
                    val hasAccess = checkRingtoneAccess()
                    Log.d(TAG, "Ringtone access check result: $hasAccess")
                    result.success(hasAccess)
                }
                "checkSoundResource" -> {
                    val name = call.argument<String>("name") ?: ""
                    val exists = checkSoundResourceExists(name)
                    Log.d(TAG, "Sound resource check for '$name': $exists")
                    result.success(exists)
                }
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call ${call.method}", e)
            result.error("ERROR", e.message, e.stackTraceToString())
        }
    }
    
    private fun playRingtone() {
        stopRingtone() // Stop any existing ringtone
        
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            Log.d(TAG, "Playing ringtone from URI: $ringtoneUri")
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, ringtoneUri)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_RING)
                }
                
                isLooping = true
                prepare()
                start()
            }
            Log.d(TAG, "Ringtone playback started successfully")
        } catch (e: IOException) {
            Log.e(TAG, "Error playing ringtone", e)
        }
    }
    
    private fun playRingtoneAsCall() {
        stopRingtone() // Stop any existing ringtone
        
        try {
            // Get the default ringtone
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            Log.d(TAG, "Playing call ringtone from URI: $ringtoneUri")
            
            // Get the audio manager
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Save current volume to restore later
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            
            // Set volume to maximum
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, maxVolume, 0)
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, ringtoneUri)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_VOICE_CALL)
                }
                
                isLooping = true
                prepare()
                start()
            }
            Log.d(TAG, "Call ringtone playback started successfully")
        } catch (e: IOException) {
            Log.e(TAG, "Error playing call ringtone", e)
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
            Log.d(TAG, "Ringtone stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping ringtone", e)
        }
    }
    
    private fun checkRingtoneAccess(): Boolean {
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val hasAccess = audioManager != null
            Log.d(TAG, "Ringtone access check: $hasAccess")
            hasAccess
        } catch (e: Exception) {
            Log.e(TAG, "Error checking ringtone access", e)
            false
        }
    }
    
    private fun checkSoundResourceExists(resourceName: String): Boolean {
        return try {
            Log.d(TAG, "Checking sound resource: $resourceName")
            
            // First check in raw resources
            var resourceId = context.resources.getIdentifier(
                resourceName, "raw", context.packageName
            )
            Log.d(TAG, "Raw resource ID for $resourceName: $resourceId")
            
            // If not found in raw, check in drawable
            if (resourceId == 0) {
                resourceId = context.resources.getIdentifier(
                    resourceName, "drawable", context.packageName
                )
                Log.d(TAG, "Drawable resource ID for $resourceName: $resourceId")
            }
            
            // If still not found, check if it's a system sound
            if (resourceId == 0) {
                val isSystemSound = when (resourceName) {
                    "ringtone" -> {
                        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        ringtoneUri != null
                    }
                    "notification" -> {
                        val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        notificationUri != null
                    }
                    else -> false
                }
                Log.d(TAG, "System sound check for $resourceName: $isSystemSound")
                isSystemSound
            } else {
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking sound resource: $resourceName", e)
            false
        }
    }
}
