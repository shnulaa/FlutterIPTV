package com.flutteriptv.flutter_iptv

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.pow

/**
 * TV端分屏播放器 Fragment
 * 逻辑参考 Windows 分屏：
 * 1. 方向键移动焦点
 * 2. OK键：空屏幕显示频道选择器，有频道则切换活动屏幕
 * 3. 长按OK键清空当前屏幕
 * 4. 返回键退出分屏（可转为普通播放）
 * 5. 支持音量增强
 */
class MultiScreenPlayerFragment : Fragment() {
    private val TAG = "MultiScreenPlayer"

    // 4个播放器实例
    private val players = arrayOfNulls<ExoPlayer>(4)
    private val playerViews = arrayOfNulls<PlayerView>(4)
    private val screenContainers = arrayOfNulls<View>(4)
    private val overlays = arrayOfNulls<View>(4)

    // 屏幕状态
    data class ScreenState(
        var channelIndex: Int = -1,
        var channelName: String = "",
        var channelUrl: String = "",
        var isLoading: Boolean = false,
        var hasError: Boolean = false,
        var videoWidth: Int = 0,
        var videoHeight: Int = 0
    )
    private val screenStates = Array(4) { ScreenState() }

    // 当前焦点和活动屏幕
    private var focusedScreenIndex = 0
    private var activeScreenIndex = 0  // 有声音的屏幕

    // 控制栏
    private lateinit var topBar: View
    private lateinit var bottomBar: View
    private var controlsVisible = true

    // 频道选择器
    private lateinit var channelSelectorPanel: View
    private lateinit var categoryList: RecyclerView
    private lateinit var channelGrid: RecyclerView
    private lateinit var selectorScreenTitle: TextView
    private lateinit var selectorCategoryTitle: TextView
    private lateinit var selectorChannelCount: TextView
    private var channelSelectorVisible = false
    private var targetScreenForSelector = 0
    private var selectedCategoryIndex = 0  // 0 = 全部频道
    private var categoryFocusIndex = 0
    private var channelFocusIndex = 0
    private var isCategoryFocused = true  // true = 分类列表有焦点, false = 频道网格有焦点

    // 频道数据
    private var channelUrls = arrayListOf<String>()
    private var channelNames = arrayListOf<String>()
    private var channelGroups = arrayListOf<String>()
    private var channelSources = arrayListOf<ArrayList<String>>()
    private var channelLogos = arrayListOf<String>()
    
    // 分类数据
    private var categories = arrayListOf<String>()  // 分类名称列表
    private var categoryChannelCounts = hashMapOf<String, Int>()  // 每个分类的频道数量
    
    // 初始频道索引（从频道列表进入时选择的频道）
    private var initialChannelIndex = 0
    
    // 默认屏幕位置（1-4，对应四个屏幕）
    private var defaultScreenPosition = 1
    
    // 音量增强
    private var volumeBoostDb = 0
    private var baseVolume = 1.0f

    // Handler
    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private val CONTROLS_HIDE_DELAY = 4000L
    
    // 长按检测
    private var okKeyDownTime = 0L
    private val LONG_PRESS_THRESHOLD = 500L
    private var longPressHandled = false
    private var ignoreInitialKeyEvents = true  // 忽略初始按键事件
    private var initTime = 0L  // 初始化时间

    // 回调
    var onCloseListener: (() -> Unit)? = null
    var onExitToNormalPlayer: ((Int) -> Unit)? = null  // 退出到普通播放器，传递当前频道索引

    companion object {
        private const val ARG_CHANNEL_URLS = "channel_urls"
        private const val ARG_CHANNEL_NAMES = "channel_names"
        private const val ARG_CHANNEL_GROUPS = "channel_groups"
        private const val ARG_CHANNEL_SOURCES = "channel_sources"
        private const val ARG_CHANNEL_LOGOS = "channel_logos"
        private const val ARG_INITIAL_CHANNEL_INDEX = "initial_channel_index"
        private const val ARG_VOLUME_BOOST_DB = "volume_boost_db"
        private const val ARG_DEFAULT_SCREEN_POSITION = "default_screen_position"
        private const val ARG_RESTORE_ACTIVE_INDEX = "restore_active_index"
        private const val ARG_RESTORE_FOCUSED_INDEX = "restore_focused_index"
        private const val ARG_RESTORE_SCREEN_STATES = "restore_screen_states"
        
        // 静态图片缓存，在 Fragment 之间共享
        private val imageCache = hashMapOf<String, Bitmap?>()
        private val loadingUrls = hashSetOf<String>()

        fun newInstance(
            channelUrls: ArrayList<String>,
            channelNames: ArrayList<String>,
            channelGroups: ArrayList<String>,
            channelSources: ArrayList<ArrayList<String>>,
            channelLogos: ArrayList<String>,
            initialChannelIndex: Int = 0,
            volumeBoostDb: Int = 0,
            defaultScreenPosition: Int = 1,
            restoreActiveIndex: Int = -1,
            restoreFocusedIndex: Int = -1,
            restoreScreenStates: ArrayList<ArrayList<String>>? = null
        ): MultiScreenPlayerFragment {
            return MultiScreenPlayerFragment().apply {
                arguments = Bundle().apply {
                    putStringArrayList(ARG_CHANNEL_URLS, channelUrls)
                    putStringArrayList(ARG_CHANNEL_NAMES, channelNames)
                    putStringArrayList(ARG_CHANNEL_GROUPS, channelGroups)
                    putSerializable(ARG_CHANNEL_SOURCES, channelSources)
                    putStringArrayList(ARG_CHANNEL_LOGOS, channelLogos)
                    putInt(ARG_INITIAL_CHANNEL_INDEX, initialChannelIndex)
                    putInt(ARG_VOLUME_BOOST_DB, volumeBoostDb)
                    putInt(ARG_DEFAULT_SCREEN_POSITION, defaultScreenPosition)
                    putInt(ARG_RESTORE_ACTIVE_INDEX, restoreActiveIndex)
                    putInt(ARG_RESTORE_FOCUSED_INDEX, restoreFocusedIndex)
                    restoreScreenStates?.let { putSerializable(ARG_RESTORE_SCREEN_STATES, it) }
                }
            }
        }
    }
    
