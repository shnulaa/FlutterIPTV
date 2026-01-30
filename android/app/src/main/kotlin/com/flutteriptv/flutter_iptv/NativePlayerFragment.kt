package com.flutteriptv.flutter_iptv

import android.net.TrafficStats
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.flutteriptv.flutter_iptv.MainActivity

class NativePlayerFragment : Fragment() {
    private val TAG = "NativePlayerFragment"

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var loadingIndicator: ProgressBar
    private lateinit var channelNameText: TextView
    private lateinit var statusText: TextView
    private lateinit var statusIndicator: View
    private lateinit var videoInfoText: TextView
    private lateinit var errorText: TextView
    private lateinit var backButton: ImageButton
    private lateinit var topBar: View
    private lateinit var bottomBar: View
    
    // EPG views
    private lateinit var epgContainer: View
    private lateinit var epgCurrentContainer: View
    private lateinit var epgNextContainer: View
    private lateinit var epgCurrentTitle: TextView
    private lateinit var epgCurrentTime: TextView
    private lateinit var epgNextTitle: TextView
    
    // Progress views (DLNA mode)
    private lateinit var progressContainer: View
    private lateinit var progressBar: android.widget.SeekBar
    private lateinit var progressCurrent: TextView
    private lateinit var progressDuration: TextView
    private lateinit var helpText: TextView
    
    // Category panel views
    private lateinit var categoryPanel: View
    private lateinit var categoryListContainer: View
    private lateinit var channelListContainer: View
    private lateinit var categoryList: RecyclerView
    private lateinit var channelList: RecyclerView
    private lateinit var channelListTitle: TextView
    
    // FPS display
    private lateinit var fpsText: TextView
    private var showFps: Boolean = true
    
    // Clock display
    private lateinit var clockText: TextView
    private var showClock: Boolean = true
    private var clockUpdateRunnable: Runnable? = null
    private val CLOCK_UPDATE_INTERVAL = 1000L
    
    // Source indicator
    private lateinit var sourceIndicator: View
    private lateinit var sourceText: TextView
    private var sourceIndicatorHideRunnable: Runnable? = null
    private val SOURCE_INDICATOR_HIDE_DELAY = 3000L
    
    // Long press detection for left key
    private var leftKeyDownTime = 0L
    private val LONG_PRESS_THRESHOLD = 500L // 500ms for long press
    private var longPressHandled = false // 防止长按后继续触发
    private var isSeekingWithLeftRight = false // 标记是否正在用左右键拖动进度
    private var seekSpeedMultiplier = 1 // 快进快退速度倍数（递增）
    
    // Double click detection for left key (show category panel)
    private var lastLeftKeyUpTime = 0L
    private val LEFT_DOUBLE_CLICK_INTERVAL = 600L // 600ms内按两次左键显示分类面板
    
    // Long press detection for right key (seeking)
    private var rightKeyDownTime = 0L
    private var rightLongPressHandled = false
    
    // Long press detection for center/enter key (favorite)
    private var centerKeyDownTime = 0L
    private var centerLongPressHandled = false
    private var isManualSwitching = false
    private var currentVerificationId = 0L

    private var currentUrl: String = ""
    private var currentName: String = ""
    private var currentIndex: Int = 0
    private var currentSourceIndex: Int = 0 // 当前源索引
    
    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    private var channelGroups: ArrayList<String> = arrayListOf()
    private var channelSources: ArrayList<ArrayList<String>> = arrayListOf() // 每个频道的所有源
    private var channelLogos: ArrayList<String> = arrayListOf()
    private var channelEpgIds: ArrayList<String> = arrayListOf()
    private var channelIsSeekable: ArrayList<Boolean> = arrayListOf() // 每个频道是否可拖动
    private var isDlnaMode: Boolean = false
    private var bufferStrength: String = "fast"
    private var progressBarMode: String = "auto" // 进度条显示模式：auto, always, never
    
    // Category data
    private var categories: MutableList<CategoryItem> = mutableListOf()
    private var selectedCategoryIndex: Int = -1
    private var categoryPanelVisible = false
    private var showingChannelList = false
    
    // 重定向URL缓存（避免重复解析）
    private val redirectCache = mutableMapOf<String, Pair<String, Long>>()
    private val CACHE_EXPIRY_MS = 5 * 60 * 1000L // 5分钟
    
    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private var controlsVisible = true
    private val CONTROLS_HIDE_DELAY = 3000L
    
    private var lastBackPressTime = 0L
    private val BACK_PRESS_INTERVAL = 2000L // 2秒内按两次返回才退出
    
    // 双击OK键收藏
    private var lastOkPressTime = 0L
    private val OK_DOUBLE_CLICK_INTERVAL = 600L // 600ms内按两次OK键收藏
    
    private var videoWidth = 0
    private var videoHeight = 0
    private var videoCodec = ""
    private var isHardwareDecoder = false
    private var frameRate = 0f
    
    // Retry logic
    private var retryCount = 0
    private val MAX_RETRIES = 2 // 改为2次重试
    private val RETRY_DELAY = 500L // 改为0.5秒，加快重试速度
    private var retryRunnable: Runnable? = null
    
    // 自动源切换标记
    private var isAutoSwitching = false // 标记是否正在自动切换源
    private var isAutoDetecting = false // 标记是否正在自动检测源
    
    // FPS calculation
    private var lastRenderedFrameCount = 0L
    private var lastFpsUpdateTime = 0L
    private var fpsUpdateRunnable: Runnable? = null
    private val FPS_UPDATE_INTERVAL = 1000L
    
    // EPG update
    private var epgUpdateRunnable: Runnable? = null
    private val EPG_UPDATE_INTERVAL = 60000L // 每分钟更新一次
    
    // Progress update (DLNA mode)
    private var progressUpdateRunnable: Runnable? = null
    private val PROGRESS_UPDATE_INTERVAL = 1000L // 每秒更新一次

    // Network speed display
    private lateinit var speedText: TextView
    private var showNetworkSpeed: Boolean = true
    private var networkSpeedUpdateRunnable: Runnable? = null
    private val NETWORK_SPEED_UPDATE_INTERVAL = 1000L
    private var lastRxBytes = 0L
    private var lastSpeedUpdateTime = 0L
    private var currentSpeedBps = 0.0 // 当前网速 bytes/s，用于码率显示

    // Video info display
    private lateinit var resolutionText: TextView
    private var showVideoInfo: Boolean = true
    
    // Favorite icon
    private lateinit var favoriteIcon: ImageView
    private var isFavorite: Boolean = false
    
    var onCloseListener: (() -> Unit)? = null
    var onEnterMultiScreen: ((Int, Int) -> Unit)? = null  // 进入分屏模式，传递当前频道索引和源索引

