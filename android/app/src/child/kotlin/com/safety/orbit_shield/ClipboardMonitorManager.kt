package com.safety.orbit_shield

import android.content.ClipboardManager
import android.content.Context
import android.content.ClipboardManager.OnPrimaryClipChangedListener
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class ClipboardMonitorManager(private val context: Context) {

    private val TAG = "ClipboardMonitor"
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val CLIPBOARD_BUFFER_KEY = "flutter.native_clipboard_buffer"
    
    private var lastClipboardText = ""
    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private val handler = Handler(Looper.getMainLooper())

    // Listener: Wakes up when clipboard content changes
    private val clipChangedListener = OnPrimaryClipChangedListener {
        Log.d(TAG, "⚡ Listener Triggered: Clipboard change detected.")
        
        // FIX: Wait 200ms before reading. 
        // Android sometimes blocks immediate reads from background services.
        handler.postDelayed({
            checkClipboard("Listener")
        }, 200)
    }

    init {
        try {
            clipboardManager.addPrimaryClipChangedListener(clipChangedListener)
            Log.i(TAG, "Native Clipboard Listener Registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register listener: ${e.message}")
        }
    }

    fun checkClipboard(source: String = "Manual") {
        try {
            if (!clipboardManager.hasPrimaryClip()) {
                // Log.d(TAG, "[$source] Clipboard empty.")
                return
            }
            
            val clipData = clipboardManager.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val item = clipData.getItemAt(0)
                val text = item.text?.toString() ?: ""

                if (text.isNotEmpty() && text != lastClipboardText) {
                    Log.d(TAG, "✅ CAPTURED ($source): $text")
                    saveToBuffer(text)
                    lastClipboardText = text
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "[$source] BLOCKED: Android prevented clipboard read. Ensure Service is running.")
        } catch (e: Exception) {
            Log.e(TAG, "[$source] Error: ${e.message}")
        }
    }

    private fun saveToBuffer(text: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingListString = prefs.getString(CLIPBOARD_BUFFER_KEY, "[]")
            val jsonArray = try { JSONArray(existingListString) } catch (e: Exception) { JSONArray() }

            val json = JSONObject()
            json.put("text", text)
            json.put("timestamp", System.currentTimeMillis())

            jsonArray.put(json.toString())
            prefs.edit().putString(CLIPBOARD_BUFFER_KEY, jsonArray.toString()).apply()
            Log.d(TAG, "Saved to buffer.")
        } catch (e: Exception) {
            Log.e(TAG, "Save Error: ${e.message}")
        }
    }
    
    fun cleanup() {
        try {
            clipboardManager.removePrimaryClipChangedListener(clipChangedListener)
        } catch (e: Exception) {}
    }
}