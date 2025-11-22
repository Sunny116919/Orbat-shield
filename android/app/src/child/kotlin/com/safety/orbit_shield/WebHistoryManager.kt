package com.safety.orbit_shield

import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

class WebHistoryManager(private val context: Context) {

    private val TAG = "WebHistoryManager"
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val WEB_BUFFER_KEY = "flutter.native_web_buffer"
    
    private var lastCapturedUrl = ""
    private var lastCaptureTime = 0L

    // Added Xiaomi/Mi Browser to the list
    private val browserPackages = setOf(
        "com.android.chrome",
        "com.google.android.apps.chrome",
        "com.microsoft.emmx", 
        "org.mozilla.firefox",
        "com.sec.android.app.sbrowser",
        "com.opera.browser",
        "com.brave.browser",
        "com.mi.global.browser", // Xiaomi Browser
        "com.mi.global.browser.mini" // Xiaomi Mint Browser
    )

    fun processEvent(packageName: String, rootNode: AccessibilityNodeInfo?) {
        // If it's not a supported browser, ignore it
        if (!browserPackages.contains(packageName) || rootNode == null) return

        // scanTreeForUrl will recursively search EVERY node for a URL
        val url = scanTreeForUrl(rootNode)

        if (url.isNotEmpty()) {
            val currentTime = System.currentTimeMillis()
            // Debounce: Don't save the same URL multiple times within 5 seconds
            if (url != lastCapturedUrl || (currentTime - lastCaptureTime > 5000)) {
                Log.d(TAG, "✅ CAPTURED URL: $url")
                saveUrlToBuffer(url, packageName)
                lastCapturedUrl = url
                lastCaptureTime = currentTime
            }
        }
    }

    // Recursive function to find ANY text that looks like a URL
    private fun scanTreeForUrl(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""

        // 1. Check current node text
        val text = node.text?.toString() ?: ""
        val contentDesc = node.contentDescription?.toString() ?: ""

        if (isValidUrl(text)) return text
        if (isValidUrl(contentDesc)) return contentDesc

        // 2. Check all children (Recursive)
        for (i in 0 until node.childCount) {
            val foundUrl = scanTreeForUrl(node.getChild(i))
            if (foundUrl.isNotEmpty()) return foundUrl
        }

        return ""
    }

    private fun isValidUrl(text: String): Boolean {
        // 1. Must contain a dot
        if (!text.contains(".")) return false
        
        // 2. Filter out system messages or search prompts
        if (text.contains("Search", true) || text.contains("Type", true) || text.contains("Google")) return false
        if (text.contains(" ")) return false // URLs usually don't have spaces

        // 3. Must look like a domain or link
        return text.startsWith("http") || 
               text.startsWith("www") || 
               text.endsWith(".com") || 
               text.endsWith(".org") || 
               text.endsWith(".net") ||
               text.endsWith(".io") ||
               text.endsWith(".in")
    }

    private fun saveUrlToBuffer(url: String, packageName: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingListString = prefs.getString(WEB_BUFFER_KEY, "[]")
            val jsonArray = try { JSONArray(existingListString) } catch (e: Exception) { JSONArray() }

            val json = JSONObject()
            json.put("url", url)
            json.put("packageName", packageName)
            json.put("timestamp", System.currentTimeMillis())

            jsonArray.put(json.toString())
            prefs.edit().putString(WEB_BUFFER_KEY, jsonArray.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Save Error: ${e.message}")
        }
    }
}