    // 公开方法供 MainActivity 获取状态
    fun getScreenState(index: Int): ScreenState? {
        return if (index in 0..3) screenStates[index] else null
    }
    
    fun getActiveScreenIndex(): Int = activeScreenIndex
    fun getFocusedScreenIndex(): Int = focusedScreenIndex

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_multi_screen_player, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "onViewCreated")
        
        // 记录初始化时间，用于忽略初始按键事件
        initTime = System.currentTimeMillis()
        ignoreInitialKeyEvents = true

        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // 解析参数
        var restoreActiveIndex = -1
        var restoreFocusedIndex = -1
        var restoreScreenStates: ArrayList<ArrayList<String>>? = null
        
        arguments?.let {
            channelUrls = it.getStringArrayList(ARG_CHANNEL_URLS) ?: arrayListOf()
            channelNames = it.getStringArrayList(ARG_CHANNEL_NAMES) ?: arrayListOf()
            channelGroups = it.getStringArrayList(ARG_CHANNEL_GROUPS) ?: arrayListOf()
            @Suppress("UNCHECKED_CAST")
            channelSources = it.getSerializable(ARG_CHANNEL_SOURCES) as? ArrayList<ArrayList<String>> ?: arrayListOf()
            channelLogos = it.getStringArrayList(ARG_CHANNEL_LOGOS) ?: arrayListOf()
            initialChannelIndex = it.getInt(ARG_INITIAL_CHANNEL_INDEX, 0)
            volumeBoostDb = it.getInt(ARG_VOLUME_BOOST_DB, 0)
            defaultScreenPosition = it.getInt(ARG_DEFAULT_SCREEN_POSITION, 1)
            restoreActiveIndex = it.getInt(ARG_RESTORE_ACTIVE_INDEX, -1)
            restoreFocusedIndex = it.getInt(ARG_RESTORE_FOCUSED_INDEX, -1)
            @Suppress("UNCHECKED_CAST")
            restoreScreenStates = it.getSerializable(ARG_RESTORE_SCREEN_STATES) as? ArrayList<ArrayList<String>>
        }

        Log.d(TAG, "Loaded ${channelUrls.size} channels, initial=$initialChannelIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreActive=$restoreActiveIndex")

        // 初始化视图
        initViews(view)

        // 初始化播放器
        for (i in 0..3) {
            initializePlayer(i)
        }

        // 设置按键监听
        view.isFocusableInTouchMode = true
        view.requestFocus()
        view.setOnKeyListener { _, keyCode, event ->
            when (event.action) {
                KeyEvent.ACTION_DOWN -> handleKeyDown(keyCode, event)
                KeyEvent.ACTION_UP -> handleKeyUp(keyCode, event)
                else -> false
            }
        }

        // 检查是否需要恢复状态
        if (restoreActiveIndex >= 0 && restoreScreenStates != null) {
            Log.d(TAG, "Restoring multi-screen state")
            // 恢复之前的分屏状态
            for (i in 0..3) {
                val stateData = restoreScreenStates?.getOrNull(i)
                if (stateData != null && stateData.size >= 3) {
                    val channelIndex = stateData[0].toIntOrNull() ?: -1
                    if (channelIndex >= 0 && channelIndex < channelUrls.size) {
                        playChannelOnScreen(i, channelIndex)
                    }
                }
            }
            activeScreenIndex = restoreActiveIndex.coerceIn(0, 3)
            focusedScreenIndex = restoreFocusedIndex.coerceIn(0, 3)
            // 确保活动屏幕有声音
            for (i in 0..3) {
                players[i]?.volume = if (i == activeScreenIndex) getEffectiveVolume() else 0f
            }
        } else {
            // 默认在指定屏幕位置播放初始频道（参考Windows分屏逻辑）
            // defaultScreenPosition: 1=左上, 2=右上, 3=左下, 4=右下
            if (initialChannelIndex >= 0 && initialChannelIndex < channelUrls.size) {
                val screenIndex = (defaultScreenPosition - 1).coerceIn(0, 3)
                // 先设置活动屏幕索引，确保播放时有声音
                activeScreenIndex = screenIndex
                focusedScreenIndex = screenIndex
                // 然后播放频道
                playChannelOnScreen(screenIndex, initialChannelIndex)
                // 确保该屏幕有声音
                players[screenIndex]?.volume = getEffectiveVolume()
            }
        }

        // 更新UI
        updateAllScreenOverlays()
        showControls()
    }

    private fun initViews(view: View) {
        // 控制栏
        topBar = view.findViewById(R.id.top_bar)
        bottomBar = view.findViewById(R.id.bottom_bar)

        // 频道选择器
        channelSelectorPanel = view.findViewById(R.id.channel_selector_panel)
        categoryList = view.findViewById(R.id.selector_category_list)
        channelGrid = view.findViewById(R.id.selector_channel_grid)
        selectorScreenTitle = view.findViewById(R.id.selector_screen_title)
        selectorCategoryTitle = view.findViewById(R.id.selector_category_title)
        selectorChannelCount = view.findViewById(R.id.selector_channel_count)

        // 初始化分类数据
        buildCategoryData()

        // 设置分类列表
        categoryList.layoutManager = LinearLayoutManager(requireContext())
        categoryList.adapter = CategoryAdapter()

        // 设置频道网格
        channelGrid.layoutManager = GridLayoutManager(requireContext(), 5)
        channelGrid.adapter = ChannelAdapter()

        // 4个屏幕
        val containerIds = arrayOf(R.id.screen_container_0, R.id.screen_container_1, R.id.screen_container_2, R.id.screen_container_3)
        val playerViewIds = arrayOf(R.id.player_view_0, R.id.player_view_1, R.id.player_view_2, R.id.player_view_3)
        val overlayIds = arrayOf(R.id.overlay_0, R.id.overlay_1, R.id.overlay_2, R.id.overlay_3)

        for (i in 0..3) {
            screenContainers[i] = view.findViewById(containerIds[i])
            playerViews[i] = view.findViewById(playerViewIds[i])
            overlays[i] = view.findViewById(overlayIds[i])

            // 设置屏幕编号
            overlays[i]?.findViewById<TextView>(R.id.screen_number)?.text = "屏幕 ${i + 1}"
            overlays[i]?.findViewById<TextView>(R.id.badge_number)?.text = "${i + 1}"

            playerViews[i]?.useController = false
        }
    }

    private fun initializePlayer(index: Int) {
        Log.d(TAG, "Initializing player $index")

        val renderersFactory = DefaultRenderersFactory(requireContext())
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15000, 30000, 500, 1500)
            .build()

        players[index] = ExoPlayer.Builder(requireContext(), renderersFactory)
            .setLoadControl(loadControl)
            .build().also { player ->
                playerViews[index]?.player = player
                player.playWhenReady = true
                player.repeatMode = Player.REPEAT_MODE_OFF
                // 只有活动屏幕有声音
                player.volume = if (index == activeScreenIndex) getEffectiveVolume() else 0f

                player.addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(playbackState: Int) {
                        when (playbackState) {
                            Player.STATE_BUFFERING -> {
                                screenStates[index].isLoading = true
                                screenStates[index].hasError = false
                                updateScreenOverlay(index)
                            }
                            Player.STATE_READY -> {
                                screenStates[index].isLoading = false
                                screenStates[index].hasError = false
                                updateScreenOverlay(index)
                            }
                            Player.STATE_ENDED, Player.STATE_IDLE -> {
                                screenStates[index].isLoading = false
                                updateScreenOverlay(index)
                            }
                        }
                    }

                    override fun onVideoSizeChanged(videoSize: VideoSize) {
                        screenStates[index].videoWidth = videoSize.width
                        screenStates[index].videoHeight = videoSize.height
                        updateScreenOverlay(index)
                    }

                    override fun onPlayerError(error: PlaybackException) {
                        Log.e(TAG, "Player $index error: ${error.message}")
                        screenStates[index].isLoading = false
                        screenStates[index].hasError = true
                        updateScreenOverlay(index)
                    }
                })
            }
    }
    
    // 计算有效音量（包含增强）
    private fun getEffectiveVolume(): Float {
        if (volumeBoostDb == 0) {
            return baseVolume
        }
        // 将 dB 转换为线性增益
        val boostFactor = 10.0.pow(volumeBoostDb / 20.0)
        return (baseVolume * boostFactor).coerceIn(0.0, 2.0).toFloat()
    }

    private fun playChannelOnScreen(screenIndex: Int, channelIndex: Int) {
        if (screenIndex < 0 || screenIndex > 3) return
        if (channelIndex < 0 || channelIndex >= channelUrls.size) return

        val url = if (channelIndex < channelSources.size && channelSources[channelIndex].isNotEmpty()) {
            channelSources[channelIndex][0]
        } else {
            channelUrls[channelIndex]
        }

        val name = channelNames.getOrElse(channelIndex) { "Channel ${channelIndex + 1}" }

        Log.d(TAG, "Playing channel '$name' on screen $screenIndex")

        screenStates[screenIndex].apply {
            this.channelIndex = channelIndex
            this.channelName = name
            this.channelUrl = url
            this.isLoading = true
            this.hasError = false
            this.videoWidth = 0
            this.videoHeight = 0
        }

        updateScreenOverlay(screenIndex)

        players[screenIndex]?.let { player ->
            player.setMediaItem(MediaItem.fromUri(url))
            player.prepare()
        }
    }

    private fun clearScreen(screenIndex: Int) {
        if (screenIndex < 0 || screenIndex > 3) return

        Log.d(TAG, "Clearing screen $screenIndex")

        players[screenIndex]?.stop()
        players[screenIndex]?.clearMediaItems()

        screenStates[screenIndex].apply {
            channelIndex = -1
            channelName = ""
            channelUrl = ""
            isLoading = false
            hasError = false
            videoWidth = 0
            videoHeight = 0
        }

        updateScreenOverlay(screenIndex)
    }

    private fun setActiveScreen(index: Int) {
        if (index < 0 || index > 3) return
        if (screenStates[index].channelIndex < 0) return  // 空屏幕不能设为活动
        if (index == activeScreenIndex) return

        Log.d(TAG, "Setting active screen to $index")

        // 静音旧的活动屏幕
        players[activeScreenIndex]?.volume = 0f

        activeScreenIndex = index

        // 取消静音新的活动屏幕（使用有效音量）
        players[activeScreenIndex]?.volume = getEffectiveVolume()

        updateAllScreenOverlays()
        
        // 显示提示
        Toast.makeText(requireContext(), "屏幕 ${index + 1} 已激活", Toast.LENGTH_SHORT).show()
    }

    private fun updateAllScreenOverlays() {
        for (i in 0..3) {
            updateScreenOverlay(i)
        }
    }

    private fun updateScreenOverlay(index: Int) {
        val overlay = overlays[index] ?: return
        val state = screenStates[index]
        val isFocused = index == focusedScreenIndex
        val isActive = index == activeScreenIndex && state.channelIndex >= 0

        activity?.runOnUiThread {
            // 只使用一个选择框（焦点框），焦点屏幕显示
            val focusBorder = overlay.findViewById<View>(R.id.focus_border)
            focusBorder?.visibility = if (isFocused) View.VISIBLE else View.GONE

            // 隐藏活动边框（不再使用）
            val activeBorder = overlay.findViewById<View>(R.id.active_border)
            activeBorder?.visibility = View.GONE

            // 隐藏屏幕编号徽章
            val badge = overlay.findViewById<View>(R.id.screen_badge)
            badge?.visibility = View.GONE

            // 加载/空/错误/播放状态
            val loadingIndicator = overlay.findViewById<ProgressBar>(R.id.loading_indicator)
            val emptyPlaceholder = overlay.findViewById<View>(R.id.empty_placeholder)
            val errorContainer = overlay.findViewById<View>(R.id.error_container)
            val bottomInfo = overlay.findViewById<View>(R.id.bottom_info)
            val channelNameText = overlay.findViewById<TextView>(R.id.channel_name)
            val infoContainer = overlay.findViewById<View>(R.id.info_container)
            val resolutionText = overlay.findViewById<TextView>(R.id.resolution_text)
            val audioIcon = overlay.findViewById<ImageView>(R.id.audio_icon)
            val emptyHint = overlay.findViewById<TextView>(R.id.empty_hint)
            val emptyIcon = overlay.findViewById<ImageView>(R.id.empty_icon)

            when {
                state.channelIndex < 0 -> {
                    // 空屏幕
                    emptyPlaceholder?.visibility = View.VISIBLE
                    loadingIndicator?.visibility = View.GONE
                    errorContainer?.visibility = View.GONE
                    bottomInfo?.visibility = View.GONE
                    infoContainer?.visibility = View.GONE
                    emptyHint?.text = if (isFocused) "按OK键添加频道" else ""
                    emptyIcon?.setColorFilter(if (isFocused) 0xFF00BCD4.toInt() else 0xFF666666.toInt())
                }
                state.hasError -> {
                    emptyPlaceholder?.visibility = View.GONE
                    loadingIndicator?.visibility = View.GONE
                    errorContainer?.visibility = View.VISIBLE
                    bottomInfo?.visibility = View.VISIBLE
                    channelNameText?.text = state.channelName
                    infoContainer?.visibility = View.GONE
                }
                state.isLoading -> {
                    emptyPlaceholder?.visibility = View.GONE
                    loadingIndicator?.visibility = View.VISIBLE
                    errorContainer?.visibility = View.GONE
                    bottomInfo?.visibility = View.VISIBLE
                    channelNameText?.text = state.channelName
                    infoContainer?.visibility = View.GONE
                }
                else -> {
                    emptyPlaceholder?.visibility = View.GONE
                    loadingIndicator?.visibility = View.GONE
                    errorContainer?.visibility = View.GONE
                    bottomInfo?.visibility = View.VISIBLE
                    channelNameText?.text = state.channelName

                    // 显示分辨率和声音图标
                    if (state.videoWidth > 0 && state.videoHeight > 0) {
                        infoContainer?.visibility = View.VISIBLE
                        resolutionText?.text = "${state.videoWidth}x${state.videoHeight}"
                        // 声音图标显示在分辨率后面
                        audioIcon?.visibility = if (isActive) View.VISIBLE else View.GONE
                    } else {
                        // 即使没有分辨率信息，如果是活动屏幕也显示声音图标
                        if (isActive) {
                            infoContainer?.visibility = View.VISIBLE
                            resolutionText?.text = ""
                            audioIcon?.visibility = View.VISIBLE
                        } else {
                            infoContainer?.visibility = View.GONE
                        }
                    }
                }
            }
        }
    }

    // ==================== 按键处理 ====================
    
    private fun handleKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode, channelSelectorVisible=$channelSelectorVisible, ignoreInitial=$ignoreInitialKeyEvents")
        
        // 忽略初始化后500ms内的按键事件（防止从普通播放器长按进入时触发）
        if (ignoreInitialKeyEvents) {
            if (System.currentTimeMillis() - initTime < 500) {
                Log.d(TAG, "Ignoring initial key event")
                return true
            }
            ignoreInitialKeyEvents = false
        }
        
        // 如果频道选择器显示中，由它处理按键
        if (channelSelectorVisible) {
            return handleSelectorKeyDown(keyCode, event)
        }
        
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                // 记录按下时间，用于检测长按
                if (okKeyDownTime == 0L) {
                    okKeyDownTime = System.currentTimeMillis()
                    longPressHandled = false
                }
                
                // 检查是否达到长按阈值
                handler.postDelayed({
                    if (okKeyDownTime > 0 && !longPressHandled) {
                        val pressDuration = System.currentTimeMillis() - okKeyDownTime
                        if (pressDuration >= LONG_PRESS_THRESHOLD) {
                            longPressHandled = true
                            // 长按：清空当前屏幕
                            handleLongPressOk()
                        }
                    }
                }, LONG_PRESS_THRESHOLD)
                
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_UP -> {
                moveFocus(0, -1)
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                moveFocus(0, 1)
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                moveFocus(-1, 0)
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                moveFocus(1, 0)
                return true
            }
            
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                return handleBackKey()
            }
            
            KeyEvent.KEYCODE_CHANNEL_UP, KeyEvent.KEYCODE_PAGE_UP -> {
                // 上一个频道（在当前焦点屏幕）
                switchChannelOnFocusedScreen(-1)
                return true
            }
            
            KeyEvent.KEYCODE_CHANNEL_DOWN, KeyEvent.KEYCODE_PAGE_DOWN -> {
                // 下一个频道（在当前焦点屏幕）
                switchChannelOnFocusedScreen(1)
                return true
            }
            
            KeyEvent.KEYCODE_VOLUME_UP -> {
                // 音量增加（系统处理）
                return false
            }
            
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                // 音量减少（系统处理）
                return false
            }
            
            KeyEvent.KEYCODE_MENU, KeyEvent.KEYCODE_INFO -> {
                // 显示/隐藏控制栏
                toggleControls()
                return true
            }
        }
        
        // 显示控制栏
        showControls()
        return false
    }
    
    private fun handleKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                val pressDuration = System.currentTimeMillis() - okKeyDownTime
                okKeyDownTime = 0L
                
                // 如果已经处理了长按，不再处理短按
                if (longPressHandled) {
                    longPressHandled = false
                    return true
                }
                
                // 短按：切换活动屏幕（有声音的屏幕）
                if (pressDuration < LONG_PRESS_THRESHOLD) {
                    handleShortPressOk()
                }
                
                return true
            }
        }
        return false
    }
    
    // 移动焦点（移动到有频道的屏幕时自动切换声音）
    private fun moveFocus(dx: Int, dy: Int) {
        // 计算新的焦点位置
        // 屏幕布局: 0 1
        //          2 3
        val col = focusedScreenIndex % 2
        val row = focusedScreenIndex / 2
        
        var newCol = col + dx
        var newRow = row + dy
        
        // 边界检查
        newCol = newCol.coerceIn(0, 1)
        newRow = newRow.coerceIn(0, 1)
        
        val newIndex = newRow * 2 + newCol
        
        if (newIndex != focusedScreenIndex) {
            focusedScreenIndex = newIndex
            
            // 如果新焦点屏幕有频道，自动切换声音到该屏幕
            if (screenStates[newIndex].channelIndex >= 0) {
                setActiveScreen(newIndex)
            }
            
            updateAllScreenOverlays()
            showControls()
        }
    }
    
    // 短按OK：
    // - 如果是空屏幕，显示频道选择器（类似Windows点击空屏幕）
    // - 如果有频道，切换为活动屏幕（有声音）
    private fun handleShortPressOk() {
        val currentState = screenStates[focusedScreenIndex]
        
        if (currentState.channelIndex < 0) {
            // 空屏幕：显示频道选择器
            showChannelSelector(focusedScreenIndex)
        } else {
            // 有频道：切换为活动屏幕
            setActiveScreen(focusedScreenIndex)
        }
        showControls()
    }
    
    // 长按OK：清空当前屏幕
    private fun handleLongPressOk() {
        Log.d(TAG, "Long press OK - clearing screen $focusedScreenIndex")
        
        // 如果要清空的是活动屏幕，先切换活动屏幕到其他有内容的屏幕
        if (focusedScreenIndex == activeScreenIndex) {
            for (i in 0..3) {
                if (i != focusedScreenIndex && screenStates[i].channelIndex >= 0) {
                    setActiveScreen(i)
                    break
                }
            }
        }
        
        clearScreen(focusedScreenIndex)
        Toast.makeText(requireContext(), "屏幕 ${focusedScreenIndex + 1} 已清空", Toast.LENGTH_SHORT).show()
    }
    
    // 在焦点屏幕切换频道
    private fun switchChannelOnFocusedScreen(direction: Int) {
        val currentState = screenStates[focusedScreenIndex]
        val currentIndex = if (currentState.channelIndex >= 0) {
            currentState.channelIndex
        } else {
            // 如果当前屏幕是空的，从活动屏幕的频道开始
            screenStates[activeScreenIndex].channelIndex.coerceAtLeast(0)
        }
        
        val newIndex = (currentIndex + direction + channelUrls.size) % channelUrls.size
        playChannelOnScreen(focusedScreenIndex, newIndex)
        showControls()
    }
    
    // 返回键处理
    fun handleBackKey(): Boolean {
        Log.d(TAG, "handleBackKey called, channelSelectorVisible=$channelSelectorVisible")
        
        // 如果频道选择器显示中，先关闭它
        if (channelSelectorVisible) {
            Log.d(TAG, "Closing channel selector")
            hideChannelSelector()
            return true
        }
        
        // 检查是否有活动屏幕正在播放
        val activeState = screenStates[activeScreenIndex]
        Log.d(TAG, "Active screen channel index: ${activeState.channelIndex}")
        
        if (activeState.channelIndex >= 0) {
            // 有频道在播放，退出分屏进入普通播放模式
            Log.d(TAG, "Exiting to normal player with channel: ${activeState.channelIndex}")
            onExitToNormalPlayer?.invoke(activeState.channelIndex)
        } else {
            // 没有播放内容，直接关闭分屏返回频道列表
            Log.d(TAG, "No active channel, closing multi-screen")
            onCloseListener?.invoke()
        }
        return true
    }
    
    private fun showExitDialog() {
        val activeState = screenStates[activeScreenIndex]
        val channelName = activeState.channelName
        
        android.app.AlertDialog.Builder(requireContext())
            .setTitle("退出分屏")
            .setMessage("当前正在播放: $channelName")
            .setPositiveButton("继续播放") { _, _ ->
                // 退出分屏，转为普通播放器继续播放
                onExitToNormalPlayer?.invoke(activeState.channelIndex)
                onCloseListener?.invoke()
            }
            .setNegativeButton("关闭") { _, _ ->
                onCloseListener?.invoke()
            }
            .setNeutralButton("取消", null)
            .show()
    }
    
    // ==================== 控制栏 ====================
    
    private fun showControls() {
        if (!controlsVisible) {
            controlsVisible = true
            topBar.visibility = View.VISIBLE
            bottomBar.visibility = View.VISIBLE
        }
        
        // 重置隐藏定时器
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        hideControlsRunnable = Runnable {
            hideControls()
        }
        handler.postDelayed(hideControlsRunnable!!, CONTROLS_HIDE_DELAY)
    }
    
    private fun hideControls() {
        controlsVisible = false
        topBar.visibility = View.GONE
        bottomBar.visibility = View.GONE
    }
    
    private fun toggleControls() {
        if (controlsVisible) {
            hideControls()
        } else {
            showControls()
        }
    }
    
    // ==================== 生命周期 ====================
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
        
        // 恢复播放
        for (i in 0..3) {
            if (screenStates[i].channelIndex >= 0) {
                players[i]?.play()
            }
        }
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause")
        
        // 暂停所有播放
        for (i in 0..3) {
            players[i]?.pause()
        }
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        Log.d(TAG, "onDestroyView")
        
        // 取消定时器
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        
        // 释放所有播放器
        for (i in 0..3) {
            players[i]?.release()
            players[i] = null
        }
        
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    
    // ==================== 公共方法 ====================
    
    // 设置音量增强
    fun setVolumeBoost(db: Int) {
        volumeBoostDb = db
        // 更新活动屏幕的音量
        players[activeScreenIndex]?.volume = getEffectiveVolume()
    }
    
    // ==================== 图片加载 ====================
    
    // 使用顶部 companion object 中的静态缓存
    private val imageExecutor = Executors.newFixedThreadPool(8)
    
    private fun loadImageAsync(url: String, imageView: ImageView, defaultView: ImageView) {
        if (url.isEmpty()) {
            imageView.visibility = View.GONE
            defaultView.visibility = View.VISIBLE
            return
        }
        
        // 检查缓存
        if (imageCache.containsKey(url)) {
            val bitmap = imageCache[url]
            if (bitmap != null) {
                imageView.setImageBitmap(bitmap)
                imageView.visibility = View.VISIBLE
                defaultView.visibility = View.GONE
            } else {
                imageView.visibility = View.GONE
                defaultView.visibility = View.VISIBLE
            }
            return
        }
        
        // 显示默认图标，等待加载
        imageView.visibility = View.GONE
        defaultView.visibility = View.VISIBLE
        
        // 避免重复加载
        synchronized(loadingUrls) {
            if (loadingUrls.contains(url)) return
            loadingUrls.add(url)
        }
        
        // 异步加载
        imageExecutor.execute {
            try {
                val connection = URL(url).openConnection()
                connection.connectTimeout = 3000
                connection.readTimeout = 3000
                val inputStream = connection.getInputStream()
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                
                imageCache[url] = bitmap
                
                handler.post {
                    if (bitmap != null) {
                        imageView.setImageBitmap(bitmap)
                        imageView.visibility = View.VISIBLE
                        defaultView.visibility = View.GONE
                    }
                }
            } catch (e: Exception) {
                imageCache[url] = null
            } finally {
                synchronized(loadingUrls) {
                    loadingUrls.remove(url)
                }
            }
        }
    }
    
    // 预加载可见范围内的台标
    private fun preloadLogos(startIndex: Int, count: Int) {
        val filteredChannels = getFilteredChannels()
        val endIndex = minOf(startIndex + count, filteredChannels.size)
        
        for (i in startIndex until endIndex) {
            val channelIndex = filteredChannels[i]
            val logoUrl = channelLogos.getOrElse(channelIndex) { "" }
            if (logoUrl.isNotEmpty() && !imageCache.containsKey(logoUrl)) {
                val shouldLoad = synchronized(loadingUrls) {
                    if (loadingUrls.contains(logoUrl)) {
                        false
                    } else {
                        loadingUrls.add(logoUrl)
                        true
                    }
                }
                
                if (shouldLoad) {
                    imageExecutor.execute {
                        try {
                            val connection = URL(logoUrl).openConnection()
                            connection.connectTimeout = 3000
                            connection.readTimeout = 3000
                            val inputStream = connection.getInputStream()
                            val bitmap = BitmapFactory.decodeStream(inputStream)
                            inputStream.close()
                            imageCache[logoUrl] = bitmap
                        } catch (e: Exception) {
                            imageCache[logoUrl] = null
                        } finally {
                            synchronized(loadingUrls) {
                                loadingUrls.remove(logoUrl)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ==================== 频道选择器 ====================
    
    private fun buildCategoryData() {
        categories.clear()
        categoryChannelCounts.clear()
        
        // 统计每个分类的频道数量
        for (group in channelGroups) {
            val count = categoryChannelCounts[group] ?: 0
            categoryChannelCounts[group] = count + 1
        }
        
        // 构建分类列表（去重）
        val uniqueGroups = channelGroups.distinct()
        categories.addAll(uniqueGroups)
        
        Log.d(TAG, "Built category data: ${categories.size} categories")
    }
    
    private fun showChannelSelector(screenIndex: Int) {
        targetScreenForSelector = screenIndex
        channelSelectorVisible = true
        selectedCategoryIndex = 0
        categoryFocusIndex = 0
        channelFocusIndex = 0
        isCategoryFocused = true
        
        // 更新标题
        selectorScreenTitle.text = "屏幕 ${screenIndex + 1}"
        
        // 刷新列表
        categoryList.adapter?.notifyDataSetChanged()
        updateChannelGrid()
        
        // 预加载前20个台标
        preloadLogos(0, 20)
        
        // 显示面板
        channelSelectorPanel.visibility = View.VISIBLE
        
        // 隐藏控制栏
        hideControls()
    }
    
    private fun hideChannelSelector() {
        channelSelectorVisible = false
        channelSelectorPanel.visibility = View.GONE
        showControls()
    }
    
    private fun updateChannelGrid() {
        val categoryName = if (selectedCategoryIndex == 0) {
            selectorCategoryTitle.text = "全部频道"
            selectorChannelCount.text = "${channelUrls.size} 个频道"
            null
        } else {
            val name = categories[selectedCategoryIndex - 1]
            selectorCategoryTitle.text = name
            val count = categoryChannelCounts[name] ?: 0
            selectorChannelCount.text = "$count 个频道"
            name
        }
        
        channelGrid.adapter?.notifyDataSetChanged()
        
        // 预加载当前分类的前20个台标
        preloadLogos(0, 20)
    }
    
    private fun getFilteredChannels(): List<Int> {
        return if (selectedCategoryIndex == 0) {
            // 全部频道
            channelUrls.indices.toList()
        } else {
            // 按分类过滤
            val categoryName = categories[selectedCategoryIndex - 1]
            channelUrls.indices.filter { channelGroups.getOrNull(it) == categoryName }
        }
    }
    
    private fun handleSelectorKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d(TAG, "handleSelectorKeyDown: keyCode=$keyCode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                Log.d(TAG, "Selector: Back key pressed, hiding selector")
                hideChannelSelector()
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (!isCategoryFocused) {
                    // 频道网格内向左移动
                    val columns = 5
                    if (channelFocusIndex % columns > 0) {
                        channelFocusIndex--
                        channelGrid.adapter?.notifyDataSetChanged()
                        channelGrid.scrollToPosition(channelFocusIndex)
                    } else {
                        // 在第一列，切换到分类列表
                        isCategoryFocused = true
                        categoryList.adapter?.notifyDataSetChanged()
                        channelGrid.adapter?.notifyDataSetChanged()
                    }
                }
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (isCategoryFocused) {
                    // 从分类列表切换到频道网格
                    isCategoryFocused = false
                    channelFocusIndex = 0
                    categoryList.adapter?.notifyDataSetChanged()
                    channelGrid.adapter?.notifyDataSetChanged()
                    channelGrid.scrollToPosition(0)
                } else {
                    // 频道网格内向右移动
                    val columns = 5
                    val filteredChannels = getFilteredChannels()
                    if (channelFocusIndex % columns < columns - 1 && channelFocusIndex + 1 < filteredChannels.size) {
                        channelFocusIndex++
                        channelGrid.adapter?.notifyDataSetChanged()
                        channelGrid.scrollToPosition(channelFocusIndex)
                    }
                }
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (isCategoryFocused) {
                    // 分类列表向上
                    if (categoryFocusIndex > 0) {
                        categoryFocusIndex--
                        categoryList.adapter?.notifyDataSetChanged()
                        categoryList.scrollToPosition(categoryFocusIndex)
                    }
                } else {
                    // 频道网格向上
                    val columns = 5
                    if (channelFocusIndex >= columns) {
                        channelFocusIndex -= columns
                        channelGrid.adapter?.notifyDataSetChanged()
                        channelGrid.scrollToPosition(channelFocusIndex)
                    }
                }
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (isCategoryFocused) {
                    // 分类列表向下
                    val maxIndex = categories.size  // +1 for "全部频道"
                    if (categoryFocusIndex < maxIndex) {
                        categoryFocusIndex++
                        categoryList.adapter?.notifyDataSetChanged()
                        categoryList.scrollToPosition(categoryFocusIndex)
                    }
                } else {
                    // 频道网格向下
                    val columns = 5
                    val filteredChannels = getFilteredChannels()
                    if (channelFocusIndex + columns < filteredChannels.size) {
                        channelFocusIndex += columns
                        channelGrid.adapter?.notifyDataSetChanged()
                        channelGrid.scrollToPosition(channelFocusIndex)
                    }
                }
                return true
            }
            
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (isCategoryFocused) {
                    // 选择分类
                    selectedCategoryIndex = categoryFocusIndex
                    channelFocusIndex = 0
                    updateChannelGrid()
                    categoryList.adapter?.notifyDataSetChanged()
                } else {
                    // 选择频道
                    val filteredChannels = getFilteredChannels()
                    if (channelFocusIndex < filteredChannels.size) {
                        val channelIndex = filteredChannels[channelFocusIndex]
                        playChannelOnScreen(targetScreenForSelector, channelIndex)
                        hideChannelSelector()
                    }
                }
                return true
            }
        }
        return false
    }
    
    // ==================== 适配器 ====================
    
    inner class CategoryAdapter : RecyclerView.Adapter<CategoryAdapter.ViewHolder>() {
        
        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val indicator: View = view.findViewById(R.id.category_indicator)
            val name: TextView = view.findViewById(R.id.category_name)
            val count: TextView = view.findViewById(R.id.category_count)
        }
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_category, parent, false)
            return ViewHolder(view)
        }
        
        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val isSelected = position == selectedCategoryIndex
            val isFocused = isCategoryFocused && position == categoryFocusIndex
            
            if (position == 0) {
                holder.name.text = "全部频道"
                holder.count.text = channelUrls.size.toString()
            } else {
                val categoryName = categories[position - 1]
                holder.name.text = categoryName
                holder.count.text = (categoryChannelCounts[categoryName] ?: 0).toString()
            }
            
            // 选中状态
            holder.indicator.visibility = if (isSelected) View.VISIBLE else View.INVISIBLE
            holder.name.setTextColor(if (isSelected) 0xFFE91E63.toInt() else Color.WHITE)
            
            // 焦点状态
            holder.itemView.setBackgroundColor(
                when {
                    isFocused -> 0x33E91E63.toInt()
                    isSelected -> 0x1AE91E63.toInt()
                    else -> Color.TRANSPARENT
                }
            )
        }
        
        override fun getItemCount(): Int = categories.size + 1  // +1 for "全部频道"
    }
    
    inner class ChannelAdapter : RecyclerView.Adapter<ChannelAdapter.ViewHolder>() {
        
        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val logo: ImageView = view.findViewById(R.id.channel_logo)
            val defaultLogo: ImageView = view.findViewById(R.id.default_logo)
            val name: TextView = view.findViewById(R.id.channel_name)
            val container: View = view
        }
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_channel_grid, parent, false)
            return ViewHolder(view)
        }
        
        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val filteredChannels = getFilteredChannels()
            if (position >= filteredChannels.size) return
            
            val channelIndex = filteredChannels[position]
            val isFocused = !isCategoryFocused && position == channelFocusIndex
            
            holder.name.text = channelNames.getOrElse(channelIndex) { "频道 ${channelIndex + 1}" }
            
            // 加载台标
            val logoUrl = channelLogos.getOrElse(channelIndex) { "" }
            loadImageAsync(logoUrl, holder.logo, holder.defaultLogo)
            
            // 焦点状态 - 设置背景View
            val bgView = holder.container.findViewById<View>(R.id.item_background)
            bgView?.setBackgroundResource(
                if (isFocused) R.drawable.channel_grid_item_focused else R.drawable.channel_grid_item_bg
            )
        }
        
        override fun getItemCount(): Int = getFilteredChannels().size
    }
}
