package com.safety.orbit_shield

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

class AppBlockerManager(private val context: Context) {

    private val TAG = "AppBlockerManager"
    private var blockedApps = setOf<String>()
    private var launcherPackageName: String? = null
    private val PREFS_NAME = "FlutterSharedPreferences"

    init {
        launcherPackageName = getLauncherPackageName()
        updateBlockedList()
    }

    // Updates the list from SharedPreferences (called when service starts or window changes)
    fun updateBlockedList() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val blockedString = prefs.getString("flutter.native_blocked_apps", "") ?: ""
        
        if (blockedString.isNotEmpty()) {
            blockedApps = blockedString.split(",").toSet()
        } else {
            blockedApps = setOf()
        }
    }

    // Returns TRUE if the app should be blocked
    fun shouldBlockApp(packageName: String): Boolean {
        // Never block the home launcher
        if (packageName == launcherPackageName) return false

        val isBlocked = blockedApps.contains(packageName)
        if (isBlocked) {
            Log.d(TAG, "Blocking detected package: $packageName")
        }
        return isBlocked
    }

    private fun getLauncherPackageName(): String? {
        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
        intent.addCategory(android.content.Intent.CATEGORY_HOME)
        val resolveInfo = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName
    }
}