    companion object {
        private const val ARG_VIDEO_URL = "video_url"
        private const val ARG_CHANNEL_NAME = "channel_name"
        private const val ARG_CHANNEL_INDEX = "channel_index"
        private const val ARG_CHANNEL_URLS = "channel_urls"
        private const val ARG_CHANNEL_NAMES = "channel_names"
        private const val ARG_CHANNEL_GROUPS = "channel_groups"
        private const val ARG_CHANNEL_SOURCES = "channel_sources"
        private const val ARG_CHANNEL_LOGOS = "channel_logos"
        private const val ARG_CHANNEL_EPG_IDS = "channel_epg_ids"
        private const val ARG_CHANNEL_IS_SEEKABLE = "channel_is_seekable"
        private const val ARG_IS_DLNA_MODE = "is_dlna_mode"
        private const val ARG_BUFFER_STRENGTH = "buffer_strength"
        private const val ARG_SHOW_FPS = "show_fps"
        private const val ARG_SHOW_CLOCK = "show_clock"
        private const val ARG_SHOW_NETWORK_SPEED = "show_network_speed"
        private const val ARG_SHOW_VIDEO_INFO = "show_video_info"
        private const val ARG_PROGRESS_BAR_MODE = "progress_bar_mode"
        private const val ARG_INITIAL_SOURCE_INDEX = "initial_source_index"

        fun newInstance(
            videoUrl: String,
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null,
            channelGroups: ArrayList<String>? = null,
            channelSources: ArrayList<ArrayList<String>>? = null,
            channelLogos: ArrayList<String>? = null,
            channelEpgIds: ArrayList<String>? = null,
            channelIsSeekable: ArrayList<Boolean>? = null,
            isDlnaMode: Boolean = false,
            bufferStrength: String = "fast",
            showFps: Boolean = true,
            showClock: Boolean = true,
            showNetworkSpeed: Boolean = true,
            showVideoInfo: Boolean = true,
            progressBarMode: String = "auto",
            initialSourceIndex: Int = 0
        ): NativePlayerFragment {
            return NativePlayerFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_VIDEO_URL, videoUrl)
                    putString(ARG_CHANNEL_NAME, channelName)
                    putInt(ARG_CHANNEL_INDEX, channelIndex)
                    channelUrls?.let { putStringArrayList(ARG_CHANNEL_URLS, it) }
                    channelNames?.let { putStringArrayList(ARG_CHANNEL_NAMES, it) }
                    channelGroups?.let { putStringArrayList(ARG_CHANNEL_GROUPS, it) }
                    channelSources?.let { putSerializable(ARG_CHANNEL_SOURCES, it) }
                    channelLogos?.let { putStringArrayList(ARG_CHANNEL_LOGOS, it) }
                    channelEpgIds?.let { putStringArrayList(ARG_CHANNEL_EPG_IDS, it) }
                    channelIsSeekable?.let { putBooleanArray(ARG_CHANNEL_IS_SEEKABLE, it.toBooleanArray()) }
                    putBoolean(ARG_IS_DLNA_MODE, isDlnaMode)
                    putString(ARG_BUFFER_STRENGTH, bufferStrength)
                    putBoolean(ARG_SHOW_FPS, showFps)
                    putBoolean(ARG_SHOW_CLOCK, showClock)
                    putBoolean(ARG_SHOW_NETWORK_SPEED, showNetworkSpeed)
                    putBoolean(ARG_SHOW_VIDEO_INFO, showVideoInfo)
                    putString(ARG_PROGRESS_BAR_MODE, progressBarMode)
                    putInt(ARG_INITIAL_SOURCE_INDEX, initialSourceIndex)
                }
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.activity_native_player, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "onViewCreated")
        
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        arguments?.let {
            currentUrl = it.getString(ARG_VIDEO_URL, "")
            currentName = it.getString(ARG_CHANNEL_NAME, "")
            currentIndex = it.getInt(ARG_CHANNEL_INDEX, 0)
            channelUrls = it.getStringArrayList(ARG_CHANNEL_URLS) ?: arrayListOf()
            channelNames = it.getStringArrayList(ARG_CHANNEL_NAMES) ?: arrayListOf()
            channelGroups = it.getStringArrayList(ARG_CHANNEL_GROUPS) ?: arrayListOf()
            @Suppress("UNCHECKED_CAST")
            channelSources = it.getSerializable(ARG_CHANNEL_SOURCES) as? ArrayList<ArrayList<String>> ?: arrayListOf()
            channelLogos = it.getStringArrayList(ARG_CHANNEL_LOGOS) ?: arrayListOf()
            channelEpgIds = it.getStringArrayList(ARG_CHANNEL_EPG_IDS) ?: arrayListOf()
            // 读取 isSeekable 数组
            val isSeekableArray = it.getBooleanArray(ARG_CHANNEL_IS_SEEKABLE)
            channelIsSeekable = if (isSeekableArray != null) {
                ArrayList(isSeekableArray.toList())
            } else {
                arrayListOf()
            }
            isDlnaMode = it.getBoolean(ARG_IS_DLNA_MODE, false)
            bufferStrength = it.getString(ARG_BUFFER_STRENGTH, "fast") ?: "fast"
            progressBarMode = it.getString(ARG_PROGRESS_BAR_MODE, "auto") ?: "auto" // 读取进度条显示模式
            showFps = it.getBoolean(ARG_SHOW_FPS, true)
            showClock = it.getBoolean(ARG_SHOW_CLOCK, true)
            showNetworkSpeed = it.getBoolean(ARG_SHOW_NETWORK_SPEED, true)
            showVideoInfo = it.getBoolean(ARG_SHOW_VIDEO_INFO, true)
            currentSourceIndex = it.getInt(ARG_INITIAL_SOURCE_INDEX, 0) // 使用传入的初始源索引
        }
        
        Log.d(TAG, "=== 参数读取完成 ===")
        Log.d(TAG, "progressBarMode: $progressBarMode")
        Log.d(TAG, "isDlnaMode: $isDlnaMode")
        Log.d(TAG, "currentIndex: $currentIndex")
        Log.d(TAG, "channelIsSeekable.size: ${channelIsSeekable.size}")
        if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
            Log.d(TAG, "当前频道 isSeekable: ${channelIsSeekable[currentIndex]}")
        }
        Log.d(TAG, "Playing: $currentName (index $currentIndex of ${channelUrls.size}, isDlna=$isDlnaMode, sources=${getCurrentSources().size})")

        playerView = view.findViewById(R.id.player_view)
        loadingIndicator = view.findViewById(R.id.loading_indicator)
        channelNameText = view.findViewById(R.id.channel_name)
        statusText = view.findViewById(R.id.status_text)
        statusIndicator = view.findViewById(R.id.status_indicator)
        videoInfoText = view.findViewById(R.id.video_info)
        errorText = view.findViewById(R.id.error_text)
        backButton = view.findViewById(R.id.back_button)
        topBar = view.findViewById(R.id.top_bar)
        bottomBar = view.findViewById(R.id.bottom_bar)
        
        // Category panel views
        categoryPanel = view.findViewById(R.id.category_panel)
        categoryListContainer = view.findViewById(R.id.category_list_container)
        channelListContainer = view.findViewById(R.id.channel_list_container)
        categoryList = view.findViewById(R.id.category_list)
        channelList = view.findViewById(R.id.channel_list)
        channelListTitle = view.findViewById(R.id.channel_list_title)
        
        // EPG views
        epgContainer = view.findViewById(R.id.epg_container)
        epgCurrentContainer = view.findViewById(R.id.epg_current_container)
        epgNextContainer = view.findViewById(R.id.epg_next_container)
        epgCurrentTitle = view.findViewById(R.id.epg_current_title)
        epgCurrentTime = view.findViewById(R.id.epg_current_time)
        epgNextTitle = view.findViewById(R.id.epg_next_title)
        
        // Progress views (DLNA mode)
        progressContainer = view.findViewById(R.id.progress_container)
        progressBar = view.findViewById(R.id.progress_bar)
        progressCurrent = view.findViewById(R.id.progress_current)
        progressDuration = view.findViewById(R.id.progress_duration)
        helpText = view.findViewById(R.id.help_text)
        
        // 设置进度条拖动监听器
        progressBar.setOnSeekBarChangeListener(object : android.widget.SeekBar.OnSeekBarChangeListener {
            private var wasPlaying = false
            
            override fun onProgressChanged(seekBar: android.widget.SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    // 用户拖动时实时更新时间显示
                    val p = player ?: return
                    val duration = p.duration
                    if (duration > 0) {
                        val position = (duration * progress / 100)
                        progressCurrent.text = formatTime(position)
                    }
                }
            }
            
            override fun onStartTrackingTouch(seekBar: android.widget.SeekBar?) {
                Log.d(TAG, "进度条开始拖动")
                // 记录播放状态
                wasPlaying = player?.isPlaying ?: false
                // 暂停播放
                player?.pause()
                // 停止进度更新
                stopProgressUpdate()
            }
            
            override fun onStopTrackingTouch(seekBar: android.widget.SeekBar?) {
                Log.d(TAG, "进度条拖动结束")
                val p = player ?: return
                val duration = p.duration
                if (duration > 0) {
                    val progress = seekBar?.progress ?: 0
                    val position = (duration * progress / 100)
                    Log.d(TAG, "跳转到位置: ${formatTime(position)} (${progress}%)")
                    p.seekTo(position)
                    
                    // 如果之前在播放，继续播放
                    if (wasPlaying) {
                        p.play()
                    }
                    
                    // 重新启动进度更新
                    startProgressUpdate()
                }
            }
        })
        
        // 进度条获得焦点时显示控制栏
        progressBar.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                Log.d(TAG, "进度条获得焦点")
                showControls()
            }
        }
        
        // FPS display
        fpsText = view.findViewById(R.id.fps_text)
        
        // Clock display
        clockText = view.findViewById(R.id.clock_text)

        // Network speed display
        speedText = view.findViewById(R.id.speed_text)

        // Video info display (resolution + bitrate)
        resolutionText = view.findViewById(R.id.resolution_text)
        
        // Favorite icon
        favoriteIcon = view.findViewById(R.id.favorite_icon)
        
        // Source indicator
        sourceIndicator = view.findViewById(R.id.source_indicator)
        sourceText = view.findViewById(R.id.source_text)

        channelNameText.text = currentName
        updateStatus("Loading")
        
        backButton.setOnClickListener { 
            Log.d(TAG, "Back button clicked")
            closePlayer()
        }
        
        playerView.useController = false
        
        // 使用统一的进度条可见性更新方法（根据用户设置）
        Log.d(TAG, "=== 初始化进度条可见性 ===")
        updateProgressBarVisibility()
        
        // Setup category panel
        setupCategoryPanel()
        
        // Handle key events
        view.isFocusableInTouchMode = true
        view.requestFocus()
        view.setOnKeyListener { _, keyCode, event ->
            when (event.action) {
                KeyEvent.ACTION_DOWN -> handleKeyDown(keyCode, event)
                KeyEvent.ACTION_UP -> handleKeyUp(keyCode, event)
                else -> false
            }
        }

        initializePlayer()
        
        if (currentUrl.isNotEmpty()) {
            Log.d(TAG, "=== 开始首次播放流程 ===")
            Log.d(TAG, "当前URL: $currentUrl")
            Log.d(TAG, "当前频道: $currentName")
            
            // 检测并使用第一个可用的源
            val sources = getCurrentSources()
            Log.d(TAG, "获取到 ${sources.size} 个源")
            
            if (sources.size > 1 && currentSourceIndex == 0) {
                Log.d(TAG, "频道有多个源且未指定特定源(index=0)，开始在后台线程检测...")
                
                // 显示正在检测的状态
                updateStatus("检测源...")
                showLoading()
                
                // 在后台线程检测源
                Thread {
                    var foundSourceIndex = 0
                    for (i in sources.indices) {
                        // 实时更新UI显示当前检测的源
                        activity?.runOnUiThread {
                            updateStatus("检测源 ${i + 1}/${sources.size}")
                        }
                        
                        Log.d(TAG, "检测源 ${i + 1}/${sources.size}: ${sources[i]}")
                        if (testSource(sources[i])) {
                            foundSourceIndex = i
                            Log.d(TAG, "✓ 源 ${i + 1} 可用")
                            break
                        } else {
                            Log.d(TAG, "✗ 源 ${i + 1} 不可用")
                        }
                    }
                    
                    val finalSourceIndex = foundSourceIndex
                    activity?.runOnUiThread {
                        currentSourceIndex = finalSourceIndex
                        val urlToPlay = sources[currentSourceIndex]
                        Log.d(TAG, "首次播放，使用源 ${currentSourceIndex + 1}/${sources.size}: $urlToPlay")
                        updateSourceIndicator()
                        playUrl(urlToPlay)
                    }
                }.start()
            } else {
                Log.d(TAG, "直接播放指定源 (index=$currentSourceIndex) 或单源频道")
                // 确保索引在有效范围内
                if (currentSourceIndex < 0 || currentSourceIndex >= sources.size) {
                    currentSourceIndex = 0
                }
                
                val urlToPlay = if (sources.isNotEmpty()) {
                    sources[currentSourceIndex]
                } else {
                    currentUrl
                }
                
                Log.d(TAG, "播放URL: $urlToPlay")
                playUrl(urlToPlay)
                updateSourceIndicator()
            }
        } else {
            Log.e(TAG, "错误：没有提供视频URL")
            showError("No video URL provided")
        }
        
        // Start clock update
        startClockUpdate()
        
        // 初始化EPG信息
        refreshEpgInfo()

        // Start network speed update
        startNetworkSpeedUpdate()
        
        // Check initial favorite status
        checkInitialFavoriteStatus()
        
        showControls()
    }
    
    private fun setupCategoryPanel() {
        // Build category list from channel groups
        buildCategories()
        
        categoryList.layoutManager = LinearLayoutManager(requireContext())
        channelList.layoutManager = LinearLayoutManager(requireContext())
        
        // 给 RecyclerView 添加按键监听，处理返回键和左键
        val recyclerKeyListener = View.OnKeyListener { _, keyCode, event ->
            if (event.action == KeyEvent.ACTION_DOWN) {
                when (keyCode) {
                    KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                        handleBackKey()
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_LEFT -> {
                        handleBackKey()
                        true
                    }
                    else -> false
                }
            } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                // 松开左键时重置长按标志
                longPressHandled = false
                leftKeyDownTime = 0L
                true
            } else {
                false
            }
        }
        categoryList.setOnKeyListener(recyclerKeyListener)
        channelList.setOnKeyListener(recyclerKeyListener)
        
        // Category adapter
        categoryList.adapter = object : RecyclerView.Adapter<CategoryViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CategoryViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_category, parent, false)
                return CategoryViewHolder(view)
            }
            
            override fun onBindViewHolder(holder: CategoryViewHolder, position: Int) {
                val item = categories[position]
                holder.nameText.text = item.name
                holder.countText.text = item.count.toString()
                // 只有当前选中且显示频道列表时才保持选中状态
                holder.itemView.isSelected = showingChannelList && position == selectedCategoryIndex
                
                holder.itemView.setOnClickListener {
                    selectCategory(holder.adapterPosition)
                }
                
                // 给每个 item 添加按键监听
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // 如果长按标志还在，忽略（用户还在长按）
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // 松开左键时重置长按标志
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }
                
                holder.itemView.setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus && !showingChannelList) {
                        // 获得焦点时临时显示选中效果
                        holder.itemView.isSelected = true
                    } else if (!hasFocus && !(showingChannelList && holder.adapterPosition == selectedCategoryIndex)) {
                        // 失去焦点且不是当前选中的分类时清除选中效果
                        holder.itemView.isSelected = false
                    }
                }
            }
            
            override fun getItemCount() = categories.size
        }
    }
    
    private fun buildCategories() {
        categories.clear()
        val groupOrder = mutableListOf<String>() // 保持原始顺序
        val groupMap = mutableMapOf<String, Int>()
        
        for (group in channelGroups) {
            val name = group.ifEmpty { getString(R.string.uncategorized) }
            if (!groupMap.containsKey(name)) {
                groupOrder.add(name) // 记录首次出现的顺序
            }
            groupMap[name] = (groupMap[name] ?: 0) + 1
        }
        
        // 按原始顺序创建分类列表
        for (name in groupOrder) {
            categories.add(CategoryItem(name, groupMap[name] ?: 0))
        }
    }
    
    private fun selectCategory(position: Int) {
        selectedCategoryIndex = position
        val category = categories[position]
        channelListTitle.text = category.name
        
        // 刷新分类列表以更新选中状态
        categoryList.adapter?.notifyDataSetChanged()
        
        // Get channels for this category
        val channelsInCategory = mutableListOf<ChannelItem>()
        val uncategorizedStr = getString(R.string.uncategorized)
        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { uncategorizedStr }
            if (groupName == category.name) {
                val isPlaying = i == currentIndex
                channelsInCategory.add(ChannelItem(i, channelNames.getOrElse(i) { "Channel $i" }, isPlaying))
            }
        }
        
        // Setup channel adapter
        channelList.adapter = object : RecyclerView.Adapter<ChannelViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChannelViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_channel, parent, false)
                return ChannelViewHolder(view)
            }
            
            override fun onBindViewHolder(holder: ChannelViewHolder, position: Int) {
                val item = channelsInCategory[position]
                holder.nameText.text = item.name
                holder.playingIcon.visibility = if (item.isPlaying) View.VISIBLE else View.GONE
                holder.nameText.setTextColor(if (item.isPlaying) 0xFFE91E63.toInt() else 0xFFFFFFFF.toInt())
                
                holder.itemView.setOnClickListener {
                    switchChannel(item.index)
                    hideCategoryPanel()
                }
                
                // 给每个 item 添加按键监听
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // 如果长按标志还在，忽略（用户还在长按）
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // 松开左键时重置长按标志
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }
                
                holder.itemView.setOnFocusChangeListener { v, hasFocus ->
                    v.isSelected = hasFocus
                }
            }
            
            override fun getItemCount() = channelsInCategory.size
        }
        
        // Show channel list
        channelListContainer.visibility = View.VISIBLE
        showingChannelList = true
        
        // Focus first channel
        channelList.post {
            channelList.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
        }
    }
    private fun showCategoryPanel() {
        categoryPanelVisible = true
        showingChannelList = false
        categoryPanel.visibility = View.VISIBLE
        channelListContainer.visibility = View.GONE
        
        // 找到当前播放频道所在的分类
        val currentGroup = if (currentIndex >= 0 && currentIndex < channelGroups.size) {
            channelGroups[currentIndex].ifEmpty { getString(R.string.uncategorized) }
        } else {
            null
        }
        
        // 找到分类索引
        val categoryIndex = if (currentGroup != null) {
            categories.indexOfFirst { it.name == currentGroup }
        } else {
            -1
        }
        
        if (categoryIndex >= 0) {
            // 自动选择当前频道所在的分类，并展开频道列表
            selectedCategoryIndex = categoryIndex
            
            // 刷新分类列表
            categoryList.adapter?.notifyDataSetChanged()
            
            // 滚动到对应分类
            categoryList.scrollToPosition(categoryIndex)
            
            // 自动展开频道列表并定位到当前频道
            selectCategoryAndLocateChannel(categoryIndex)
        } else {
            selectedCategoryIndex = -1
            // 刷新分类列表
            categoryList.adapter?.notifyDataSetChanged()
            
            // Focus first category
            categoryList.post {
                categoryList.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
            }
        }
        
        // Cancel auto-hide
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
    }
    
    private fun selectCategoryAndLocateChannel(position: Int) {
        selectedCategoryIndex = position
        val category = categories[position]
        channelListTitle.text = category.name
        
        // 刷新分类列表以更新选中状态
        categoryList.adapter?.notifyDataSetChanged()
        
        // Get channels for this category
        val channelsInCategory = mutableListOf<ChannelItem>()
        var currentChannelPositionInList = -1
        val uncategorizedStr = getString(R.string.uncategorized)
        
        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { uncategorizedStr }
            if (groupName == category.name) {
                val isPlaying = i == currentIndex
                if (isPlaying) {
                    currentChannelPositionInList = channelsInCategory.size
                }
                channelsInCategory.add(ChannelItem(i, channelNames.getOrElse(i) { "Channel $i" }, isPlaying))
            }
        }
        
        // Setup channel adapter
        channelList.adapter = object : RecyclerView.Adapter<ChannelViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChannelViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_channel, parent, false)
                return ChannelViewHolder(view)
            }
            
            override fun onBindViewHolder(holder: ChannelViewHolder, position: Int) {
                val item = channelsInCategory[position]
                holder.nameText.text = item.name
                holder.playingIcon.visibility = if (item.isPlaying) View.VISIBLE else View.GONE
                holder.nameText.setTextColor(if (item.isPlaying) 0xFFE91E63.toInt() else 0xFFFFFFFF.toInt())
                
                holder.itemView.setOnClickListener {
                    switchChannel(item.index)
                    hideCategoryPanel()
                }
                
                // 给每个 item 添加按键监听
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // 如果长按标志还在，忽略（用户还在长按）
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // 松开左键时重置长按标志
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }
                
                holder.itemView.setOnFocusChangeListener { v, hasFocus ->
                    v.isSelected = hasFocus
                }
            }
            
            override fun getItemCount() = channelsInCategory.size
        }
        
        // Show channel list
        channelListContainer.visibility = View.VISIBLE
        showingChannelList = true
        
        // 滚动到当前播放的频道并聚焦
        val focusPosition = if (currentChannelPositionInList >= 0) currentChannelPositionInList else 0
        channelList.post {
            channelList.scrollToPosition(focusPosition)
            channelList.post {
                channelList.findViewHolderForAdapterPosition(focusPosition)?.itemView?.requestFocus()
            }
        }
    }
    
    private fun hideCategoryPanel() {
        categoryPanelVisible = false
        showingChannelList = false
        selectedCategoryIndex = -1
        categoryPanel.visibility = View.GONE
        channelListContainer.visibility = View.GONE
        
        // Return focus to main view
        view?.requestFocus()
        scheduleHideControls()
    }

    fun handleBackKey(): Boolean {
        Log.d(TAG, "handleBackKey: categoryPanelVisible=$categoryPanelVisible, showingChannelList=$showingChannelList, longPressHandled=$longPressHandled")
        
        if (categoryPanelVisible) {
            if (showingChannelList) {
                // Go back to category list
                channelListContainer.visibility = View.GONE
                showingChannelList = false
                categoryList.findViewHolderForAdapterPosition(selectedCategoryIndex.coerceAtLeast(0))?.itemView?.requestFocus()
                return true
            }
            // Close category panel
            hideCategoryPanel()
            return true
        }
        
        // 双击返回退出播放器
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastBackPressTime < BACK_PRESS_INTERVAL) {
            closePlayer()
        } else {
            lastBackPressTime = currentTime
            // 显示提示
            activity?.runOnUiThread {
                android.widget.Toast.makeText(requireContext(), getString(R.string.press_back_again_to_exit), android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }

    private fun handleKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode, categoryPanelVisible=$categoryPanelVisible, isDlnaMode=$isDlnaMode, progressBarHasFocus=${progressBar.hasFocus()}")
        
        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                // 如果正在拖动进度，先退出拖动模式
                if (isSeekingWithLeftRight) {
                    isSeekingWithLeftRight = false
                    showControls()
                    return true
                }
                return handleBackKey()
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (!categoryPanelVisible) {
                    // 长按已处理，忽略后续事件
                    if (centerLongPressHandled) {
                        return true
                    }
                    // 记录按下时间
                    if (event.repeatCount == 0) {
                        centerKeyDownTime = System.currentTimeMillis()
                        centerLongPressHandled = false
                    }
                    // 检测长按 - 进入分屏模式
                    if (event.repeatCount > 0 && !centerLongPressHandled && 
                        System.currentTimeMillis() - centerKeyDownTime >= LONG_PRESS_THRESHOLD) {
                        centerLongPressHandled = true
                        // 长按OK键进入分屏模式
                        if (!isDlnaMode && channelUrls.isNotEmpty()) {
                            onEnterMultiScreen?.invoke(currentIndex, currentSourceIndex)
                        }
                        return true
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                // DLNA 模式下左键快退 10 秒
                if (isDlnaMode) {
                    showControls()
                    player?.seekBack()
                    return true
                }
                
                // 如果长按已处理，继续处理重复事件（持续快退，速度递增）
                if (longPressHandled) {
                    // 检查是否是可拖动内容
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }
                    
                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        // 递增速度：每次重复事件增加倍数（最大10倍）
                        seekSpeedMultiplier = (seekSpeedMultiplier + 1).coerceAtMost(10)
                        val seekAmount = 5000 * seekSpeedMultiplier // 5秒 * 倍数
                        
                        // 持续快退
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val newPos = (currentPos - seekAmount).coerceAtLeast(0)
                            p.seekTo(newPos)
                            Log.d(TAG, "持续快退 (${seekSpeedMultiplier}x): ${formatTime(currentPos)} -> ${formatTime(newPos)} (-${seekAmount/1000}s)")
                        }
                        showControls()
                    }
                    return true
                }
                
                // 分类面板已打开时，不处理长按，让 item 的监听器处理
                if (categoryPanelVisible) {
                    return false
                }
                
                // 记录按下时间，用于长按检测
                if (event.repeatCount == 0) {
                    leftKeyDownTime = System.currentTimeMillis()
                    longPressHandled = false
                    seekSpeedMultiplier = 1 // 重置速度倍数
                    Log.d(TAG, "左键按下，开始计时")
                }
                
                // 检测长按 - 拖动进度条（仅在可拖动内容时）
                val pressDuration = System.currentTimeMillis() - leftKeyDownTime
                if (event.repeatCount > 0 && !longPressHandled && pressDuration >= LONG_PRESS_THRESHOLD) {
                    Log.d(TAG, "检测到左键长按，pressDuration=$pressDuration")
                    
                    // 检查是否是可拖动内容
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }
                    
                    Log.d(TAG, "currentIsSeekable=$currentIsSeekable, progressVisible=${progressContainer.visibility == View.VISIBLE}")
                    
                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        longPressHandled = true
                        isSeekingWithLeftRight = true
                        seekSpeedMultiplier = 1 // 初始速度
                        // 快退
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val newPos = (currentPos - 10000).coerceAtLeast(0) // 首次快退10秒
                            p.seekTo(newPos)
                            Log.d(TAG, "长按左键快退: ${formatTime(currentPos)} -> ${formatTime(newPos)}")
                        }
                        showControls()
                        return true
                    } else {
                        Log.d(TAG, "不满足快退条件")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                // DLNA 模式下右键快进 10 秒
                if (isDlnaMode) {
                    showControls()
                    player?.seekForward()
                    return true
                }
                
                // 如果长按已处理，继续处理重复事件（持续快进，速度递增）
                if (rightLongPressHandled) {
                    // 检查是否是可拖动内容
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }
                    
                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        // 递增速度：每次重复事件增加倍数（最大10倍）
                        seekSpeedMultiplier = (seekSpeedMultiplier + 1).coerceAtMost(10)
                        val seekAmount = 5000 * seekSpeedMultiplier // 5秒 * 倍数
                        
                        // 持续快进
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val duration = p.duration
                            val newPos = (currentPos + seekAmount).coerceAtMost(duration)
                            p.seekTo(newPos)
                            Log.d(TAG, "持续快进 (${seekSpeedMultiplier}x): ${formatTime(currentPos)} -> ${formatTime(newPos)} (+${seekAmount/1000}s)")
                        }
                        showControls()
                    }
                    return true
                }
                
                // 分类面板已打开时不处理
                if (categoryPanelVisible) {
                    return false
                }
                
                // 记录按下时间，用于长按检测
                if (event.repeatCount == 0) {
                    rightKeyDownTime = System.currentTimeMillis()
                    rightLongPressHandled = false
                    seekSpeedMultiplier = 1 // 重置速度倍数
                    Log.d(TAG, "右键按下，开始计时")
                }
                
                // 检测长按 - 拖动进度条（仅在可拖动内容时）
                val pressDuration = System.currentTimeMillis() - rightKeyDownTime
                if (event.repeatCount > 0 && !rightLongPressHandled && pressDuration >= LONG_PRESS_THRESHOLD) {
                    Log.d(TAG, "检测到右键长按，pressDuration=$pressDuration")
                    
                    // 检查是否是可拖动内容
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }
                    
                    Log.d(TAG, "currentIsSeekable=$currentIsSeekable, progressVisible=${progressContainer.visibility == View.VISIBLE}")
                    
                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        rightLongPressHandled = true
                        isSeekingWithLeftRight = true
                        seekSpeedMultiplier = 1 // 初始速度
                        // 快进
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val duration = p.duration
                            val newPos = (currentPos + 10000).coerceAtMost(duration) // 首次快进10秒
                            p.seekTo(newPos)
                            Log.d(TAG, "长按右键快进: ${formatTime(currentPos)} -> ${formatTime(newPos)}")
                        }
                        showControls()
                        return true
                    } else {
                        Log.d(TAG, "不满足快进条件")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_CHANNEL_UP -> {
                if (!categoryPanelVisible) {
                    // DLNA 模式下只显示控制栏
                    if (isDlnaMode) {
                        showControls()
                        return true
                    }
                    Log.d(TAG, "Channel UP pressed")
                    previousChannel()
                }
                return false // Let RecyclerView handle if panel is visible
            }
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_CHANNEL_DOWN -> {
                if (!categoryPanelVisible) {
                    // DLNA 模式下只显示控制栏
                    if (isDlnaMode) {
                        showControls()
                        return true
                    }
                    Log.d(TAG, "Channel DOWN pressed")
                    nextChannel()
                }
                return false // Let RecyclerView handle if panel is visible
            }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                showControls()
                player?.let {
                    if (it.isPlaying) it.pause() else it.play()
                }
                return true
            }
        }
        
        if (!categoryPanelVisible) {
            showControls()
        }
        return false
    }
    
    private fun handleKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                // 重置长按标志
                val wasLongPressHandled = centerLongPressHandled
                centerLongPressHandled = false
                
                // 如果是长按触发的，不再处理
                if (wasLongPressHandled) {
                    centerKeyDownTime = 0L
                    return true
                }
                
                // 分类面板可见时不处理
                if (categoryPanelVisible) {
                    centerKeyDownTime = 0L
                    return true
                }
                
                // 短按处理 - 播放/暂停或双击收藏
                val pressDuration = System.currentTimeMillis() - centerKeyDownTime
                if (centerKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    val currentTime = System.currentTimeMillis()
                    val timeSinceLastOk = currentTime - lastOkPressTime
                    Log.d(TAG, "OK key up: pressDuration=$pressDuration, timeSinceLastOk=$timeSinceLastOk, lastOkPressTime=$lastOkPressTime")
                    // 检测双击 - 收藏
                    if (lastOkPressTime > 0 && timeSinceLastOk < OK_DOUBLE_CLICK_INTERVAL) {
                        Log.d(TAG, "Double click detected, toggling favorite")
                        toggleFavorite()
                        lastOkPressTime = 0L
                    } else {
                        // 单击 - 播放/暂停
                        lastOkPressTime = currentTime
                        showControls()
                        player?.let {
                            if (it.isPlaying) it.pause() else it.play()
                        }
                    }
                }
                centerKeyDownTime = 0L
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                // 重置长按标志和速度倍数
                val wasLongPressHandled = longPressHandled
                longPressHandled = false
                seekSpeedMultiplier = 1 // 重置速度倍数
                
                // 如果是长按触发的（拖动进度），不再处理
                if (wasLongPressHandled) {
                    leftKeyDownTime = 0L
                    Log.d(TAG, "左键松开，重置速度倍数")
                    return true
                }
                
                // DLNA 模式不处理
                if (isDlnaMode) {
                    leftKeyDownTime = 0L
                    return true
                }
                
                // 分类面板已可见时不处理
                if (categoryPanelVisible) {
                    leftKeyDownTime = 0L
                    return true
                }
                
                // 短按左键处理
                val pressDuration = System.currentTimeMillis() - leftKeyDownTime
                if (leftKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    val currentTime = System.currentTimeMillis()
                    val timeSinceLastLeft = currentTime - lastLeftKeyUpTime
                    Log.d(TAG, "Left key up: pressDuration=$pressDuration, timeSinceLastLeft=$timeSinceLastLeft")
                    
                    // 检测双击 - 显示分类面板
                    if (lastLeftKeyUpTime > 0 && timeSinceLastLeft < LEFT_DOUBLE_CLICK_INTERVAL) {
                        Log.d(TAG, "Double click left detected, showing category panel")
                        showCategoryPanel()
                        lastLeftKeyUpTime = 0L
                    } else {
                        // 单击 - 切换源（如果有多个源）
                        lastLeftKeyUpTime = currentTime
                        if (hasMultipleSources()) {
                            previousSource()
                        }
                    }
                }
                leftKeyDownTime = 0L
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                // 重置长按标志和速度倍数
                val wasLongPressHandled = rightLongPressHandled
                rightLongPressHandled = false
                seekSpeedMultiplier = 1 // 重置速度倍数
                
                // 如果是长按触发的（拖动进度），不再处理
                if (wasLongPressHandled) {
                    rightKeyDownTime = 0L
                    Log.d(TAG, "右键松开，重置速度倍数")
                    return true
                }
                
                // DLNA 模式不处理
                if (isDlnaMode) {
                    rightKeyDownTime = 0L
                    return true
                }
                
                // 分类面板已可见时不处理
                if (categoryPanelVisible) {
                    rightKeyDownTime = 0L
                    return true
                }
                
                // 短按右键 - 切换到下一个源
                val pressDuration = System.currentTimeMillis() - rightKeyDownTime
                if (rightKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    if (hasMultipleSources()) {
                        nextSource()
                    }
                }
                rightKeyDownTime = 0L
                return true
            }
        }
        return false
    }

    private fun initializePlayer() {
        Log.d(TAG, "Initializing ExoPlayer")
        
        // Use DefaultRenderersFactory with FFmpeg extension for MP2/AC3/DTS audio support
        val renderersFactory = DefaultRenderersFactory(requireContext())
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        
        // 配置加载控制 - 根据缓冲强度设置
        val (minBuffer, maxBuffer, playbackBuffer, rebufferBuffer) = when (bufferStrength) {
            "fast" -> arrayOf(15000, 30000, 500, 1500)      // 快速：0.5秒开始播放
            "balanced" -> arrayOf(30000, 60000, 1500, 3000) // 平衡：1.5秒开始播放
            "stable" -> arrayOf(50000, 120000, 2500, 5000)  // 稳定：2.5秒开始播放
            else -> arrayOf(15000, 30000, 500, 1500)
        }
        Log.d(TAG, "Buffer strength: $bufferStrength (playback: ${playbackBuffer}ms)")
        
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(minBuffer, maxBuffer, playbackBuffer, rebufferBuffer)
            .build()
        
        // 配置 HTTP 数据源，设置合理的超时时间
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(5000)  // 5秒连接超时（重定向可能需要更长时间）
            .setReadTimeoutMs(10000)    // 10秒读取超时
            .setAllowCrossProtocolRedirects(true)  // 允许跨协议重定向 (HTTP→HTTPS)
            .setUserAgent("Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36")
        
        // 配置 MediaSourceFactory 支持 HLS/DASH 等流媒体格式
        val mediaSourceFactory = DefaultMediaSourceFactory(requireContext())
            .setDataSourceFactory(dataSourceFactory)
        
        player = ExoPlayer.Builder(requireContext(), renderersFactory)
            .setLoadControl(loadControl)
            .setMediaSourceFactory(mediaSourceFactory)
            .setVideoChangeFrameRateStrategy(C.VIDEO_CHANGE_FRAME_RATE_STRATEGY_OFF)
            .build().also { exoPlayer ->
            playerView.player = exoPlayer
            exoPlayer.playWhenReady = true
            exoPlayer.repeatMode = Player.REPEAT_MODE_OFF
            
            // 设置视频缩放模式
            exoPlayer.videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT

            exoPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> {
                            showLoading()
                            updateStatus("Buffering")
                        }
                        Player.STATE_READY -> {
                            hideLoading()
                            updateStatus("LIVE")
                            // 不立即重置，延迟3秒确保播放真正稳定
                            // 这样可以避免短暂的 READY 状态导致重试计数被过早重置
                            startFpsCalculation() // 开始计算 FPS
                        }
                        Player.STATE_ENDED -> {
                            updateStatus("Ended")
                            stopFpsCalculation()
                        }
                        Player.STATE_IDLE -> {
                            updateStatus("Idle")
                            stopFpsCalculation()
                        }
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        updateStatus("LIVE")
                        // 延迟3秒后确认播放稳定，然后重置重试计数
                        handler.postDelayed({
                            if (player?.isPlaying == true) {
                                Log.d(TAG, "播放稳定，重置重试计数")
                                retryCount = 0
                                isAutoSwitching = false
                            }
                        }, 3000)
                    } else if (player?.playbackState == Player.STATE_READY) {
                        updateStatus("Paused")
                    }
                }

                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    videoWidth = videoSize.width
                    videoHeight = videoSize.height
                    updateVideoInfoDisplay()
                }

                override fun onPlayerError(error: PlaybackException) {
                    Log.e(TAG, "Player error: ${error.message}", error)
                    Log.e(TAG, "Error type: ${error.errorCode}")
                    Log.e(TAG, "Current URL: $currentUrl")
                    error.cause?.let { cause ->
                        Log.e(TAG, "Error cause: ${cause.message}", cause)
                    }
                    
                    // 自动重试逻辑
                    if (retryCount < MAX_RETRIES) {
                        retryCount++
                        Log.d(TAG, "播放错误，尝试重试 ($retryCount/$MAX_RETRIES): ${error.message}")
                        updateStatus("Retrying")
                        showLoading()
                        
                        retryRunnable?.let { handler.removeCallbacks(it) }
                        retryRunnable = Runnable {
                            if (currentUrl.isNotEmpty()) {
                                playUrl(currentUrl)
                            }
                        }
                        handler.postDelayed(retryRunnable!!, RETRY_DELAY)
                    } else {
                        // 重试次数用完，检查是否有其他源可以尝试
                        val sources = getCurrentSources()
                        if (sources.size > 1) {
                            // 标记开始自动检测
                            isAutoDetecting = true
                            
                            // 显示正在检测的状态
                            updateStatus("自动切换源...")
                            showLoading()
                            
                            // 在后台线程异步检测源
                            Thread {
                                // 查找下一个可用的源
                                var nextSourceIndex = currentSourceIndex + 1
                                var foundAvailableSource = false
                                
                                // 不循环，只往后找
                                while (nextSourceIndex < sources.size && isAutoDetecting) {
                                    // 实时更新UI显示当前检测的源
                                    activity?.runOnUiThread {
                                        updateStatus("检测源 ${nextSourceIndex + 1}/${sources.size}")
                                    }
                                    
                                    // 检测源是否可用
                                    Log.d(TAG, "当前源 (${currentSourceIndex + 1}/${sources.size}) 重试失败，检测源 ${nextSourceIndex + 1}")
                                    if (testSource(sources[nextSourceIndex])) {
                                        Log.d(TAG, "源 ${nextSourceIndex + 1} 可用")
                                        foundAvailableSource = true
                                        break
                                    } else {
                                        Log.d(TAG, "源 ${nextSourceIndex + 1} 不可用，继续尝试下一个源")
                                    }
                                    nextSourceIndex++
                                }
                                
                                val finalNextSourceIndex = nextSourceIndex
                                val finalFoundAvailableSource = foundAvailableSource
                                
                                activity?.runOnUiThread {
                                    isAutoDetecting = false
                                    
                                    if (finalFoundAvailableSource) {
                                        // 找到可用的源，自动切换
                                        Log.d(TAG, "切换到可用源 ${finalNextSourceIndex + 1}")
                                        isAutoSwitching = true
                                        currentSourceIndex = finalNextSourceIndex
                                        retryCount = 0 // 重置重试计数
                                        val newUrl = sources[currentSourceIndex]
                                        currentUrl = newUrl
                                        
                                        updateSourceIndicator()
                                        showSourceIndicator()
                                        playUrl(newUrl)
                                    } else {
                                        // 尝试 Fallback 到下一个源（如果有的话）
                                        val fallbackIndex = currentSourceIndex + 1
                                        if (fallbackIndex < sources.size) {
                                            Log.d(TAG, "自动检测全部失败，Fallback：强制尝试下一个 ${fallbackIndex + 1}")
                                            isAutoSwitching = true
                                            currentSourceIndex = fallbackIndex
                                            retryCount = 0
                                            val newUrl = sources[currentSourceIndex]
                                            currentUrl = newUrl
                                            
                                            updateSourceIndicator()
                                            showSourceIndicator()
                                            playUrl(newUrl)
                                        } else {
                                            // 所有源都不可用，显示错误
                                            Log.d(TAG, "所有 ${sources.size} 个源都不可用，全部失败")
                                            showError("播放失败: ${error.message}")
                                            updateStatus("Offline")
                                        }
                                    }
                                }
                            }.start()
                        } else {
                            // 只有一个源，直接显示错误
                            showError("播放失败: ${error.message}")
                            updateStatus("Offline")
                        }
                    }
                }
            })
            
            exoPlayer.addAnalyticsListener(object : AnalyticsListener {
                override fun onVideoDecoderInitialized(
                    eventTime: AnalyticsListener.EventTime,
                    decoderName: String,
                    initializedTimestampMs: Long,
                    initializationDurationMs: Long
                ) {
                    isHardwareDecoder = decoderName.contains("c2.") || 
                                       decoderName.contains("OMX.") ||
                                       !decoderName.contains("sw")
                    videoCodec = decoderName
                    updateVideoInfoDisplay()
                }
                
                override fun onVideoInputFormatChanged(
                    eventTime: AnalyticsListener.EventTime,
                    format: Format,
                    decoderReuseEvaluation: DecoderReuseEvaluation?
                ) {
                    // 只从 format 获取 codec 信息，帧率通过渲染帧数计算
                    format.codecs?.let { 
                        if (it.isNotEmpty()) videoCodec = it 
                    }
                    updateVideoInfoDisplay()
                }
            })
        }
    }
    
    // 解析真实播放地址（处理302重定向，带缓存）
    private fun resolveRealPlayUrl(url: String): String {
        // 检查缓存
        val cached = redirectCache[url]
        if (cached != null) {
            val (cachedUrl, timestamp) = cached
            if (System.currentTimeMillis() - timestamp < CACHE_EXPIRY_MS) {
                Log.d(TAG, "使用缓存的重定向: $url -> $cachedUrl")
                return cachedUrl
            } else {
                // 缓存过期，移除
                redirectCache.remove(url)
            }
        }
        
        return try {
            val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", "miguvideo_android")
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            
            connection.connect()
            
            if (connection.responseCode in 300..399) {
                val location = connection.getHeaderField("Location")
                connection.disconnect()
                
                if (location != null) {
                    Log.d(TAG, "解析重定向: $url -> $location")
                    // 缓存结果
                    redirectCache[url] = Pair(location, System.currentTimeMillis())
                    location
                } else {
                    Log.d(TAG, "无 Location 头，使用原始 URL: $url")
                    url
                }
            } else {
                connection.disconnect()
                Log.d(TAG, "无重定向，使用原始 URL: $url")
                url
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析播放地址失败: ${e.message}", e)
            // 失败时返回原始 URL，让播放器尝试
            url
        }
    }
    
    private fun playUrl(url: String) {
        Log.d(TAG, "Playing URL: $url")
        videoWidth = 0
        videoHeight = 0
        frameRate = 0f
        stopFpsCalculation()
        updateVideoInfoDisplay()
        
        showLoading()
        updateStatus("Loading")
        
        // 在后台线程解析真实地址
        Thread {
            val realUrl = resolveRealPlayUrl(url)
            
            activity?.runOnUiThread {
                Log.d(TAG, "使用播放地址: $realUrl")
                val mediaItem = MediaItem.fromUri(realUrl)
                player?.setMediaItem(mediaItem)
                player?.prepare()
            }
        }.start()
    }
    
    // 通过渲染帧数计算实际 FPS
    private fun startFpsCalculation() {
        stopFpsCalculation()
        lastRenderedFrameCount = 0L
        lastFpsUpdateTime = System.currentTimeMillis()
        
        fpsUpdateRunnable = Runnable {
            calculateFps()
            handler.postDelayed(fpsUpdateRunnable!!, FPS_UPDATE_INTERVAL)
        }
        handler.postDelayed(fpsUpdateRunnable!!, FPS_UPDATE_INTERVAL)
    }
    
    private fun stopFpsCalculation() {
        fpsUpdateRunnable?.let { handler.removeCallbacks(it) }
        fpsUpdateRunnable = null
    }
    
    private fun calculateFps() {
        val p = player ?: return
        
        // 播放器不在播放状态时不计算，但要更新时间戳
        if (!p.isPlaying) {
            lastFpsUpdateTime = System.currentTimeMillis()
            lastRenderedFrameCount = 0L
            return
        }
        
        val currentTime = System.currentTimeMillis()
        val timeDelta = currentTime - lastFpsUpdateTime
        
        // 时间间隔太短，跳过（但不更新时间戳，等下次累积）
        if (timeDelta < 800) return
        
        try {
            // 从 videoDecoderCounters 获取渲染帧数
            val counters = p.videoDecoderCounters
            if (counters != null) {
                val currentFrames = counters.renderedOutputBufferCount.toLong()
                
                if (lastRenderedFrameCount > 0 && currentFrames > lastRenderedFrameCount) {
                    val frameDelta = currentFrames - lastRenderedFrameCount
                    val calculatedFps = frameDelta * 1000f / timeDelta
                    
                    // 合理范围内才更新 (10-120 fps)
                    if (calculatedFps in 10f..120f) {
                        frameRate = calculatedFps
                        updateVideoInfoDisplay()
                    }
                }
                
                lastRenderedFrameCount = currentFrames
                lastFpsUpdateTime = currentTime
            }
        } catch (e: Exception) {
            Log.d(TAG, "Failed to calculate FPS: ${e.message}")
        }
    }
    
    // 时钟更新
    private fun startClockUpdate() {
        stopClockUpdate()
        clockUpdateRunnable = Runnable {
            updateClock()
            handler.postDelayed(clockUpdateRunnable!!, CLOCK_UPDATE_INTERVAL)
        }
        handler.post(clockUpdateRunnable!!)
    }
    
    private fun stopClockUpdate() {
        clockUpdateRunnable?.let { handler.removeCallbacks(it) }
        clockUpdateRunnable = null
    }
    
    private fun updateClock() {
        activity?.runOnUiThread {
            val sdf = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            clockText.text = sdf.format(java.util.Date())
            // 根据设置显示/隐藏时钟
            clockText.visibility = if (showClock) View.VISIBLE else View.GONE
        }
    }

    // 网速更新
    private fun startNetworkSpeedUpdate() {
        stopNetworkSpeedUpdate()
        lastRxBytes = TrafficStats.getTotalRxBytes()
        lastSpeedUpdateTime = System.currentTimeMillis()
        
        networkSpeedUpdateRunnable = Runnable {
            updateNetworkSpeed()
            handler.postDelayed(networkSpeedUpdateRunnable!!, NETWORK_SPEED_UPDATE_INTERVAL)
        }
        handler.postDelayed(networkSpeedUpdateRunnable!!, NETWORK_SPEED_UPDATE_INTERVAL)
    }

    private fun stopNetworkSpeedUpdate() {
        networkSpeedUpdateRunnable?.let { handler.removeCallbacks(it) }
        networkSpeedUpdateRunnable = null
    }

    private fun updateNetworkSpeed() {
        if (!showNetworkSpeed) {
            activity?.runOnUiThread {
                speedText.visibility = View.GONE
            }
            return
        }

        try {
            val currentRxBytes = TrafficStats.getTotalRxBytes()
            val currentTime = System.currentTimeMillis()
            val timeDelta = currentTime - lastSpeedUpdateTime
            
            val speedStr: String
            if (timeDelta > 0 && lastRxBytes > 0) {
                val bytesDelta = currentRxBytes - lastRxBytes
                val speedBytesPerSecond = bytesDelta * 1000.0 / timeDelta
                currentSpeedBps = speedBytesPerSecond // 保存当前网速用于码率显示
                val speedKbps = speedBytesPerSecond / 1024.0 // KB/s
                val speedMbps = speedKbps / 1024.0 // MB/s

                speedStr = if (speedMbps >= 1.0) {
                    "↓%.1f MB/s".format(speedMbps)
                } else if (speedKbps >= 1.0) {
                    "↓%.0f KB/s".format(speedKbps)
                } else {
                    "↓%.0f B/s".format(speedBytesPerSecond)
                }
            } else {
                speedStr = "↓--"
            }
            
            lastRxBytes = currentRxBytes
            lastSpeedUpdateTime = currentTime

            activity?.runOnUiThread {
                this.speedText.text = speedStr
                this.speedText.visibility = View.VISIBLE
            }
        } catch (e: Exception) {
            Log.d(TAG, "Failed to update network speed: ${e.message}")
            activity?.runOnUiThread {
                speedText.visibility = View.GONE
            }
        }
    }
    
    // 获取当前频道的所有源
    private fun getCurrentSources(): List<String> {
        return if (currentIndex >= 0 && currentIndex < channelSources.size) {
            channelSources[currentIndex]
        } else if (currentIndex >= 0 && currentIndex < channelUrls.size) {
            listOf(channelUrls[currentIndex])
        } else {
            listOf(currentUrl)
        }
    }
    
    // 检查当前频道是否有多个源
    private fun hasMultipleSources(): Boolean {
        return getCurrentSources().size > 1
    }
    
    // 切换到下一个源（循环检测直到找到可用源）
    private fun nextSource() {
        switchSourceIteratively(1)
    }
    
    // 切换到上一个源（循环检测直到找到可用源）
    private fun previousSource() {
        switchSourceIteratively(-1)
    }

    // 循环切换源的通用逻辑
    private fun switchSourceIteratively(direction: Int) {
        val sources = getCurrentSources()
        if (sources.size <= 1) return
        
        // 防止重复手动切换
        if (isManualSwitching) {
            activity?.let {
                android.widget.Toast.makeText(it, "正在检测源，请稍候...", android.widget.Toast.LENGTH_SHORT).show()
            }
            return
        }
        
        // 增加验证 ID，立即使所有之前的后台任务失效
        currentVerificationId++
        val myVerificationId = currentVerificationId
        
        // 取消正在进行的自动检测和重试
        isAutoDetecting = false
        retryRunnable?.let { handler.removeCallbacks(it) }
        
        // 手动切换源时重置状态
        retryCount = 0
        isAutoSwitching = false
        
        // 锁定
        isManualSwitching = true
        
        showControls()
        showLoading()
        updateStatus("正在寻找可用源...")
        
        val startIndex = currentSourceIndex
        
        Thread {
            if (myVerificationId != currentVerificationId) {
                activity?.runOnUiThread { isManualSwitching = false }
                return@Thread
            }
            
            try {
                var found = false
                var loopCount = 0
                // 根据方向计算起始检查点
                var indexToCheck = if (direction > 0) {
                    (startIndex + 1) % sources.size
                } else {
                    (startIndex - 1 + sources.size) % sources.size
                }
                
                // 循环检测，最多尝试 sources.size 次
                while (loopCount < sources.size) {
                    if (myVerificationId != currentVerificationId) {
                        activity?.runOnUiThread { isManualSwitching = false }
                        return@Thread
                    }

                    // 如果回到了起点，且不是第一次检查，则停止
                    if (indexToCheck == startIndex) {
                        break
                    }

                    activity?.runOnUiThread {
                        if (myVerificationId == currentVerificationId) {
                            updateStatus("检测源 ${indexToCheck + 1}/${sources.size}")
                            showControls()
                        }
                    }
                    
                    Log.d(TAG, "检测源 ${indexToCheck + 1}/${sources.size}: ${sources[indexToCheck]}")
                    if (testSource(sources[indexToCheck])) {
                        found = true
                        break
                    }
                    
                    Log.d(TAG, "源 ${indexToCheck + 1} 不可用，尝试下一个")
                    
                    // 继续下一个
                    if (direction > 0) {
                        indexToCheck = (indexToCheck + 1) % sources.size
                    } else {
                        indexToCheck = (indexToCheck - 1 + sources.size) % sources.size
                    }
                    loopCount++
                }
                
                if (myVerificationId != currentVerificationId) {
                    activity?.runOnUiThread { isManualSwitching = false }
                    return@Thread
                }
                
                val finalIndex = indexToCheck
                activity?.runOnUiThread {
                    if (myVerificationId != currentVerificationId) {
                        isManualSwitching = false
                        return@runOnUiThread
                    }
                    
                    // 解锁
                    isManualSwitching = false
                    
                    if (found) {
                        Log.d(TAG, "找到可用源 ${finalIndex + 1}，切换")
                        currentSourceIndex = finalIndex
                        currentUrl = sources[currentSourceIndex]
                        updateSourceIndicator()
                        playUrl(currentUrl)
                    } else {
                        Log.d(TAG, "未找到其他可用源 (全部检测失败)，强制尝试下一个源")
                        // Fallback
                        val fallbackIndex = if (direction > 0) {
                            (startIndex + 1) % sources.size
                        } else {
                            (startIndex - 1 + sources.size) % sources.size
                        }
                        
                        currentSourceIndex = fallbackIndex
                        currentUrl = sources[currentSourceIndex]
                        updateSourceIndicator()
                        playUrl(currentUrl)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Source switching error: ${e.message}")
                activity?.runOnUiThread {
                    isManualSwitching = false
                    hideLoading()
                }
            }
        }.start()
    }
    
    // 显示源切换指示器
    private fun showSourceIndicator() {
        updateSourceIndicator()
    }
    
    // 更新源指示器显示
    private fun updateSourceIndicator() {
        val sources = getCurrentSources()
        activity?.runOnUiThread {
            if (sources.size > 1) {
                // 更新源指示器文本
                sourceText.text = getString(R.string.source_indicator, currentSourceIndex + 1, sources.size)
                sourceIndicator.visibility = View.VISIBLE
                // 频道名称不再显示源信息
                channelNameText.text = currentName
            } else {
                channelNameText.text = currentName
                sourceIndicator.visibility = View.GONE
            }
        }
    }
    
    private fun switchChannel(newIndex: Int) {
        Log.d(TAG, "=== switchChannel 被调用 ===")
        Log.d(TAG, "新频道索引: $newIndex, 总频道数: ${channelUrls.size}")
        
        if (channelUrls.isEmpty() || newIndex < 0 || newIndex >= channelUrls.size) {
            Log.e(TAG, "无效的频道索引")
            return
        }
        
        // 增加验证 ID，立即使所有之前的后台任务失效
        currentVerificationId++
        val myVerificationId = currentVerificationId
        
        // 重置手动切换状态
        isManualSwitching = false
        
        // 立即停止当前播放，给予"已切换"的反馈
        player?.stop()
        player?.clearMediaItems()
        
        // 重置重试计数和取消自动检测
        retryCount = 0
        isAutoSwitching = false
        isAutoDetecting = false
        retryRunnable?.let { handler.removeCallbacks(it) }
        
        currentIndex = newIndex
        currentSourceIndex = 0 // 重置源索引
        currentUrl = channelUrls[newIndex]
        currentName = if (newIndex < channelNames.size) channelNames[newIndex] else "Channel ${newIndex + 1}"
        
        // 更新进度条可见性
        updateProgressBarVisibility()
        
        // 立即显示控制栏（频道信息等）
        showControls()
        // 更新EPG信息
        refreshEpgInfo()
        
        Log.d(TAG, "切换到频道: $currentName")
        
        // 检测并使用第一个可用的源
        val sources = getCurrentSources()
        Log.d(TAG, "频道有 ${sources.size} 个源")
        
        if (sources.size > 1) {
            Log.d(TAG, "开始在后台线程检测源...")
            
            // 显示正在检测的状态
            updateStatus("检测源...")
            showLoading()
            
            // 在后台线程检测源
            Thread {
                if (myVerificationId != currentVerificationId) return@Thread
                
                var foundSourceIndex = 0
                for (i in sources.indices) {
                    // 如果已经进行了新的操作，立即停止
                    if (myVerificationId != currentVerificationId) return@Thread
                    
                    // 实时更新UI显示当前检测的源
                    activity?.runOnUiThread {
                        if (myVerificationId != currentVerificationId) return@runOnUiThread
                        updateStatus("检测源 ${i + 1}/${sources.size}")
                        currentSourceIndex = i
                        updateSourceIndicator()
                        showControls()
                    }
                    
                    Log.d(TAG, "检测源 ${i + 1}/${sources.size}: ${sources[i]}")
                    if (testSource(sources[i])) {
                        foundSourceIndex = i
                        Log.d(TAG, "✓ 源 ${i + 1} 可用")
                        break
                    } else {
                        Log.d(TAG, "✗ 源 ${i + 1} 不可用")
                    }
                }
                
                if (myVerificationId != currentVerificationId) return@Thread
                
                val finalSourceIndex = foundSourceIndex
                activity?.runOnUiThread {
                    if (myVerificationId != currentVerificationId) return@runOnUiThread
                    
                    currentSourceIndex = finalSourceIndex
                    val urlToPlay = sources[currentSourceIndex]
                    Log.d(TAG, "使用源 ${currentSourceIndex + 1}/${sources.size}: $urlToPlay")
                    
                    updateSourceIndicator()
                    playUrl(urlToPlay)
                    
                    // 检查新频道的收藏状态
                    checkInitialFavoriteStatus()
                    
                    showControls()
                }
            }.start()
        } else {
            Log.d(TAG, "频道只有一个源，直接播放")
            val urlToPlay = if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                sources[currentSourceIndex]
            } else {
                currentUrl
            }
            
            updateSourceIndicator()
            playUrl(urlToPlay)
            
            // 检查新频道的收藏状态
            checkInitialFavoriteStatus()
            
            showControls()
        }
    }

    private fun refreshEpgInfo() {
        // 简单检查是否attached
        if (!isAdded || activity == null) return

        if (isDlnaMode || channelNames.isEmpty() || currentIndex < 0 || currentIndex >= channelNames.size) {
             activity?.runOnUiThread {
                 try {
                     if (view != null) epgContainer.visibility = View.GONE
                 } catch (e: Exception) {}
             }
             return
        }
        
        val name = channelNames[currentIndex]
        val epgId = if (currentIndex < channelEpgIds.size) channelEpgIds[currentIndex] else ""
        
        (activity as? MainActivity)?.requestEpgInfo(name, epgId) { result ->
            activity?.runOnUiThread {
                try {
                    if (view == null) return@runOnUiThread
                    
                    if (result != null) {
                        val currentTitle = result["currentTitle"] as? String
                        val nextTitle = result["nextTitle"] as? String
                        
                        var hasContent = false
                        
                        if (!currentTitle.isNullOrEmpty()) {
                            epgCurrentTitle.text = currentTitle
                            epgCurrentContainer.visibility = View.VISIBLE
                            hasContent = true
                        } else {
                            epgCurrentContainer.visibility = View.GONE
                        }
                        
                        if (!nextTitle.isNullOrEmpty()) {
                            epgNextTitle.text = nextTitle
                            epgNextContainer.visibility = View.VISIBLE
                            hasContent = true
                        } else {
                            epgNextContainer.visibility = View.GONE
                        }
                        
                        epgContainer.visibility = if (hasContent) View.VISIBLE else View.GONE
                    } else {
                        epgContainer.visibility = View.GONE
                    }
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
    
    // 检测源是否可用（在后台线程执行）
    private fun testSource(url: String): Boolean {
        return try {
            val urlConnection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            urlConnection.connectTimeout = 1500 // 1.5秒超时
            urlConnection.readTimeout = 1500
            urlConnection.requestMethod = "HEAD" // 使用HEAD请求，更快
            urlConnection.setRequestProperty("User-Agent", "Mozilla/5.0")
            urlConnection.setRequestProperty("Accept", "*/*")
            urlConnection.setRequestProperty("Connection", "keep-alive")
            
            val responseCode = urlConnection.responseCode
            urlConnection.disconnect()
            
            val isAvailable = responseCode in 200..399
            Log.d(TAG, "testSource: $url -> $responseCode (${if (isAvailable) "可用" else "不可用"})")
            isAvailable
        } catch (e: Exception) {
            Log.d(TAG, "testSource: $url -> 异常: ${e.message}")
            false
        }
    }
    
    private fun nextChannel() {
        if (channelUrls.isEmpty()) return
        val newIndex = if (currentIndex < channelUrls.size - 1) currentIndex + 1 else 0
        switchChannel(newIndex)
    }
    
    private fun previousChannel() {
        if (channelUrls.isEmpty()) return
        val newIndex = if (currentIndex > 0) currentIndex - 1 else channelUrls.size - 1
        switchChannel(newIndex)
    }

    private fun updateStatus(status: String) {
        activity?.runOnUiThread {
            statusText.text = status
            val color = when (status) {
                "LIVE" -> 0xFF4CAF50.toInt()  // Green
                "Buffering", "Loading" -> 0xFFFF9800.toInt()  // Orange
                "Paused" -> 0xFF2196F3.toInt()  // Blue
                "Offline", "Error" -> 0xFFF44336.toInt()  // Red
                else -> 0xFF9E9E9E.toInt()  // Gray
            }
            statusText.setTextColor(color)
            
            // Update indicator dot color
            val drawable = android.graphics.drawable.GradientDrawable()
            drawable.shape = android.graphics.drawable.GradientDrawable.OVAL
            drawable.setColor(color)
            statusIndicator.background = drawable
        }
    }

    private fun updateVideoInfoDisplay() {
        activity?.runOnUiThread {
            val parts = mutableListOf<String>()
            if (videoWidth > 0 && videoHeight > 0) {
                parts.add("${videoWidth}x${videoHeight}")
            }
            if (frameRate > 0) {
                parts.add("${frameRate.toInt()}fps")
            }
            if (isHardwareDecoder) {
                parts.add(getString(R.string.hardware_decode))
            } else {
                parts.add(getString(R.string.software_decode))
            }
            
            if (parts.isNotEmpty()) {
                videoInfoText.text = parts.joinToString(" · ")
                videoInfoText.visibility = View.VISIBLE
            } else {
                videoInfoText.visibility = View.GONE
            }
            
            // 更新右上角 FPS 显示
            if (showFps && frameRate > 0) {
                fpsText.text = "${frameRate.toInt()} FPS"
                fpsText.visibility = View.VISIBLE
            } else {
                fpsText.visibility = View.GONE
            }

            // 更新右上角分辨率显示（不显示码率）
            if (showVideoInfo && videoWidth > 0 && videoHeight > 0) {
                val resInfo = "${videoWidth}x${videoHeight}"
                resolutionText.text = resInfo
                resolutionText.visibility = View.VISIBLE
            } else {
                resolutionText.visibility = View.GONE
            }
        }
    }

    private fun showLoading() {
        loadingIndicator.visibility = View.VISIBLE
        errorText.visibility = View.GONE
    }

    private fun hideLoading() {
        loadingIndicator.visibility = View.GONE
        errorText.visibility = View.GONE
    }

    private fun showError(message: String) {
        loadingIndicator.visibility = View.GONE
        errorText.visibility = View.VISIBLE
        errorText.text = message
    }
    
    private fun showControls() {
        controlsVisible = true
        topBar.visibility = View.VISIBLE
        bottomBar.visibility = View.VISIBLE
        topBar.animate().alpha(1f).setDuration(200).start()
        bottomBar.animate().alpha(1f).setDuration(200).start()
        scheduleHideControls()
        updateEpgInfo()
    }
    
    private fun updateEpgInfo() {
        // Request EPG info from Flutter via MethodChannel
        val activity = activity as? MainActivity ?: return
        activity.getEpgInfo(currentName) { epgInfo ->
            activity.runOnUiThread {
                if (epgInfo != null) {
                    val currentTitle = epgInfo["currentTitle"] as? String
                    val currentRemaining = epgInfo["currentRemaining"] as? Int
                    val nextTitle = epgInfo["nextTitle"] as? String
                    
                    if (currentTitle != null || nextTitle != null) {
                        epgContainer.visibility = View.VISIBLE
                        
                        if (currentTitle != null) {
                            epgCurrentContainer.visibility = View.VISIBLE
                            epgCurrentTitle.text = currentTitle
                            epgCurrentTime.text = if (currentRemaining != null) getString(R.string.epg_ends_in_minutes, currentRemaining) else ""
                        } else {
                            epgCurrentContainer.visibility = View.GONE
                        }
                        
                        if (nextTitle != null) {
                            epgNextContainer.visibility = View.VISIBLE
                            epgNextTitle.text = nextTitle
                        } else {
                            epgNextContainer.visibility = View.GONE
                        }
                    } else {
                        epgContainer.visibility = View.GONE
                    }
                } else {
                    epgContainer.visibility = View.GONE
                }
            }
        }
    }
    
    private fun hideControls() {
        controlsVisible = false
        topBar.animate().alpha(0f).setDuration(200).withEndAction {
            if (!controlsVisible) {
                topBar.visibility = View.GONE
            }
        }.start()
        bottomBar.animate().alpha(0f).setDuration(200).withEndAction {
            if (!controlsVisible) {
                bottomBar.visibility = View.GONE
            }
        }.start()
    }
    
    private fun scheduleHideControls() {
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        hideControlsRunnable = Runnable { 
            // 只要不在分类面板中，就隐藏控制栏
            if (!categoryPanelVisible) {
                hideControls() 
            }
        }
        handler.postDelayed(hideControlsRunnable!!, CONTROLS_HIDE_DELAY)
    }
    
    // DLNA 模式：启动进度更新
    private fun startProgressUpdate() {
        progressUpdateRunnable?.let { handler.removeCallbacks(it) }
        progressUpdateRunnable = Runnable {
            updateProgress()
            handler.postDelayed(progressUpdateRunnable!!, PROGRESS_UPDATE_INTERVAL)
        }
        handler.post(progressUpdateRunnable!!)
    }
    
    // DLNA 模式：停止进度更新
    private fun stopProgressUpdate() {
        progressUpdateRunnable?.let { handler.removeCallbacks(it) }
        progressUpdateRunnable = null
    }
    
    // 更新进度条可见性（根据内容类型、DLNA 模式和用户设置）
    private fun updateProgressBarVisibility() {
        Log.d(TAG, "=== updateProgressBarVisibility 被调用 ===")
        Log.d(TAG, "progressBarMode: $progressBarMode")
        Log.d(TAG, "isDlnaMode: $isDlnaMode")
        Log.d(TAG, "currentIndex: $currentIndex")
        Log.d(TAG, "channelIsSeekable.size: ${channelIsSeekable.size}")
        
        // 根据用户设置决定是否显示进度条
        val shouldShow = when (progressBarMode) {
            "never" -> {
                Log.d(TAG, "模式: never - 不显示进度条")
                false  // 从不显示
            }
            "always" -> {
                Log.d(TAG, "模式: always - 始终显示进度条")
                true  // 始终显示
            }
            "auto" -> {  // 自动检测
                // DLNA 模式或可拖动内容显示进度条
                val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                    channelIsSeekable[currentIndex]
                } else {
                    false
                }
                Log.d(TAG, "模式: auto - currentIsSeekable: $currentIsSeekable")
                val result = isDlnaMode || currentIsSeekable
                Log.d(TAG, "模式: auto - 结果: $result")
                result
            }
            else -> {  // 默认自动检测
                Log.d(TAG, "模式: 未知($progressBarMode) - 使用默认自动检测")
                val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                    channelIsSeekable[currentIndex]
                } else {
                    false
                }
                Log.d(TAG, "默认模式 - currentIsSeekable: $currentIsSeekable")
                val result = isDlnaMode || currentIsSeekable
                Log.d(TAG, "默认模式 - 结果: $result")
                result
            }
        }
        
        Log.d(TAG, "最终决定: shouldShow = $shouldShow")
        
        if (shouldShow) {
            // 显示进度条
            Log.d(TAG, "显示进度条，隐藏帮助文字")
            progressContainer.visibility = View.VISIBLE
            helpText.visibility = View.GONE
            if (!isDlnaMode) {
                // 非 DLNA 模式的可拖动内容也需要启动进度更新
                Log.d(TAG, "启动进度更新")
                startProgressUpdate()
            }
            // 不自动请求焦点，让用户通过按键主动激活
        } else {
            // 隐藏进度条，显示帮助文字
            Log.d(TAG, "隐藏进度条，显示帮助文字")
            progressContainer.visibility = View.GONE
            helpText.visibility = View.VISIBLE
            if (!isDlnaMode) {
                Log.d(TAG, "停止进度更新")
                stopProgressUpdate()
            }
        }
    }
    
    // DLNA 模式：更新进度条
    private fun updateProgress() {
        val p = player ?: return
        val position = p.currentPosition
        val duration = p.duration
        
        if (duration > 0) {
            val progress = (position * 100 / duration).toInt()
            progressBar.progress = progress
            progressCurrent.text = formatTime(position)
            progressDuration.text = formatTime(duration)
        }
    }
    
    // 格式化时间 (毫秒 -> HH:MM:SS 或 MM:SS)
    private fun formatTime(ms: Long): String {
        val totalSeconds = ms / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }
    
    private fun toggleFavorite() {
        Log.d(TAG, "toggleFavorite called: currentIndex=$currentIndex, isDlnaMode=$isDlnaMode")
        if (currentIndex < 0 || isDlnaMode) {
            Log.d(TAG, "toggleFavorite: skipped - invalid index or DLNA mode")
            return
        }
        
        val activity = activity as? MainActivity
        if (activity == null) {
            Log.e(TAG, "toggleFavorite: activity is null")
            return
        }
        
        Log.d(TAG, "toggleFavorite: calling MainActivity.toggleFavorite")
        activity.toggleFavorite(currentIndex) { newFavoriteStatus ->
            Log.d(TAG, "toggleFavorite callback: newFavoriteStatus=$newFavoriteStatus")
            activity.runOnUiThread {
                if (newFavoriteStatus != null) {
                    isFavorite = newFavoriteStatus
                    updateFavoriteIcon()
                    val message = if (newFavoriteStatus) {
                        getString(R.string.added_to_favorites)
                    } else {
                        getString(R.string.removed_from_favorites)
                    }
                    android.widget.Toast.makeText(requireContext(), message, android.widget.Toast.LENGTH_SHORT).show()
                } else {
                    Log.e(TAG, "toggleFavorite: operation failed")
                    android.widget.Toast.makeText(requireContext(), getString(R.string.operation_failed), android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun updateFavoriteIcon() {
        favoriteIcon.visibility = if (isFavorite) View.VISIBLE else View.GONE
    }
    
    private fun checkInitialFavoriteStatus() {
        if (currentIndex < 0 || isDlnaMode) return
        
        val activity = activity as? MainActivity ?: return
        activity.isFavorite(currentIndex) { favoriteStatus ->
            activity.runOnUiThread {
                isFavorite = favoriteStatus
                updateFavoriteIcon()
                Log.d(TAG, "Initial favorite status: $isFavorite for channel index $currentIndex")
            }
        }
    }
    
    private fun closePlayer() {
        Log.d(TAG, "closePlayer called")
        try {
            player?.stop()
            player?.release()
            player = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing player", e)
        }
        onCloseListener?.invoke()
    }
    
    // DLNA control methods
    fun pause() {
        activity?.runOnUiThread {
            player?.pause()
        }
    }
    
    fun play() {
        activity?.runOnUiThread {
            player?.play()
        }
    }
    
    fun seekTo(positionMs: Long) {
        activity?.runOnUiThread {
            player?.seekTo(positionMs)
        }
    }
    
    fun setVolume(volume: Int) {
        activity?.runOnUiThread {
            player?.volume = volume / 100f
        }
    }
    
    fun getPlaybackState(): Map<String, Any?> {
        val p = player
        return mapOf(
            "isPlaying" to (p?.isPlaying ?: false),
            "position" to (p?.currentPosition ?: 0L),
            "duration" to (p?.duration ?: 0L),
            "fps" to frameRate,
            "state" to when (p?.playbackState) {
                Player.STATE_IDLE -> "idle"
                Player.STATE_BUFFERING -> "buffering"
                Player.STATE_READY -> if (p.isPlaying) "playing" else "paused"
                Player.STATE_ENDED -> "ended"
                else -> "unknown"
            }
        )
    }

    fun getCurrentChannelIndex(): Int {
        return currentIndex
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
        // 确保屏幕常亮
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // 检查播放器状态，如果播放器存在但没有在播放，尝试恢复播放
        player?.let { p ->
            if (p.playbackState == Player.STATE_IDLE || p.playbackState == Player.STATE_ENDED) {
                // 播放器处于空闲或结束状态，需要重新加载
                Log.d(TAG, "Player in IDLE/ENDED state, reloading media...")
                val sources = getCurrentSources()
                if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                    val urlToPlay = sources[currentSourceIndex]
                    playUrl(urlToPlay)
                }
            } else {
                // 播放器状态正常，直接恢复播放
                p.playWhenReady = true
            }
        } ?: run {
            // 播放器不存在，重新初始化并播放
            Log.d(TAG, "Player is null, reinitializing...")
            initializePlayer()
            val sources = getCurrentSources()
            if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                val urlToPlay = sources[currentSourceIndex]
                playUrl(urlToPlay)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause")
        player?.playWhenReady = false
    }

    override fun onDestroyView() {
        super.onDestroyView()
        Log.d(TAG, "onDestroyView")
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        retryRunnable?.let { handler.removeCallbacks(it) }
        sourceIndicatorHideRunnable?.let { handler.removeCallbacks(it) }
        stopProgressUpdate() // 停止进度更新
        stopFpsCalculation() // 停止 FPS 计算
        stopClockUpdate() // 停止时钟更新
        stopNetworkSpeedUpdate() // 停止网速更新
        redirectCache.clear() // 清除重定向缓存
        player?.release()
        player = null
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    
    // Data classes
    data class CategoryItem(val name: String, val count: Int)
    data class ChannelItem(val index: Int, val name: String, val isPlaying: Boolean)
    
    // ViewHolders
    class CategoryViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val nameText: TextView = view.findViewById(R.id.category_name)
        val countText: TextView = view.findViewById(R.id.category_count)
    }
    
    class ChannelViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val nameText: TextView = view.findViewById(R.id.channel_name)
        val playingIcon: ImageView = view.findViewById(R.id.playing_icon)
    }
}
