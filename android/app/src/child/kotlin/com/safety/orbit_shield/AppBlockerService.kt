package com.safety.orbit_shield

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    private val TAG = "AppBlockerService"
    
    // Declare the managers
    private lateinit var appBlockerManager: AppBlockerManager
    private lateinit var webHistoryManager: WebHistoryManager
    // vvv NEW: Declare Clipboard Manager vvv
    private lateinit var clipboardMonitorManager: ClipboardMonitorManager 
    // ^^^ END NEW ^^^

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        // 1. Initialize Managers
        appBlockerManager = AppBlockerManager(this)
        webHistoryManager = WebHistoryManager(this)
        // vvv NEW: Initialize Clipboard Manager vvv
        clipboardMonitorManager = ClipboardMonitorManager(this)
        // ^^^ END NEW ^^^

        // 2. Configure Accessibility Info
        val info = AccessibilityServiceInfo()
        
        // CRITICAL CHANGE: We now listen for BOTH State changes (for Blocking) AND Content changes (for URLs)
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                     AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info
        
        Log.i(TAG, "Orbit Shield Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        // Log.d(TAG, "Event from Package: $packageName") // Uncomment for debugging

        // --- Logic 1: App Blocker ---
        // Usually, blocking happens when a new window state occurs (App opens)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // Update list ensures we are always in sync with SharedPreferences
            appBlockerManager.updateBlockedList()
            
            if (appBlockerManager.shouldBlockApp(packageName)) {
                Log.d(TAG, "BLOCKED: $packageName")
                performGlobalAction(GLOBAL_ACTION_HOME)
                return // Exit immediately. Do not try to read URLs if the app is blocked.
            }
        }

        // --- Logic 2: Clipboard Monitor (NEW) ---
        // We check this on every event. It is very lightweight (just checks a string string vs string).
        // This ensures we catch the copy event almost instantly even if the app is in background/locked.
        try {
            clipboardMonitorManager.checkClipboard()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking clipboard: ${e.message}")
        }

        // --- Logic 3: Web History ---
        // We pass the event to the manager. It checks internally if the app is a browser.
        // We pass 'rootInActiveWindow' to allow scanning the screen for the URL bar.
        try {
            webHistoryManager.processEvent(packageName, rootInActiveWindow)
        } catch (e: Exception) {
            Log.e(TAG, "Error processing web history: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.e(TAG, "Service Interrupted")
    }
}