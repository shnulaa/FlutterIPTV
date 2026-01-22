import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/epg_entry.dart';
import '../../../core/models/catchup_models.dart';
import '../../../core/services/catchup_service.dart';

class CatchUpProvider with ChangeNotifier {
  final CatchUpService _catchUpService = CatchUpService();

  // Current catch-up state
  final CatchUpState _state = CatchUpState();
  
  // Reference to the channel being played back
  Channel? _currentChannel;
  
  // Callbacks for player control
  VoidCallback? onEnterCatchUp;
  VoidCallback? onExitCatchUp;
  Function(Duration position)? onSeekTo;
  Function(int seconds)? onSeekRelative;

  // Getters
  bool get isInCatchUpMode => _state.isActive;
  String? get currentChannelId => _state.channelId;
  String? get currentChannelName => _state.channelName;
  DateTime? get programStartTime => _state.programStartTime;
  DateTime? get programEndTime => _state.programEndTime;
  Duration get currentPosition => _state.currentPosition;
  Duration get totalDuration => _state.totalDuration;
  String? get currentUrl => _state.currentUrl;
  
  double get progress => _state.progress;
  Duration get remainingTime => _state.remainingTime;
  bool get hasEnded => _state.hasEnded;

  /// Enter catch-up mode for a specific program
  Future<String?> enterCatchUpMode({
    required Channel channel,
    required EpgEntry program,
    required String liveUrl,
  }) async {
    if (!channel.hasCatchUp) {
      debugPrint('CatchUpProvider: Channel ${channel.name} does not support catch-up');
      return null;
    }

    final template = channel.catchUpSource!;
    
    // Build the catch-up URL
    final catchUpUrl = _catchUpService.buildUrl(
      template: template,
      startTime: program.startTime,
      endTime: program.endTime,
      useUtc: true,
    );

    // Update state
    _state.isActive = true;
    _state.channelId = channel.epgId ?? channel.name;
    _state.channelName = channel.name;
    _state.programStartTime = program.startTime;
    _state.programEndTime = program.endTime;
    _state.currentPosition = Duration.zero;
    _state.totalDuration = program.endTime.difference(program.startTime);
    _state.currentUrl = catchUpUrl;

    debugPrint('CatchUpProvider: Entered catch-up mode for ${channel.name}');
    debugPrint('  Program: ${program.title}');
    debugPrint('  URL: $catchUpUrl');
    debugPrint('  Duration: ${_state.totalDuration}');

    notifyListeners();

    // Notify player
    onEnterCatchUp?.call();

    return catchUpUrl;
  }

  /// Exit catch-up mode and return to live TV
  void exitCatchUpMode({String? liveUrl}) {
    if (!_state.isActive) return;

    debugPrint('CatchUpProvider: Exited catch-up mode');

    _state.isActive = false;
    _state.currentPosition = Duration.zero;
    _state.totalDuration = Duration.zero;
    _state.currentUrl = null;

    notifyListeners();

    // Notify player
    onExitCatchUp?.call();
  }

  /// Update the current playback position
  void updatePosition(Duration position) {
    if (!_state.isActive) return;

    _state.currentPosition = position;
    notifyListeners();
  }

  /// Seek to a specific position
  void seekTo(Duration position) {
    if (!_state.isActive) return;

    final clampedPosition = position < Duration.zero 
        ? Duration.zero 
        : (position > _state.totalDuration ? _state.totalDuration : position);
    _state.currentPosition = clampedPosition;
    
    debugPrint('CatchUpProvider: Seek to $clampedPosition');
    
    notifyListeners();
    
    // Notify player
    onSeekTo?.call(clampedPosition);
  }

  /// Seek forward by a number of seconds
  void seekForward(int seconds) {
    if (!_state.isActive) return;
    
    final newPosition = _state.currentPosition + Duration(seconds: seconds);
    seekTo(newPosition);
  }

  /// Seek backward by a number of seconds
  void seekBackward(int seconds) {
    if (!_state.isActive) return;
    
    final newPosition = _state.currentPosition - Duration(seconds: seconds);
    seekTo(newPosition);
  }

  /// Get the relative position for DLNA sync
  /// Converts absolute position to relative (0-based) position
  Duration getRelativePosition(Duration absolutePosition) {
    if (!_state.isActive) return absolutePosition;
    
    final relativeMs = absolutePosition.inMilliseconds - 
        (_state.programStartTime?.millisecondsSinceEpoch ?? 0);
    final relative = Duration(milliseconds: relativeMs);
    return relative < Duration.zero 
        ? Duration.zero 
        : (relative > _state.totalDuration ? _state.totalDuration : relative);
  }

  /// Get the absolute position from a relative position (for DLNA)
  Duration getAbsolutePosition(Duration relativePosition) {
    if (!_state.isActive) return relativePosition;
    
    if (_state.programStartTime != null) {
      final absoluteMs = _state.programStartTime!.millisecondsSinceEpoch + 
          relativePosition.inMilliseconds;
      return Duration(milliseconds: absoluteMs);
    }
    return relativePosition;
  }

  /// Check if a given time is available for catch-up
  bool isTimeAvailable(DateTime time, {int? days}) {
    final channelDays = _currentChannel?.catchUpDays ?? 7;
    return _catchUpService.isTimeAvailable(
      time,
      days: days ?? channelDays,
    );
  }

  /// Get the earliest available time for catch-up
  DateTime getEarliestAvailableTime() {
    final days = _currentChannel?.catchUpDays ?? 7;
    return _catchUpService.getEarliestAvailableTime(days: days);
  }

  /// Build a catch-up URL for a specific time range
  String buildUrl(DateTime startTime, DateTime endTime) {
    if (_currentChannel?.catchUpSource == null) {
      throw StateError('No catch-up source available');
    }

    return _catchUpService.buildUrl(
      template: _currentChannel!.catchUpSource!,
      startTime: startTime,
      endTime: endTime,
      useUtc: true,
    );
  }

  /// Reset the provider state
  void reset() {
    _currentChannel = null;
    _state.isActive = false;
    _state.currentPosition = Duration.zero;
    _state.totalDuration = Duration.zero;
    _state.currentUrl = null;
    notifyListeners();
  }

  /// Create a CatchUpProgram from current state
  CatchUpProgram? getCurrentProgram() {
    if (_state.channelId == null || 
        _state.channelName == null ||
        _state.programStartTime == null ||
        _state.programEndTime == null) {
      return null;
    }

    return CatchUpProgram(
      channelId: _state.channelId!,
      channelName: _state.channelName!,
      title: '',
      startTime: _state.programStartTime!,
      endTime: _state.programEndTime!,
      catchUpUrl: _state.currentUrl,
      logoUrl: _currentChannel?.logoUrl,
    );
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
