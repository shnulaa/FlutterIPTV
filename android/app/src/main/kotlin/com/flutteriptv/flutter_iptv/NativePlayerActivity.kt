package com.flutteriptv.flutter_iptv

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.ui.PlayerView
import org.json.JSONArray

class NativePlayerActivity : AppCompatActivity() {
    private val TAG = "NativePlayerActivity"

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var loadingIndicator: ProgressBar
    private lateinit var channelNameText: TextView
    private lateinit var statusText: TextView
    private lateinit var videoInfoText: TextView
    private lateinit var errorText: TextView
    private lateinit var backButton: ImageButton
    private lateinit var topBar: View
    private lateinit var bottomBar: View

    private var currentUrl: String = ""
    private var currentName: String = ""
    private var currentIndex: Int = 0
    
    // Channel list for switching
    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    
    // 注意：重定向解析已统一到 RedirectResolver 工具类
    
    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private var controlsVisible = true
    private val CONTROLS_HIDE_DELAY = 3000L
    
    // Video info
    private var videoWidth = 0
    private var videoHeight = 0
    private var videoCodec = ""
    private var isHardwareDecoder = false
    private var frameRate = 0f
    
    // User-Agent
    private var userAgent = "Wget/1.21.3"

    companion object {
        private const val EXTRA_VIDEO_URL = "video_url"
        private const val EXTRA_CHANNEL_NAME = "channel_name"
        private const val EXTRA_CHANNEL_INDEX = "channel_index"
        private const val EXTRA_CHANNEL_URLS = "channel_urls"
        private const val EXTRA_CHANNEL_NAMES = "channel_names"
        private const val EXTRA_USER_AGENT = "user_agent"

        fun createIntent(
            context: Context, 
            videoUrl: String, 
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null,
            userAgent: String = "Wget/1.21.3"
        ): Intent {
            return Intent(context, NativePlayerActivity::class.java).apply {
                putExtra(EXTRA_VIDEO_URL, videoUrl)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_CHANNEL_INDEX, channelIndex)
                channelUrls?.let { putStringArrayListExtra(EXTRA_CHANNEL_URLS, it) }
                channelNames?.let { putStringArrayListExtra(EXTRA_CHANNEL_NAMES, it) }
                putExtra(EXTRA_USER_AGENT, userAgent)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")
        
        // Fullscreen immersive mode
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        hideSystemUI()

        setContentView(R.layout.activity_native_player)

        // Get extras
        currentUrl = intent.getStringExtra(EXTRA_VIDEO_URL) ?: ""
        currentName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: ""
        currentIndex = intent.getIntExtra(EXTRA_CHANNEL_INDEX, 0)
        channelUrls = intent.getStringArrayListExtra(EXTRA_CHANNEL_URLS) ?: arrayListOf()
        channelNames = intent.getStringArrayListExtra(EXTRA_CHANNEL_NAMES) ?: arrayListOf()
        userAgent = intent.getStringExtra(EXTRA_USER_AGENT) ?: "Wget/1.21.3"
        
        Log.d(TAG, "Playing: $currentName (index $currentIndex of ${channelUrls.size}) - $currentUrl, userAgent=$userAgent")

        // Initialize views
        playerView = findViewById(R.id.player_view)
        loadingIndicator = findViewById(R.id.loading_indicator)
        channelNameText = findViewById(R.id.channel_name)
        statusText = findViewById(R.id.status_text)
        videoInfoText = findViewById(R.id.video_info)
        errorText = findViewById(R.id.error_text)
        backButton = findViewById(R.id.back_button)
        topBar = findViewById(R.id.top_bar)
        bottomBar = findViewById(R.id.bottom_bar)

        channelNameText.text = currentName
        updateStatus("Loading")
        
        backButton.setOnClickListener { 
            Log.d(TAG, "Back button clicked")
            finishPlayer() 
        }
        
        // Hide ExoPlayer's default controller
        playerView.useController = false

        initializePlayer()
        
        if (currentUrl.isNotEmpty()) {
            playUrl(currentUrl)
        } else {
            showError("No video URL provided")
        }
        
        // Show controls initially, then auto-hide
        showControls()
    }
    
    private fun hideSystemUI() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
    }

