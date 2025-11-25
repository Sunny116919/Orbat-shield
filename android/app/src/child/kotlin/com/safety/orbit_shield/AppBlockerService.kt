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
    private lateinit var clipboardMonitorManager: ClipboardMonitorManager 

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        // 1. Initialize Managers
        appBlockerManager = AppBlockerManager(this)
        webHistoryManager = WebHistoryManager(this)
        clipboardMonitorManager = ClipboardMonitorManager(this)

        // 2. Configure Accessibility Info
        val info = AccessibilityServiceInfo()
        
        // vvv UPDATED: Added CLICKED and TEXT_SELECTION events vvv
        // This ensures the service catches copy actions instantly
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or 
                          AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                          AccessibilityEvent.TYPE_VIEW_CLICKED or 
                          AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED
        // ^^^ END UPDATED ^^^
        
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                     AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info
        
        Log.i(TAG, "Orbit Shield Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // --- Logic 1: App Blocker ---
        // Only check blocking when the window state changes (new app opens)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            appBlockerManager.updateBlockedList()
            
            if (appBlockerManager.shouldBlockApp(packageName)) {
                Log.d(TAG, "BLOCKED: $packageName")
                performGlobalAction(GLOBAL_ACTION_HOME)
                return // Exit immediately if blocked
            }
        }

        // --- Logic 2: Clipboard Monitor ---
        // Check constantly. The manager handles logic to avoid duplicates.
        // This runs on Clicks/Selection too now, capturing "Copy" button presses.
        try {
            clipboardMonitorManager.checkClipboard()
        } catch (e: Exception) {
            // Log.e(TAG, "Error checking clipboard: ${e.message}")
        }

        // --- Logic 3: Web History ---
        try {
            webHistoryManager.processEvent(packageName, rootInActiveWindow)
        } catch (e: Exception) {
            // Log.e(TAG, "Error processing web history: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.e(TAG, "Service Interrupted")
    }

    // vvv NEW: Clean up the native clipboard listener when service stops vvv
    override fun onDestroy() {
        super.onDestroy()
        try {
            clipboardMonitorManager.cleanup()
        } catch (e: Exception) {}
    }
}