import 'package:flutter/foundation.dart';

/// Represents a catch-up TV program that can be played back
class CatchUpProgram {
  final String channelId;
  final String channelName;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? catchUpUrl;
  final String? logoUrl;

  CatchUpProgram({
    required this.channelId,
    required this.channelName,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.catchUpUrl,
    this.logoUrl,
  });

  /// Get the duration of the program
  Duration get duration => endTime.difference(startTime);

  /// Check if the program is currently being broadcast (live)
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Check if the program has ended
  bool get hasEnded => DateTime.now().isAfter(endTime);

  /// Check if the program has started
  bool get hasStarted => DateTime.now().isAfter(startTime);

  /// Check if this program is available for catch-up playback
  bool get isAvailable => hasStarted && !isLive;

  /// Get the progress of the program (0.0 to 1.0) for live programs
  double get liveProgress {
    if (!isLive) return 1.0;
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    return (elapsed.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  /// Get the remaining time for live programs
  Duration get remainingTime {
    if (!isLive) return Duration.zero;
    return endTime.difference(DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatchUpProgram &&
        other.channelId == channelId &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode => channelId.hashCode ^ startTime.hashCode ^ endTime.hashCode;

  @override
  String toString() {
    return 'CatchUpProgram(channel: $channelName, title: $title, start: $startTime, end: $endTime)';
  }
}

/// Represents a time range for catch-up playback
class CatchUpTimeRange {
  final DateTime startTime;
  final DateTime endTime;
  final int maxDays;

  CatchUpTimeRange({
    required this.startTime,
    required this.endTime,
    this.maxDays = 7,
  });

  /// Check if a given time is within this range
  bool contains(DateTime time) {
    return time.isAfter(startTime) && time.isBefore(endTime);
  }

  /// Check if this range is within the catch-up window
  bool isWithinCatchUpWindow({DateTime? referenceTime}) {
    final reference = referenceTime ?? DateTime.now();
    final earliest = reference.subtract(Duration(days: maxDays));
    return startTime.isAfter(earliest);
  }

  /// Get the duration of this range
  Duration get duration => endTime.difference(startTime);

  /// Get the total duration in seconds
  int get durationSeconds => duration.inSeconds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatchUpTimeRange &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode => startTime.hashCode ^ endTime.hashCode;
}

/// Represents the current catch-up playback state
class CatchUpState {
  bool isActive;
  String? channelId;
  String? channelName;
  DateTime? programStartTime;
  DateTime? programEndTime;
  Duration currentPosition;
  Duration totalDuration;
  String? currentUrl;

  CatchUpState({
    this.isActive = false,
    this.channelId,
    this.channelName,
    this.programStartTime,
    this.programEndTime,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.currentUrl,
  });

  /// Get the current progress (0.0 to 1.0)
  double get progress {
    if (totalDuration.inSeconds == 0) return 0.0;
    return (currentPosition.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
  }

  /// Get the remaining time
  Duration get remainingTime {
    return totalDuration - currentPosition;
  }

  /// Check if playback has reached the end
  bool get hasEnded => currentPosition >= totalDuration;

  /// Get a copy of this state with updated position
  CatchUpState copyWith({
    bool? isActive,
    String? channelId,
    String? channelName,
    DateTime? programStartTime,
    DateTime? programEndTime,
    Duration? currentPosition,
    Duration? totalDuration,
    String? currentUrl,
  }) {
    return CatchUpState(
      isActive: isActive ?? this.isActive,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      programStartTime: programStartTime ?? this.programStartTime,
      programEndTime: programEndTime ?? this.programEndTime,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      currentUrl: currentUrl ?? this.currentUrl,
    );
  }

  @override
  String toString() {
    return 'CatchUpState(isActive: $isActive, channel: $channelName, position: $currentPosition/$totalDuration)';
  }
}

/// Configuration for catch-up TV feature
class CatchUpConfig {
  final int defaultDays;
  final int maxDays;
  final bool enabled;
  final int defaultRewindSeconds;
  final int defaultForwardSeconds;

  CatchUpConfig({
    this.defaultDays = 7,
    this.maxDays = 7,
    this.enabled = true,
    this.defaultRewindSeconds = 30,
    this.defaultForwardSeconds = 30,
  });

  /// Create config from preferences map
  factory CatchUpConfig.fromMap(Map<String, dynamic> map) {
    return CatchUpConfig(
      defaultDays: map['defaultDays'] ?? 7,
      maxDays: map['maxDays'] ?? 7,
      enabled: map['enabled'] ?? true,
      defaultRewindSeconds: map['defaultRewindSeconds'] ?? 30,
      defaultForwardSeconds: map['defaultForwardSeconds'] ?? 30,
    );
  }

  /// Convert to preferences map
  Map<String, dynamic> toMap() {
    return {
      'defaultDays': defaultDays,
      'maxDays': maxDays,
      'enabled': enabled,
      'defaultRewindSeconds': defaultRewindSeconds,
      'defaultForwardSeconds': defaultForwardSeconds,
    };
  }
}
