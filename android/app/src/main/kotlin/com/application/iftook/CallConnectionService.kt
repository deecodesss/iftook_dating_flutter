package com.application.iftook

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import androidx.annotation.RequiresApi

@RequiresApi(api = Build.VERSION_CODES.M)
class CallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection {
        val connection = object : Connection() {
            override fun onAnswer() {
                super.onAnswer()
                // Launch main activity with accept action
                val intent = Intent(applicationContext, MainActivity::class.java).apply {
                    putExtra("call_action", "accept")
                    putExtra("call_id", request.extras.getString("call_id"))
                    putExtra("is_video", request.extras.getBoolean("is_video", false))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(intent)
                
                // Set connection as active
                setActive()
            }

            override fun onReject() {
                super.onReject()
                // Handle call rejection
                setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
                destroy()
                
                // Notify the app about rejection
                val intent = Intent(applicationContext, MainActivity::class.java).apply {
                    putExtra("call_action", "reject")
                    putExtra("call_id", request.extras.getString("call_id"))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }

            override fun onDisconnect() {
                super.onDisconnect()
                setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                destroy()
            }
        }

        connection.connectionCapabilities = Connection.CAPABILITY_MUTE or Connection.CAPABILITY_SUPPORT_HOLD
        
        // Set caller information
        val extras = request.extras
        connection.setCallerDisplayName(
            extras.getString("caller_name", "Unknown Caller"),
            TelecomManager.PRESENTATION_ALLOWED
        )
        
        // Set as ringing
        connection.setRinging()
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection? {
        // Not implementing outgoing calls for now
        return null
    }
}
