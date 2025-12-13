import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/models/channel.dart';

enum PlayerState {
  idle,
  loading,
  playing,
  paused,
  error,
  buffering,
}

class PlayerProvider extends ChangeNotifier {
  Player? _player;
  VideoController? _videoController;
  
  Channel? _currentChannel;
  PlayerState _state = PlayerState.idle;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  
  // Getters
  Player? get player => _player;
  VideoController? get videoController => _videoController;
  Channel? get currentChannel => _currentChannel;
  PlayerState get state => _state;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get playbackSpeed => _playbackSpeed;
  bool get isFullscreen => _isFullscreen;
  bool get controlsVisible => _controlsVisible;
  
  bool get isPlaying => _state == PlayerState.playing;
  bool get isLoading => _state == PlayerState.loading || _state == PlayerState.buffering;
  bool get hasError => _state == PlayerState.error;
  
  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }
  
  PlayerProvider() {
    _initPlayer();
  }
  
  void _initPlayer() {
    _player = Player();
    _videoController = VideoController(_player!);
    
    // Listen to player streams
    _player!.stream.playing.listen((playing) {
      if (playing) {
        _state = PlayerState.playing;
      } else if (_state == PlayerState.playing) {
        _state = PlayerState.paused;
      }
      notifyListeners();
    });
    
    _player!.stream.buffering.listen((buffering) {
      if (buffering && _state != PlayerState.idle) {
        _state = PlayerState.buffering;
        notifyListeners();
      }
    });
    
    _player!.stream.position.listen((position) {
      _position = position;
      notifyListeners();
    });
    
    _player!.stream.duration.listen((duration) {
      _duration = duration;
      notifyListeners();
    });
    
    _player!.stream.volume.listen((volume) {
      _volume = volume / 100;
      notifyListeners();
    });
    
    _player!.stream.error.listen((error) {
      if (error.isNotEmpty) {
        _state = PlayerState.error;
        _error = error;
        notifyListeners();
      }
    });
  }
  
  // Play a channel
  Future<void> playChannel(Channel channel) async {
    _currentChannel = channel;
    _state = PlayerState.loading;
    _error = null;
    notifyListeners();
    
    try {
      await _player?.open(Media(channel.url));
      _state = PlayerState.playing;
    } catch (e) {
      _state = PlayerState.error;
      _error = 'Failed to play channel: $e';
    }
    
    notifyListeners();
  }
  
  // Play from URL
  Future<void> playUrl(String url, {String? name}) async {
    _state = PlayerState.loading;
    _error = null;
    notifyListeners();
    
    try {
      await _player?.open(Media(url));
      _state = PlayerState.playing;
    } catch (e) {
      _state = PlayerState.error;
      _error = 'Failed to play: $e';
    }
    
    notifyListeners();
  }
  
  // Toggle play/pause
  void togglePlayPause() {
    if (_player == null) return;
    _player!.playOrPause();
  }
  
  // Pause playback
  void pause() {
    _player?.pause();
  }
  
  // Resume playback
  void play() {
    _player?.play();
  }
  
  // Stop playback
  void stop() {
    _player?.stop();
    _state = PlayerState.idle;
    _currentChannel = null;
    notifyListeners();
  }
  
  // Seek to position
  void seek(Duration position) {
    _player?.seek(position);
  }
  
  // Seek forward by seconds
  void seekForward(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    seek(newPosition);
  }
  
  // Seek backward by seconds
  void seekBackward(int seconds) {
    final newPosition = _position - Duration(seconds: seconds);
    seek(newPosition.isNegative ? Duration.zero : newPosition);
  }
  
  // Set volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player?.setVolume(_volume * 100);
    
    if (_volume > 0) {
      _isMuted = false;
    }
    
    notifyListeners();
  }
  
  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _player?.setVolume(_isMuted ? 0 : _volume * 100);
    notifyListeners();
  }
  
  // Set playback speed
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _player?.setRate(speed);
    notifyListeners();
  }
  
  // Toggle fullscreen
  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }
  
  // Set fullscreen state
  void setFullscreen(bool fullscreen) {
    _isFullscreen = fullscreen;
    notifyListeners();
  }
  
  // Show/hide controls
  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    notifyListeners();
  }
  
  // Toggle controls visibility
  void toggleControls() {
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }
  
  // Play next channel from a list
  void playNext(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    
    final currentIndex = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (currentIndex == -1 || currentIndex >= channels.length - 1) return;
    
    playChannel(channels[currentIndex + 1]);
  }
  
  // Play previous channel from a list
  void playPrevious(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    
    final currentIndex = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (currentIndex <= 0) return;
    
    playChannel(channels[currentIndex - 1]);
  }
  
  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}