    private fun initializePlayer() {
        Log.d(TAG, "Initializing ExoPlayer")
        
        // Use DefaultRenderersFactory with FFmpeg extension for MP2/AC3/DTS audio support
        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        
        // 配置 HTTP 数据源和 MediaSourceFactory 支持 HLS/DASH
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(8000)
            .setReadTimeoutMs(15000)
            .setAllowCrossProtocolRedirects(true)  // 允许跨协议重定向 (HTTP→HTTPS)
            .setUserAgent(userAgent)  // 使用自定义 User-Agent
        
        Log.d(TAG, "Using User-Agent: $userAgent")
        
        val mediaSourceFactory = DefaultMediaSourceFactory(this)
            .setDataSourceFactory(dataSourceFactory)
        
        player = ExoPlayer.Builder(this, renderersFactory)
            .setMediaSourceFactory(mediaSourceFactory)
            .build().also { exoPlayer ->
            playerView.player = exoPlayer
            exoPlayer.playWhenReady = true
            exoPlayer.repeatMode = Player.REPEAT_MODE_OFF

            exoPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> {
                            NativeLogger.d(TAG, "播放器状态: BUFFERING")
                            showLoading()
                            updateStatus("Buffering")
                        }
                        Player.STATE_READY -> {
                            NativeLogger.i(TAG, "播放器状态: READY")
                            hideLoading()
                            updateStatus("LIVE")
                        }
                        Player.STATE_ENDED -> {
                            NativeLogger.d(TAG, "播放器状态: ENDED")
                            updateStatus("Ended")
                        }
                        Player.STATE_IDLE -> {
                            NativeLogger.d(TAG, "播放器状态: IDLE")
                            updateStatus("Idle")
                        }
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        NativeLogger.i(TAG, ">>> 播放成功开始")
                        updateStatus("LIVE")
                    } else if (player?.playbackState == Player.STATE_READY) {
                        NativeLogger.d(TAG, "播放暂停")
                        updateStatus("Paused")
                    }
                }

                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    videoWidth = videoSize.width
                    videoHeight = videoSize.height
                    NativeLogger.d(TAG, "视频尺寸: ${videoWidth}x${videoHeight}")
                    updateVideoInfoDisplay()
                }

                override fun onPlayerError(error: PlaybackException) {
                    NativeLogger.e(TAG, ">>> 播放器错误: ${error.message}, 错误码: ${error.errorCode}", error)
                    error.cause?.let { cause ->
                        NativeLogger.e(TAG, "错误原因: ${cause.message}", cause)
                    }
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
                    Log.d(TAG, "Video decoder: $decoderName")
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
    
    
    // 解析真实播放地址（使用统一的RedirectResolver）
    private fun resolveRealPlayUrl(url: String): String {
        return RedirectResolver.resolveRealPlayUrl(url, useCache = true)
    }
    
    private fun playUrl(url: String) {
        NativeLogger.i(TAG, ">>> 开始播放流程: $url")
        val startTime = System.currentTimeMillis()
        
        // Reset video info
        videoWidth = 0
        videoHeight = 0
        frameRate = 0f
        updateVideoInfoDisplay()
        
        showLoading()
        updateStatus("Loading")
        
        // 在后台线程解析真实地址
        Thread {
            NativeLogger.d(TAG, ">>> 开始解析302重定向")
            val redirectStartTime = System.currentTimeMillis()
            
            val realUrl = resolveRealPlayUrl(url)
            
            val redirectTime = System.currentTimeMillis() - redirectStartTime
            NativeLogger.d(TAG, ">>> 302重定向解析完成，耗时: ${redirectTime}ms")
            
            runOnUiThread {
                NativeLogger.d(TAG, ">>> 使用播放地址: $realUrl")
                NativeLogger.d(TAG, ">>> 开始初始化播放器")
                val playStartTime = System.currentTimeMillis()
                
                val mediaItem = MediaItem.fromUri(realUrl)
                player?.setMediaItem(mediaItem)
                player?.prepare()
                
                val playTime = System.currentTimeMillis() - playStartTime
                val totalTime = System.currentTimeMillis() - startTime
                NativeLogger.d(TAG, ">>> 播放器初始化完成，耗时: ${playTime}ms")
                NativeLogger.i(TAG, ">>> 播放流程总耗时: ${totalTime}ms")
            }
        }.start()
    }
    
    private fun switchChannel(newIndex: Int) {
        if (channelUrls.isEmpty() || newIndex < 0 || newIndex >= channelUrls.size) {
            NativeLogger.w(TAG, "无法切换到索引 $newIndex (列表大小: ${channelUrls.size})")
            return
        }
        
        currentIndex = newIndex
        currentUrl = channelUrls[newIndex]
        currentName = if (newIndex < channelNames.size) channelNames[newIndex] else "Channel ${newIndex + 1}"
        
        NativeLogger.i(TAG, "切换频道: $currentName (索引 $currentIndex)")
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
        runOnUiThread {
            statusText.text = status
            val color = when (status) {
                "LIVE" -> 0xFF4CAF50.toInt()
                "Buffering", "Loading" -> 0xFFFF9800.toInt()
                "Paused" -> 0xFF2196F3.toInt()
                "Offline", "Error" -> 0xFFF44336.toInt()
                else -> 0xFF9E9E9E.toInt()
            }
            statusText.setTextColor(color)
        }
    }

    private fun updateVideoInfoDisplay() {
        runOnUiThread {
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
            if (player?.isPlaying == true) {
                hideControls() 
            }
        }
        handler.postDelayed(hideControlsRunnable!!, CONTROLS_HIDE_DELAY)
    }
    
    private fun finishPlayer() {
        Log.d(TAG, "finishPlayer called")
        try {
            player?.stop()
            player?.release()
            player = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing player", e)
        }
        finish()
    }
    
    override fun onBackPressed() {
        Log.d(TAG, "onBackPressed called")
        finishPlayer()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        Log.d(TAG, "onKeyDown: keyCode=$keyCode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                finishPlayer()
                return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                showControls()
                player?.let {
                    if (it.isPlaying) it.pause() else it.play()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                showControls()
                player?.seekBack()
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                showControls()
                player?.seekForward()
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_CHANNEL_UP -> {
                Log.d(TAG, "Channel UP pressed")
                previousChannel()
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_CHANNEL_DOWN -> {
                Log.d(TAG, "Channel DOWN pressed")
                nextChannel()
                return true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                showControls()
                player?.let {
                    if (it.isPlaying) it.pause() else it.play()
                }
                return true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY -> {
                showControls()
                player?.play()
                return true
            }
            KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                showControls()
                player?.pause()
                return true
            }
        }
        
        showControls()
        return super.onKeyDown(keyCode, event)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
        hideSystemUI()
        player?.playWhenReady = true
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
        player?.playWhenReady = false
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called")
        
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        player?.release()
        player = null
    }
}
