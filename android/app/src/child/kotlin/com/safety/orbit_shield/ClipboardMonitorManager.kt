package com.safety.orbit_shield

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class ClipboardMonitorManager(private val context: Context) {

    private val TAG = "ClipboardMonitor"
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val CLIPBOARD_BUFFER_KEY = "flutter.native_clipboard_buffer"
    
    private var lastClipboardText = ""
    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    fun checkClipboard() {
        try {
            // Check if clipboard has text
            if (!clipboardManager.hasPrimaryClip()) return
            
            val clipData = clipboardManager.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val item = clipData.getItemAt(0)
                val text = item.text?.toString() ?: ""

                if (text.isNotEmpty() && text != lastClipboardText) {
                    Log.d(TAG, "✅ Clipboard Captured: $text")
                    saveToBuffer(text)
                    lastClipboardText = text
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading clipboard: ${e.message}")
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
        } catch (e: Exception) {
            Log.e(TAG, "Error saving clipboard: ${e.message}")
        }
    }
}