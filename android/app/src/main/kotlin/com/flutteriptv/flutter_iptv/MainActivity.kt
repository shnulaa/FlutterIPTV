package com.flutteriptv.flutter_iptv

import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.flutteriptv/platform"
    private val PLAYER_CHANNEL = "com.flutteriptv/native_player"
    private val INSTALL_CHANNEL = "com.flutteriptv/install"
    
    private var playerFragment: NativePlayerFragment? = null
    private var playerContainer: FrameLayout? = null
    private var playerMethodChannel: MethodChannel? = null
    
    private lateinit var backPressedCallback: OnBackPressedCallback

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
                "getCpuAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "armeabi-v7a")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // APK install channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            installApk(filePath)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to install APK", e)
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK file path is required", null)
                    }
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
                    val groups = call.argument<List<String>>("groups")
                    @Suppress("UNCHECKED_CAST")
                    val sources = call.argument<List<List<String>>>("sources") // 每个频道的所有源
                    val isDlnaMode = call.argument<Boolean>("isDlnaMode") ?: false
                    val bufferStrength = call.argument<String>("bufferStrength") ?: "fast"
                    val showFps = call.argument<Boolean>("showFps") ?: true
                    
                    if (url != null) {
                        Log.d(TAG, "Launching native player fragment: $name (index $index of ${urls?.size ?: 0}, isDlna=$isDlnaMode, buffer=$bufferStrength, showFps=$showFps)")
                        try {
                            showPlayerFragment(url, name, index, urls, names, groups, sources, isDlnaMode, bufferStrength, showFps)
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
                "pause" -> {
                    playerFragment?.pause()
                    result.success(true)
                }
                "play" -> {
                    playerFragment?.play()
                    result.success(true)
                }
                "seekTo" -> {
                    val position = call.argument<Number>("position")?.toLong() ?: 0L
                    Log.d(TAG, "DLNA seekTo: position=$position, playerFragment=${playerFragment != null}")
                    playerFragment?.seekTo(position)
                    result.success(true)
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 100
                    playerFragment?.setVolume(volume)
                    result.success(true)
                }
                "getPlaybackState" -> {
                    val state = playerFragment?.getPlaybackState()
                    result.success(state)
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
        
        // Setup back press handling for Android 13+
        backPressedCallback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() {
                Log.d(TAG, "OnBackPressedCallback triggered")
                playerFragment?.handleBackKey()
            }
        }
        onBackPressedDispatcher.addCallback(this, backPressedCallback)
    }
    
    private fun showPlayerFragment(
        url: String,
        name: String,
        index: Int,
        urls: List<String>?,
        names: List<String>?,
        groups: List<String>?,
        sources: List<List<String>>?,
        isDlnaMode: Boolean = false,
        bufferStrength: String = "fast",
        showFps: Boolean = true
    ) {
        Log.d(TAG, "showPlayerFragment isDlnaMode=$isDlnaMode, bufferStrength=$bufferStrength, showFps=$showFps")
        
        // Enable back press callback when player is showing
        backPressedCallback.isEnabled = true
        
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
        
        // 将 sources 转换为 ArrayList<ArrayList<String>>
        val sourcesArrayList = sources?.map { ArrayList(it) }?.let { ArrayList(it) }
        
        playerFragment = NativePlayerFragment.newInstance(
            url,
            name,
            index,
            urls?.let { ArrayList(it) },
            names?.let { ArrayList(it) },
            groups?.let { ArrayList(it) },
            sourcesArrayList,
            isDlnaMode,
            bufferStrength,
            showFps
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
        
        // Disable back press callback when player is hidden
        backPressedCallback.isEnabled = false
        
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
        Log.d(TAG, "onKeyDown: keyCode=$keyCode, playerVisible=${playerContainer?.visibility == View.VISIBLE}")
        // If player is showing, let the fragment handle back key
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                playerFragment?.handleBackKey()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
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
    
    /**
     * Get EPG info for a channel from Flutter via MethodChannel
     */
    fun getEpgInfo(channelName: String, callback: (Map<String, Any?>?) -> Unit) {
        playerMethodChannel?.invokeMethod(
            "getEpgInfo",
            mapOf("channelName" to channelName, "epgId" to null),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    @Suppress("UNCHECKED_CAST")
                    callback(result as? Map<String, Any?>)
                }
                
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "getEpgInfo error: $errorCode - $errorMessage")
                    callback(null)
                }
                
                override fun notImplemented() {
                    Log.w(TAG, "getEpgInfo not implemented")
                    callback(null)
                }
            }
        )
    }
    
    /**
     * Install APK file using FileProvider
     */
    private fun installApk(filePath: String) {
        Log.d(TAG, "Installing APK: $filePath")
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("APK file not found: $filePath")
        }
        
        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ use FileProvider
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            // Older versions use file:// URI
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
        }
        
        startActivity(intent)
    }
}
