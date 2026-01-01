package com.flutteriptv.flutter_iptv

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
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

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

    private var currentUrl: String = ""
    private var currentName: String = ""
    private var currentIndex: Int = 0
    private var currentSourceIndex: Int = 0 // 当前源索引
    
    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    private var channelGroups: ArrayList<String> = arrayListOf()
    private var channelSources: ArrayList<ArrayList<String>> = arrayListOf() // 每个频道的所有源
    private var isDlnaMode: Boolean = false
    private var bufferStrength: String = "fast"
    
    // Category data
    private var categories: MutableList<CategoryItem> = mutableListOf()
    private var selectedCategoryIndex: Int = -1
    private var categoryPanelVisible = false
    private var showingChannelList = false
    
    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private var controlsVisible = true
    private val CONTROLS_HIDE_DELAY = 3000L
    
    private var lastBackPressTime = 0L
    private val BACK_PRESS_INTERVAL = 2000L // 2秒内按两次返回才退出
    
    private var videoWidth = 0
    private var videoHeight = 0
    private var videoCodec = ""
    private var isHardwareDecoder = false
    private var frameRate = 0f
    
    // Retry logic
    private var retryCount = 0
    private val MAX_RETRIES = 3
    private val RETRY_DELAY = 2000L
    private var retryRunnable: Runnable? = null
    
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
    
    var onCloseListener: (() -> Unit)? = null

    companion object {
        private const val ARG_VIDEO_URL = "video_url"
        private const val ARG_CHANNEL_NAME = "channel_name"
        private const val ARG_CHANNEL_INDEX = "channel_index"
        private const val ARG_CHANNEL_URLS = "channel_urls"
        private const val ARG_CHANNEL_NAMES = "channel_names"
        private const val ARG_CHANNEL_GROUPS = "channel_groups"
        private const val ARG_CHANNEL_SOURCES = "channel_sources"
        private const val ARG_IS_DLNA_MODE = "is_dlna_mode"
        private const val ARG_BUFFER_STRENGTH = "buffer_strength"
        private const val ARG_SHOW_FPS = "show_fps"

        fun newInstance(
            videoUrl: String,
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null,
            channelGroups: ArrayList<String>? = null,
            channelSources: ArrayList<ArrayList<String>>? = null,
            isDlnaMode: Boolean = false,
            bufferStrength: String = "fast",
            showFps: Boolean = true
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
                    putBoolean(ARG_IS_DLNA_MODE, isDlnaMode)
                    putString(ARG_BUFFER_STRENGTH, bufferStrength)
                    putBoolean(ARG_SHOW_FPS, showFps)
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
            isDlnaMode = it.getBoolean(ARG_IS_DLNA_MODE, false)
            bufferStrength = it.getString(ARG_BUFFER_STRENGTH, "fast") ?: "fast"
            showFps = it.getBoolean(ARG_SHOW_FPS, true)
            currentSourceIndex = 0 // 初始化为第一个源
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
        
        // FPS display
        fpsText = view.findViewById(R.id.fps_text)
        
        // Clock display
        clockText = view.findViewById(R.id.clock_text)
        
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
        
        // DLNA 模式：显示进度条，隐藏帮助文字
        if (isDlnaMode) {
            progressContainer.visibility = View.VISIBLE
            helpText.visibility = View.GONE
            startProgressUpdate()
        } else {
            progressContainer.visibility = View.GONE
            helpText.visibility = View.VISIBLE
        }
        
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
            // 使用第一个源播放
            val sources = getCurrentSources()
            val urlToPlay = if (sources.isNotEmpty()) sources[0] else currentUrl
            playUrl(urlToPlay)
            updateSourceIndicator()
        } else {
            showError("No video URL provided")
        }
        
        // Start clock update
        startClockUpdate()
        
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
            val name = group.ifEmpty { "未分类" }
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
        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { "未分类" }
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
            channelGroups[currentIndex].ifEmpty { "未分类" }
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
        
        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { "未分类" }
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
                android.widget.Toast.makeText(requireContext(), "再按一次返回退出播放", android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }

    private fun handleKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode, categoryPanelVisible=$categoryPanelVisible, isDlnaMode=$isDlnaMode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                return handleBackKey()
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (!categoryPanelVisible) {
                    showControls()
                    player?.let {
                        if (it.isPlaying) it.pause() else it.play()
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
                // 如果长按已处理，忽略后续的重复事件直到松开
                if (longPressHandled) {
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
                }
                // 检测长按 - 显示分类面板
                if (event.repeatCount > 0 && !longPressHandled && System.currentTimeMillis() - leftKeyDownTime >= LONG_PRESS_THRESHOLD) {
                    longPressHandled = true // 标记长按已处理，防止重复触发
                    showCategoryPanel()
                    return true
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
                // 如果有多个源，切换到下一个源
                if (!categoryPanelVisible && hasMultipleSources()) {
                    nextSource()
                    return true
                }
                // 直播流禁用快进
                if (!categoryPanelVisible) {
                    showControls()
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
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                // 重置长按标志
                val wasLongPressHandled = longPressHandled
                longPressHandled = false
                
                // 如果是长按触发的，不再处理
                if (wasLongPressHandled) {
                    leftKeyDownTime = 0L
                    return true
                }
                
                // DLNA 模式不处理
                if (isDlnaMode) {
                    leftKeyDownTime = 0L
                    return true
                }
                
                // 分类面板已可见时不处理（可能是之前打开的）
                if (categoryPanelVisible) {
                    leftKeyDownTime = 0L
                    return true
                }
                
                // 短按左键 - 切换源或显示分类面板
                val pressDuration = System.currentTimeMillis() - leftKeyDownTime
                if (leftKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    if (hasMultipleSources()) {
                        previousSource()
                    } else {
                        showCategoryPanel()
                    }
                }
                leftKeyDownTime = 0L
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
        
        player = ExoPlayer.Builder(requireContext(), renderersFactory)
            .setLoadControl(loadControl)
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
                            retryCount = 0 // 播放成功，重置重试计数
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
                    
                    // 自动重试逻辑
                    if (retryCount < MAX_RETRIES) {
                        retryCount++
                        Log.d(TAG, "Retrying playback ($retryCount/$MAX_RETRIES)...")
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
                        showError("Error: ${error.message}")
                        updateStatus("Offline")
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
    
    private fun playUrl(url: String) {
        Log.d(TAG, "Playing URL: $url")
        videoWidth = 0
        videoHeight = 0
        frameRate = 0f
        stopFpsCalculation()
        updateVideoInfoDisplay()
        
        showLoading()
        updateStatus("Loading")
        
        val mediaItem = MediaItem.fromUri(url)
        player?.setMediaItem(mediaItem)
        player?.prepare()
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
    
    // 切换到下一个源
    private fun nextSource() {
        val sources = getCurrentSources()
        if (sources.size <= 1) return
        
        currentSourceIndex = (currentSourceIndex + 1) % sources.size
        val newUrl = sources[currentSourceIndex]
        
        Log.d(TAG, "Switching to source ${currentSourceIndex + 1}/${sources.size}: $newUrl")
        showSourceIndicator()
        playUrl(newUrl)
        showControls()
    }
    
    // 切换到上一个源
    private fun previousSource() {
        val sources = getCurrentSources()
        if (sources.size <= 1) return
        
        currentSourceIndex = (currentSourceIndex - 1 + sources.size) % sources.size
        val newUrl = sources[currentSourceIndex]
        
        Log.d(TAG, "Switching to source ${currentSourceIndex + 1}/${sources.size}: $newUrl")
        showSourceIndicator()
        playUrl(newUrl)
        showControls()
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
                sourceText.text = "源 ${currentSourceIndex + 1}/${sources.size}"
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
        if (channelUrls.isEmpty() || newIndex < 0 || newIndex >= channelUrls.size) {
            return
        }
        
        // 重置重试计数
        retryCount = 0
        retryRunnable?.let { handler.removeCallbacks(it) }
        
        currentIndex = newIndex
        currentSourceIndex = 0 // 重置源索引
        currentUrl = channelUrls[newIndex]
        currentName = if (newIndex < channelNames.size) channelNames[newIndex] else "Channel ${newIndex + 1}"
        
        Log.d(TAG, "Switching to channel: $currentName (index $currentIndex, sources=${getCurrentSources().size})")
        updateSourceIndicator()
        
        // 使用第一个源播放
        val sources = getCurrentSources()
        val urlToPlay = if (sources.isNotEmpty()) sources[0] else currentUrl
        playUrl(urlToPlay)
        showControls()
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
                parts.add("硬解")
            } else {
                parts.add("软解")
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
                            epgCurrentTime.text = if (currentRemaining != null) "${currentRemaining}分钟后结束" else ""
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

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
        player?.playWhenReady = true
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
