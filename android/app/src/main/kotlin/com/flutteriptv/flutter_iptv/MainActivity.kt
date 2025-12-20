package com.flutteriptv.flutter_iptv

import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.flutteriptv/platform"
    private val PLAYER_CHANNEL = "com.flutteriptv/native_player"
    
    private var playerFragment: NativePlayerFragment? = null
    private var playerContainer: FrameLayout? = null
    private var playerMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")
        
        // Platform detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTV" -> {
                    result.success(isAndroidTV())
                }
                "getDeviceType" -> {
                    result.success(getDeviceType())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Native player channel
        playerMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL)
        playerMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "launchPlayer" -> {
                    val url = call.argument<String>("url")
                    val name = call.argument<String>("name") ?: ""
                    val index = call.argument<Int>("index") ?: 0
                    val urls = call.argument<List<String>>("urls")
                    val names = call.argument<List<String>>("names")
                    
                    if (url != null) {
                        Log.d(TAG, "Launching native player fragment: $name (index $index of ${urls?.size ?: 0})")
                        try {
                            showPlayerFragment(url, name, index, urls, names)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to launch player", e)
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "Video URL is required", null)
                    }
                }
                "closePlayer" -> {
                    hidePlayerFragment()
                    result.success(true)
                }
                "isNativePlayerAvailable" -> {
                    result.success(isAndroidTV())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")
        
        // Create player container overlay
        playerContainer = FrameLayout(this).apply {
            id = View.generateViewId()
            visibility = View.GONE
            setBackgroundColor(0xFF000000.toInt())
        }
        
        // Add container on top of Flutter view
        addContentView(
            playerContainer,
            android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
    }
    
    private fun showPlayerFragment(
        url: String,
        name: String,
        index: Int,
        urls: List<String>?,
        names: List<String>?
    ) {
        Log.d(TAG, "showPlayerFragment")
        
        // Hide system UI
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        
        playerContainer?.visibility = View.VISIBLE
        
        playerFragment = NativePlayerFragment.newInstance(
            url,
            name,
            index,
            urls?.let { ArrayList(it) },
            names?.let { ArrayList(it) }
        ).apply {
            onCloseListener = {
                runOnUiThread {
                    hidePlayerFragment()
                }
            }
        }
        
        supportFragmentManager.beginTransaction()
            .replace(playerContainer!!.id, playerFragment!!)
            .commit()
    }
    
    private fun hidePlayerFragment() {
        Log.d(TAG, "hidePlayerFragment")
        
        playerFragment?.let {
            supportFragmentManager.beginTransaction()
                .remove(it)
                .commitAllowingStateLoss()
        }
        playerFragment = null
        playerContainer?.visibility = View.GONE
        
        // Restore system UI
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        
        // Notify Flutter that player closed
        playerMethodChannel?.invokeMethod("onPlayerClosed", null)
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // If player is showing, let it handle keys
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            // Back key handling
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                hidePlayerFragment()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onBackPressed() {
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            hidePlayerFragment()
            return
        }
        super.onBackPressed()
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called")
    }
    
    private fun isAndroidTV(): Boolean {
        val uiModeManager = getSystemService(UI_MODE_SERVICE) as android.app.UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }
    
    private fun getDeviceType(): String {
        return when {
            isAndroidTV() -> "tv"
            isTablet() -> "tablet"
            else -> "phone"
        }
    }
    
    private fun isTablet(): Boolean {
        val screenLayout = resources.configuration.screenLayout
        val screenSize = screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK
        return screenSize >= Configuration.SCREENLAYOUT_SIZE_LARGE
    }
}
