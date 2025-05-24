package com.application.iftook

import android.content.Intent
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
    private val CHANNEL = "com.iftook.app/intent"
    
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
        
        handleIntent(intent)
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
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Handle method calls from Flutter here
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        // Extract call actions from intent
        val callAction = intent.getStringExtra("call_action")
        val callId = intent.getStringExtra("call_id")
        val isVideo = intent.getBooleanExtra("is_video", false)
        
        if (callAction != null && callId != null) {
            // Send to Flutter
            val args = HashMap<String, Any>()
            args["call_action"] = callAction
            args["call_id"] = callId
            if (isVideo) {
                args["is_video"] = true
            }
            
            if (flutterEngine != null) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onNewIntent", args)
            }
        }
    }
}
