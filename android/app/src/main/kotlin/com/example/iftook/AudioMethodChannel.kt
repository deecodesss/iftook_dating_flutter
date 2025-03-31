package com.example.iftook

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException

class AudioMethodChannel(private val context: Context) : MethodCallHandler {
    private var mediaPlayer: MediaPlayer? = null
    
    override fun onMethodCall(call: MethodCall, result: Result) {
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
                result.success(checkRingtoneAccess())
            }
            "checkSoundResource" -> {
                val name = call.argument<String>("name") ?: ""
                result.success(checkSoundResourceExists(name))
            }
            else -> result.notImplemented()
        }
    }
    
    private fun playRingtone() {
        stopRingtone() // Stop any existing ringtone
        
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            
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
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }
    
    private fun playRingtoneAsCall() {
        stopRingtone() // Stop any existing ringtone
        
        try {
            // Get the default ringtone
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            
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
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }
    
    private fun stopRingtone() {
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            release()
        }
        mediaPlayer = null
    }
    
    private fun checkRingtoneAccess(): Boolean {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        return audioManager != null
    }
    
    private fun checkSoundResourceExists(resourceName: String): Boolean {
        val resourceId = context.resources.getIdentifier(
            resourceName, "raw", context.packageName
        )
        return resourceId != 0
    }
}
