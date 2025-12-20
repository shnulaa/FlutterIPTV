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

class NativePlayerFragment : Fragment() {
    private val TAG = "NativePlayerFragment"

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
    
    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    
    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private var controlsVisible = true
    private val CONTROLS_HIDE_DELAY = 3000L
    
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

        fun newInstance(
            videoUrl: String,
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null
        ): NativePlayerFragment {
            return NativePlayerFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_VIDEO_URL, videoUrl)
                    putString(ARG_CHANNEL_NAME, channelName)
                    putInt(ARG_CHANNEL_INDEX, channelIndex)
                    channelUrls?.let { putStringArrayList(ARG_CHANNEL_URLS, it) }
                    channelNames?.let { putStringArrayList(ARG_CHANNEL_NAMES, it) }
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
        }
        
        Log.d(TAG, "Playing: $currentName (index $currentIndex of ${channelUrls.size})")

        playerView = view.findViewById(R.id.player_view)
        loadingIndicator = view.findViewById(R.id.loading_indicator)
        channelNameText = view.findViewById(R.id.channel_name)
        statusText = view.findViewById(R.id.status_text)
        videoInfoText = view.findViewById(R.id.video_info)
        errorText = view.findViewById(R.id.error_text)
        backButton = view.findViewById(R.id.back_button)
        topBar = view.findViewById(R.id.top_bar)
        bottomBar = view.findViewById(R.id.bottom_bar)

        channelNameText.text = currentName
        updateStatus("Loading")
        
        backButton.setOnClickListener { 
            Log.d(TAG, "Back button clicked")
            closePlayer()
        }
        
        playerView.useController = false
        
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

    private fun handleKeyDown(keyCode: Int): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                closePlayer()
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
        }
        
        showControls()
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
            if (player?.isPlaying == true) {
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
}
