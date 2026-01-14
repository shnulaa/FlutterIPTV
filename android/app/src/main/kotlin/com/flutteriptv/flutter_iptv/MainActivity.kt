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
    private var multiScreenFragment: MultiScreenPlayerFragment? = null
    private var playerContainer: FrameLayout? = null
    private var playerMethodChannel: MethodChannel? = null
    
    private lateinit var backPressedCallback: OnBackPressedCallback
    
    // 记住分屏状态
    data class ScreenState(
        var channelIndex: Int = -1,
        var channelName: String = "",
        var channelUrl: String = ""
    )
    private var savedMultiScreenStates = Array(4) { ScreenState() }
    private var savedActiveScreenIndex = 0
    private var savedFocusedScreenIndex = 0
    
    // 记住频道数据（用于切换时传递）
    private var lastChannelUrls: List<String>? = null
    private var lastChannelNames: List<String>? = null
    private var lastChannelGroups: List<String>? = null
    private var lastChannelSources: List<List<String>>? = null
    private var lastChannelLogos: List<String>? = null
    private var lastVolumeBoostDb: Int = 0
    private var lastDefaultScreenPosition: Int = 1
    
    // 标记是否是从分屏退出到单频道播放（这种情况下单频道退出时不应覆盖分屏状态）
    private var isFromMultiScreen: Boolean = false

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
                    val logos = call.argument<List<String>>("logos") // 每个频道的台标URL
                    val isDlnaMode = call.argument<Boolean>("isDlnaMode") ?: false
                    val bufferStrength = call.argument<String>("bufferStrength") ?: "fast"
                    val showFps = call.argument<Boolean>("showFps") ?: true
                    val showClock = call.argument<Boolean>("showClock") ?: true
                    val showNetworkSpeed = call.argument<Boolean>("showNetworkSpeed") ?: true
                    val showVideoInfo = call.argument<Boolean>("showVideoInfo") ?: true
                    
                    if (url != null) {
                        Log.d(TAG, "Launching native player fragment: $name (index $index of ${urls?.size ?: 0}, isDlna=$isDlnaMode, logos=${logos?.size ?: 0})")
                        try {
                            showPlayerFragment(url, name, index, urls, names, groups, sources, logos, isDlnaMode, bufferStrength, showFps, showClock, showNetworkSpeed, showVideoInfo)
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
                "launchMultiScreen" -> {
                    val urls = call.argument<List<String>>("urls")
                    val names = call.argument<List<String>>("names")
                    val groups = call.argument<List<String>>("groups")
                    @Suppress("UNCHECKED_CAST")
                    val sources = call.argument<List<List<String>>>("sources")
                    val logos = call.argument<List<String>>("logos")
                    val initialChannelIndex = call.argument<Int>("initialChannelIndex") ?: 0
                    val volumeBoostDb = call.argument<Int>("volumeBoostDb") ?: 0
                    val defaultScreenPosition = call.argument<Int>("defaultScreenPosition") ?: 1
                    val restoreActiveIndex = call.argument<Int>("restoreActiveIndex") ?: -1
                    @Suppress("UNCHECKED_CAST")
                    val restoreScreenChannels = call.argument<List<Int?>>("restoreScreenChannels")
                    
                    if (urls != null && names != null && groups != null) {
                        Log.d(TAG, "Launching multi-screen player with ${urls.size} channels, initial=$initialChannelIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreActive=$restoreActiveIndex, restoreChannels=$restoreScreenChannels")
                        try {
                            showMultiScreenFragment(
                                urls, names, groups, sources, logos,
                                initialChannelIndex, volumeBoostDb, defaultScreenPosition,
                                restoreFromLocal = false,  // 不从本地恢复
                                restoreActiveIndex = restoreActiveIndex,  // 从 Flutter 传递的恢复参数
                                restoreScreenChannels = restoreScreenChannels
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to launch multi-screen player", e)
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_DATA", "Channel data is required", null)
                    }
                }
                "closeMultiScreen" -> {
                    hideMultiScreenFragment()
                    result.success(true)
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
                Log.d(TAG, "OnBackPressedCallback triggered, multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")
                // 优先处理分屏
                if (multiScreenFragment != null) {
                    multiScreenFragment?.handleBackKey()
                } else {
                    playerFragment?.handleBackKey()
                }
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
        logos: List<String>?,
        isDlnaMode: Boolean = false,
        bufferStrength: String = "fast",
        showFps: Boolean = true,
        showClock: Boolean = true,
        showNetworkSpeed: Boolean = true,
        showVideoInfo: Boolean = true
    ) {
        Log.d(TAG, "showPlayerFragment isDlnaMode=$isDlnaMode, bufferStrength=$bufferStrength, logos=${logos?.size ?: 0}")
        
        // 保存频道数据（用于切换到分屏时传递）
        lastChannelUrls = urls
        lastChannelNames = names
        lastChannelGroups = groups
        lastChannelSources = sources
        lastChannelLogos = logos
        
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
            showFps,
            showClock,
            showNetworkSpeed,
            showVideoInfo
        ).apply {
            onCloseListener = {
                runOnUiThread {
                    hidePlayerFragment()
                }
            }
            // 从普通播放器进入分屏模式
            onEnterMultiScreen = { channelIndex ->
                runOnUiThread {
                    if (urls != null && names != null && groups != null) {
                        // 先隐藏普通播放器
                        hidePlayerFragment()
                        // 启动分屏，恢复之前的状态
                        showMultiScreenFragment(
                            urls, names, groups, sources, logos,
                            channelIndex, 
                            lastVolumeBoostDb, 
                            lastDefaultScreenPosition,
                            restoreFromLocal = true  // 恢复之前的分屏状态（从本地保存）
                        )
                    }
                }
            }
        }
        
        supportFragmentManager.beginTransaction()
            .replace(playerContainer!!.id, playerFragment!!)
            .commit()
    }
    
    private fun hidePlayerFragment() {
        Log.d(TAG, "hidePlayerFragment: isFromMultiScreen=$isFromMultiScreen")
        
        // 获取当前播放的频道索引
        val currentChannelIndex = playerFragment?.getCurrentChannelIndex() ?: -1
        Log.d(TAG, "hidePlayerFragment: currentChannelIndex=$currentChannelIndex")
        
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
        
        // Notify Flutter that player closed with current channel index
        // 如果是从分屏退出到单频道播放的，传递 skipSave=true 告诉 Flutter 不要覆盖分屏状态
        playerMethodChannel?.invokeMethod("onPlayerClosed", mapOf(
            "channelIndex" to currentChannelIndex,
            "skipSave" to isFromMultiScreen
        ))
        
        // 重置标志
        isFromMultiScreen = false
    }
    
    private fun showMultiScreenFragment(
        urls: List<String>,
        names: List<String>,
        groups: List<String>,
        sources: List<List<String>>?,
        logos: List<String>?,
        initialChannelIndex: Int = 0,
        volumeBoostDb: Int = 0,
        defaultScreenPosition: Int = 1,
        restoreFromLocal: Boolean = false,  // 是否从本地保存的状态恢复（单屏切换到分屏）
        restoreActiveIndex: Int = -1,  // 从 Flutter 传递的恢复活动屏幕索引（首页继续播放）
        restoreScreenChannels: List<Int?>? = null  // 从 Flutter 传递的恢复频道索引（首页继续播放）
    ) {
        val shouldRestoreFromFlutter = restoreActiveIndex >= 0 && restoreScreenChannels != null
        Log.d(TAG, "showMultiScreenFragment with ${urls.size} channels, initial=$initialChannelIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreFromLocal=$restoreFromLocal, restoreFromFlutter=$shouldRestoreFromFlutter")
        
        // 保存频道数据
        lastChannelUrls = urls
        lastChannelNames = names
        lastChannelGroups = groups
        lastChannelSources = sources
        lastChannelLogos = logos
        lastVolumeBoostDb = volumeBoostDb
        lastDefaultScreenPosition = defaultScreenPosition
        
        // Enable back press callback
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
        
        val sourcesArrayList = sources?.map { ArrayList(it) }?.let { ArrayList(it) } ?: arrayListOf()
        val logosArrayList = logos?.let { ArrayList(it) } ?: arrayListOf()
        
        // 决定恢复状态的来源
        val savedStatesArrayList: ArrayList<ArrayList<String>>?
        val finalRestoreActiveIndex: Int
        val finalRestoreFocusedIndex: Int
        
        if (shouldRestoreFromFlutter && restoreScreenChannels != null) {
            // 从 Flutter 传递的状态恢复（首页继续播放）
            savedStatesArrayList = ArrayList(restoreScreenChannels.map { channelIndex ->
                if (channelIndex != null && channelIndex >= 0 && channelIndex < urls.size) {
                    arrayListOf(channelIndex.toString(), names.getOrElse(channelIndex) { "" }, urls.getOrElse(channelIndex) { "" })
                } else {
                    arrayListOf("-1", "", "")
                }
            })
            finalRestoreActiveIndex = restoreActiveIndex
            finalRestoreFocusedIndex = restoreActiveIndex
        } else if (restoreFromLocal) {
            // 从本地保存的状态恢复（单屏切换到分屏）
            savedStatesArrayList = ArrayList(savedMultiScreenStates.map { 
                arrayListOf(it.channelIndex.toString(), it.channelName, it.channelUrl)
            })
            finalRestoreActiveIndex = savedActiveScreenIndex
            finalRestoreFocusedIndex = savedFocusedScreenIndex
        } else {
            savedStatesArrayList = null
            finalRestoreActiveIndex = -1
            finalRestoreFocusedIndex = -1
        }
        
        multiScreenFragment = MultiScreenPlayerFragment.newInstance(
            ArrayList(urls),
            ArrayList(names),
            ArrayList(groups),
            sourcesArrayList,
            logosArrayList,
            initialChannelIndex,
            volumeBoostDb,
            defaultScreenPosition,
            finalRestoreActiveIndex,
            finalRestoreFocusedIndex,
            savedStatesArrayList
        ).apply {
            onCloseListener = {
                runOnUiThread {
                    // 直接隐藏分屏，hideMultiScreenFragment 会自动保存状态并通知 Flutter
                    hideMultiScreenFragment()
                }
            }
            onExitToNormalPlayer = { channelIndex ->
                runOnUiThread {
                    // 先保存分屏状态到本地（用于单屏切换回分屏时恢复）
                    saveMultiScreenState()
                    
                    // 保存分屏状态到 Flutter
                    val screenStates = mutableListOf<Int?>()
                    var activeIndex = 0
                    multiScreenFragment?.let { fragment ->
                        for (i in 0..3) {
                            val state = fragment.getScreenState(i)
                            screenStates.add(state?.channelIndex?.takeIf { it >= 0 })
                        }
                        activeIndex = fragment.getActiveScreenIndex()
                    }
                    
                    // 通知 Flutter 保存分屏状态
                    playerMethodChannel?.invokeMethod("onMultiScreenClosed", mapOf(
                        "screenStates" to screenStates,
                        "activeIndex" to activeIndex
                    ))
                    
                    // 标记是从分屏退出到单频道播放
                    isFromMultiScreen = true
                    
                    // 退出分屏后启动普通播放器
                    if (channelIndex >= 0 && channelIndex < urls.size) {
                        val url = if (sources != null && channelIndex < sources.size && sources[channelIndex].isNotEmpty()) {
                            sources[channelIndex][0]
                        } else {
                            urls[channelIndex]
                        }
                        val name = names.getOrElse(channelIndex) { "" }
                        val group = groups.getOrElse(channelIndex) { "" }
                        
                        // 先隐藏分屏（不通知 Flutter，因为上面已经通知了）
                        hideMultiScreenFragment(notifyFlutter = false)
                        
                        // 启动普通播放器
                        showPlayerFragment(
                            url, name, channelIndex,
                            urls, names, groups, sources, logos,
                            isDlnaMode = false,
                            bufferStrength = "fast",
                            showFps = true,
                            showClock = true,
                            showNetworkSpeed = true,
                            showVideoInfo = true
                        )
                    }
                }
            }
        }
        
        supportFragmentManager.beginTransaction()
            .replace(playerContainer!!.id, multiScreenFragment!!)
            .commit()
    }
    
    // 保存分屏状态
    private fun saveMultiScreenState() {
        multiScreenFragment?.let { fragment ->
            for (i in 0..3) {
                val state = fragment.getScreenState(i)
                savedMultiScreenStates[i] = ScreenState(
                    channelIndex = state?.channelIndex ?: -1,
                    channelName = state?.channelName ?: "",
                    channelUrl = state?.channelUrl ?: ""
                )
            }
            savedActiveScreenIndex = fragment.getActiveScreenIndex()
            savedFocusedScreenIndex = fragment.getFocusedScreenIndex()
            Log.d(TAG, "Saved multi-screen state: active=$savedActiveScreenIndex, focused=$savedFocusedScreenIndex")
        }
    }
    
    private fun hideMultiScreenFragment(notifyFlutter: Boolean = true) {
        Log.d(TAG, "hideMultiScreenFragment: notifyFlutter=$notifyFlutter")
        
        // 获取分屏状态用于通知 Flutter
        val screenStates = mutableListOf<Int?>()
        var activeIndex = 0
        multiScreenFragment?.let { fragment ->
            for (i in 0..3) {
                val state = fragment.getScreenState(i)
                screenStates.add(state?.channelIndex?.takeIf { it >= 0 })
            }
            activeIndex = fragment.getActiveScreenIndex()
        }
        
        backPressedCallback.isEnabled = false
        
        multiScreenFragment?.let {
            supportFragmentManager.beginTransaction()
                .remove(it)
                .commitAllowingStateLoss()
        }
        multiScreenFragment = null
        playerContainer?.visibility = View.GONE
        
        // Restore system UI
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        
        // Notify Flutter with multi-screen state (only if not transitioning to single player)
        if (notifyFlutter) {
            playerMethodChannel?.invokeMethod("onMultiScreenClosed", mapOf(
                "screenStates" to screenStates,
                "activeIndex" to activeIndex
            ))
        }
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        Log.d(TAG, "onKeyDown: keyCode=$keyCode, playerVisible=${playerContainer?.visibility == View.VISIBLE}, multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")
        
        // If multi-screen is showing, handle keys
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE) {
            // 返回键直接调用 handleBackKey
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                Log.d(TAG, "Back key pressed for multi-screen")
                val handled = multiScreenFragment?.handleBackKey() ?: false
                Log.d(TAG, "Multi-screen handleBackKey returned: $handled")
                return true  // 总是消费返回键
            }
            // 其他按键通过 view 的 key listener 处理
            if (event != null) {
                val handled = multiScreenFragment?.view?.dispatchKeyEvent(event) ?: false
                if (handled) return true
            }
        }
        
        // If player is showing, let the fragment handle back key
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                Log.d(TAG, "Back key pressed for player")
                playerFragment?.handleBackKey()
                return true
            }
        }
        
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        // If multi-screen is showing, forward key up events (except back key)
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE && event != null) {
            if (keyCode != KeyEvent.KEYCODE_BACK && keyCode != KeyEvent.KEYCODE_ESCAPE) {
                val handled = multiScreenFragment?.view?.dispatchKeyEvent(event) ?: false
                if (handled) return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        Log.d(TAG, "onBackPressed: multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")
        
        // If multi-screen is showing
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE) {
            Log.d(TAG, "Handling back press for multi-screen")
            multiScreenFragment?.handleBackKey()
            return
        }
        
        // If player is showing
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            Log.d(TAG, "Handling back press for player")
            playerFragment?.handleBackKey()
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
     * Toggle favorite status for a channel from native player
     */
    fun toggleFavorite(channelIndex: Int, callback: (Boolean?) -> Unit) {
        Log.d(TAG, "toggleFavorite: channelIndex=$channelIndex, playerMethodChannel=${playerMethodChannel != null}")
        if (playerMethodChannel == null) {
            Log.e(TAG, "toggleFavorite: playerMethodChannel is null")
            callback(null)
            return
        }
        playerMethodChannel?.invokeMethod(
            "toggleFavorite",
            mapOf("channelIndex" to channelIndex),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "toggleFavorite success: result=$result")
                    callback(result as? Boolean)
                }
                
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "toggleFavorite error: $errorCode - $errorMessage")
                    callback(null)
                }
                
                override fun notImplemented() {
                    Log.w(TAG, "toggleFavorite not implemented")
                    callback(null)
                }
            }
        )
    }
    
    /**
     * Check if a channel is favorite
     */
    fun isFavorite(channelIndex: Int, callback: (Boolean) -> Unit) {
        playerMethodChannel?.invokeMethod(
            "isFavorite",
            mapOf("channelIndex" to channelIndex),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    callback(result as? Boolean ?: false)
                }
                
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "isFavorite error: $errorCode - $errorMessage")
                    callback(false)
                }
                
                override fun notImplemented() {
                    Log.w(TAG, "isFavorite not implemented")
                    callback(false)
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
