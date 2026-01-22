import 'package:flutter/foundation.dart';

/// Service for building catch-up TV URLs from templates
/// Supports various time variable formats commonly used in IPTV playlists
class CatchUpService {
  static final CatchUpService _instance = CatchUpService._internal();
  factory CatchUpService() => _instance;
  CatchUpService._internal();

  /// Build a catch-up URL from a template and time range
  ///
  /// [template] The URL template containing time variables
  /// [startTime] The start time of the program
  /// [endTime] The end time of the program
  /// [useUtc] Whether to use UTC time (true) or local time (false)
  ///
  /// Returns the constructed URL with variables replaced
  String buildUrl({
    required String template,
    required DateTime startTime,
    required DateTime endTime,
    bool useUtc = true,
  }) {
    final timeSource = useUtc ? startTime.toUtc() : startTime;
    final endTimeSource = useUtc ? endTime.toUtc() : endTime;

    String result = template;

    // Replace UTC time variables
    result = _replaceTimeVariable(
      result,
      r'${utc:yyyyMMddHHmmss}',
      timeSource,
      'yyyyMMddHHmmss',
    );
    result = _replaceTimeVariable(
      result,
      r'${utc:yyyyMMddHHmm}',
      timeSource,
      'yyyyMMddHHmm',
    );
    result = _replaceTimeVariable(
      result,
      r'${utc:yyyyMMddHH}',
      timeSource,
      'yyyyMMddHH',
    );
    result = _replaceTimeVariable(
      result,
      r'${utc:yyyyMMdd}',
      timeSource,
      'yyyyMMdd',
    );

    // Replace end time UTC variables
    result = _replaceTimeVariable(
      result,
      r'${utcend:yyyyMMddHHmmss}',
      endTimeSource,
      'yyyyMMddHHmmss',
    );
    result = _replaceTimeVariable(
      result,
      r'${utcend:yyyyMMddHHmm}',
      endTimeSource,
      'yyyyMMddHHmm',
    );
    result = _replaceTimeVariable(
      result,
      r'${utcend:yyyyMMddHH}',
      endTimeSource,
      'yyyyMMddHH',
    );
    result = _replaceTimeVariable(
      result,
      r'${utcend:yyyyMMdd}',
      endTimeSource,
      'yyyyMMdd',
    );

    // Replace local time variables
    result = _replaceTimeVariable(
      result,
      r'${start:yyyyMMddHHmmss}',
      timeSource,
      'yyyyMMddHHmmss',
    );
    result = _replaceTimeVariable(
      result,
      r'${start:yyyyMMddHHmm}',
      timeSource,
      'yyyyMMddHHmm',
    );
    result = _replaceTimeVariable(
      result,
      r'${start:yyyyMMddHH}',
      timeSource,
      'yyyyMMddHH',
    );
    result = _replaceTimeVariable(
      result,
      r'${start:yyyyMMdd}',
      timeSource,
      'yyyyMMdd',
    );

    // Replace end time local variables
    result = _replaceTimeVariable(
      result,
      r'${end:yyyyMMddHHmmss}',
      endTimeSource,
      'yyyyMMddHHmmss',
    );
    result = _replaceTimeVariable(
      result,
      r'${end:yyyyMMddHHmm}',
      endTimeSource,
      'yyyyMMddHHmm',
    );
    result = _replaceTimeVariable(
      result,
      r'${end:yyyyMMddHH}',
      endTimeSource,
      'yyyyMMddHH',
    );
    result = _replaceTimeVariable(
      result,
      r'${end:yyyyMMdd}',
      endTimeSource,
      'yyyyMMdd',
    );

    // Replace Unix timestamp variables (seconds)
    result = result.replaceAll(
      r'${start:unix}',
      (timeSource.millisecondsSinceEpoch / 1000).round().toString(),
    );
    result = result.replaceAll(
      r'${end:unix}',
      (endTimeSource.millisecondsSinceEpoch / 1000).round().toString(),
    );

    // Replace Unix timestamp in milliseconds
    result = result.replaceAll(
      r'${start:unix_ms}',
      timeSource.millisecondsSinceEpoch.toString(),
    );
    result = result.replaceAll(
      r'${end:unix_ms}',
      endTimeSource.millisecondsSinceEpoch.toString(),
    );

    debugPrint('CatchUpService: Built URL from template');
    debugPrint('  Template: $template');
    debugPrint('  Result: $result');

    return result;
  }

  /// Replace a single time variable in the template
  String _replaceTimeVariable(
    String template,
    String variable,
    DateTime time,
    String format,
  ) {
    if (!template.contains(variable)) {
      return template;
    }

    final formatted = _formatDateTime(time, format);
    return template.replaceAll(variable, formatted);
  }

  /// Format DateTime according to the specified format
  String _formatDateTime(DateTime time, String format) {
    final year = time.year.toString();
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');

    return format
        .replaceAll('yyyy', year)
        .replaceAll('MM', month)
        .replaceAll('dd', day)
        .replaceAll('HH', hour)
        .replaceAll('mm', minute)
        .replaceAll('ss', second);
  }

  /// Validate a catch-up URL template
  /// Returns true if the template is valid and contains at least one time variable
  bool isValidTemplate(String template) {
    if (template.isEmpty) {
      return false;
    }

    // Check for common time variable patterns
    final patterns = [
      r'${utc:',
      r'${utcend:',
      r'${start:',
      r'${end:',
      r'${start:unix',
      r'${end:unix',
    ];

    for (final pattern in patterns) {
      if (template.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a URL contains catch-up time variables
  bool containsTimeVariables(String url) {
    return url.contains(r'${') && url.contains('}');
  }

  /// Get the earliest available time for catch-up (7 days ago from now)
  DateTime getEarliestAvailableTime({int days = 7}) {
    return DateTime.now().subtract(Duration(days: days));
  }

  /// Check if a given time is within the catch-up window
  bool isTimeAvailable(
    DateTime time, {
    int days = 7,
    DateTime? referenceTime,
  }) {
    final reference = referenceTime ?? DateTime.now();
    final earliest = reference.subtract(Duration(days: days));
    return time.isAfter(earliest) && time.isBefore(reference);
  }

  /// Calculate the duration of a catch-up window in days
  int calculateCatchUpDays(DateTime start, DateTime end) {
    final difference = end.difference(start);
    return (difference.inHours / 24).round();
  }

  /// Parse a duration string (e.g., "01:30:00") to Duration
  Duration parseDuration(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    } else if (parts.length == 2) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
      );
    }
    return Duration.zero;
  }

  /// Format Duration to string (e.g., "01:30:00")
  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
