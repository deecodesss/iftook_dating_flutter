package com.application.iftook

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        // Static instance to allow access from other classes
        lateinit var instance: MainActivity
    }
    
    private val AUDIO_CHANNEL = "com.application.iftook/audio"
    private val RESOURCES_CHANNEL = "com.application.iftook/resources"
    private val SCREEN_CHANNEL = "com.application.iftook/screen"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Store reference to this activity
        instance = this
        
        // Configure window for full-screen intents
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Create and register the audio method channel handler
        val audioMethodChannel = AudioMethodChannel(context)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler(audioMethodChannel)
            
        // Register the resources method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESOURCES_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "checkSoundResource" -> {
                            val name = call.argument<String>("name") ?: ""
                            val resourceId = context.resources.getIdentifier(
                                name, "raw", context.packageName
                            )
                            result.success(resourceId != 0)
                        }
                        "checkRingtoneExists" -> {
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
            
        // Register the screen method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler(ScreenMethodChannel(context))
    }
}
