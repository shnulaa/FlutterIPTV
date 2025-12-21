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
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DecoderReuseEvaluation
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
    
    // Category panel views
    private lateinit var categoryPanel: View
    private lateinit var categoryListContainer: View
    private lateinit var channelListContainer: View
    private lateinit var categoryList: RecyclerView
    private lateinit var channelList: RecyclerView
    private lateinit var channelListTitle: TextView

    private var currentUrl: String = ""
    private var currentName: String = ""
    private var currentIndex: Int = 0
    
    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    private var channelGroups: ArrayList<String> = arrayListOf()
    
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
    
    var onCloseListener: (() -> Unit)? = null

    companion object {
        private const val ARG_VIDEO_URL = "video_url"
        private const val ARG_CHANNEL_NAME = "channel_name"
        private const val ARG_CHANNEL_INDEX = "channel_index"
        private const val ARG_CHANNEL_URLS = "channel_urls"
        private const val ARG_CHANNEL_NAMES = "channel_names"
        private const val ARG_CHANNEL_GROUPS = "channel_groups"

        fun newInstance(
            videoUrl: String,
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null,
            channelGroups: ArrayList<String>? = null
        ): NativePlayerFragment {
            return NativePlayerFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_VIDEO_URL, videoUrl)
                    putString(ARG_CHANNEL_NAME, channelName)
                    putInt(ARG_CHANNEL_INDEX, channelIndex)
                    channelUrls?.let { putStringArrayList(ARG_CHANNEL_URLS, it) }
                    channelNames?.let { putStringArrayList(ARG_CHANNEL_NAMES, it) }
                    channelGroups?.let { putStringArrayList(ARG_CHANNEL_GROUPS, it) }
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
        }
        
        Log.d(TAG, "Playing: $currentName (index $currentIndex of ${channelUrls.size})")

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

        channelNameText.text = currentName
        updateStatus("Loading")
        
        backButton.setOnClickListener { 
            Log.d(TAG, "Back button clicked")
            closePlayer()
        }
        
        playerView.useController = false
        
        // Setup category panel
        setupCategoryPanel()
        
        // Handle key events
        view.isFocusableInTouchMode = true
        view.requestFocus()
        view.setOnKeyListener { _, keyCode, event ->
            if (event.action == KeyEvent.ACTION_DOWN) {
                handleKeyDown(keyCode)
            } else {
                false
            }
        }

        initializePlayer()
        
        if (currentUrl.isNotEmpty()) {
            playUrl(currentUrl)
        } else {
            showError("No video URL provided")
        }
        
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
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE, KeyEvent.KEYCODE_DPAD_LEFT -> {
                                handleBackKey()
                                true
                            }
                            else -> false
                        }
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
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE, KeyEvent.KEYCODE_DPAD_LEFT -> {
                                handleBackKey()
                                true
                            }
                            else -> false
                        }
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
        selectedCategoryIndex = -1
        categoryPanel.visibility = View.VISIBLE
        channelListContainer.visibility = View.GONE
        
        // Refresh category list
        categoryList.adapter?.notifyDataSetChanged()
        
        // Focus first category
        categoryList.post {
            categoryList.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
        }
        
        // Cancel auto-hide
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
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
        Log.d(TAG, "handleBackKey: categoryPanelVisible=$categoryPanelVisible, showingChannelList=$showingChannelList")
        
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

    private fun handleKeyDown(keyCode: Int): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode, categoryPanelVisible=$categoryPanelVisible")
        
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
                if (categoryPanelVisible) {
                    if (showingChannelList) {
                        // Go back to category list
                        channelListContainer.visibility = View.GONE
                        showingChannelList = false
                        categoryList.findViewHolderForAdapterPosition(selectedCategoryIndex.coerceAtLeast(0))?.itemView?.requestFocus()
                        return true
                    }
                    // Close panel
                    hideCategoryPanel()
                    return true
                }
                // Show category panel
                showCategoryPanel()
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                // Disabled for live streams
                if (!categoryPanelVisible) {
                    showControls()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_CHANNEL_UP -> {
                if (!categoryPanelVisible) {
                    Log.d(TAG, "Channel UP pressed")
                    previousChannel()
                }
                return false // Let RecyclerView handle if panel is visible
            }
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_CHANNEL_DOWN -> {
                if (!categoryPanelVisible) {
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

    private fun initializePlayer() {
        Log.d(TAG, "Initializing ExoPlayer")
        player = ExoPlayer.Builder(requireContext()).build().also { exoPlayer ->
            playerView.player = exoPlayer
            exoPlayer.playWhenReady = true
            exoPlayer.repeatMode = Player.REPEAT_MODE_OFF

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
                        }
                        Player.STATE_ENDED -> updateStatus("Ended")
                        Player.STATE_IDLE -> updateStatus("Idle")
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
                    showError("Error: ${error.message}")
                    updateStatus("Offline")
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
                    if (format.frameRate > 0) {
                        frameRate = format.frameRate
                    }
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
        updateVideoInfoDisplay()
        
        showLoading()
        updateStatus("Loading")
        
        val mediaItem = MediaItem.fromUri(url)
        player?.setMediaItem(mediaItem)
        player?.prepare()
    }
    
    private fun switchChannel(newIndex: Int) {
        if (channelUrls.isEmpty() || newIndex < 0 || newIndex >= channelUrls.size) {
            return
        }
        
        currentIndex = newIndex
        currentUrl = channelUrls[newIndex]
        currentName = if (newIndex < channelNames.size) channelNames[newIndex] else "Channel ${newIndex + 1}"
        
        Log.d(TAG, "Switching to channel: $currentName (index $currentIndex)")
        channelNameText.text = currentName
        playUrl(currentUrl)
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
            val hwStatus = if (isHardwareDecoder) "HW" else "SW"
            parts.add(hwStatus)
            
            if (parts.isNotEmpty()) {
                videoInfoText.text = parts.joinToString(" | ")
                videoInfoText.visibility = View.VISIBLE
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
            if (player?.isPlaying == true && !categoryPanelVisible) {
                hideControls() 
            }
        }
        handler.postDelayed(hideControlsRunnable!!, CONTROLS_HIDE_DELAY)
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
