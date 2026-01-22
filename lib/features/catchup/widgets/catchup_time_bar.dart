import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/catchup_models.dart';

class CatchUpTimeBar extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  final Duration currentPosition;
  final ValueChanged<Duration>? onSeek;
  final bool enabled;

  const CatchUpTimeBar({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.currentPosition,
    this.onSeek,
    this.enabled = true,
  });

  @override
  State<CatchUpTimeBar> createState() => _CatchUpTimeBarState();
}

class _CatchUpTimeBarState extends State<CatchUpTimeBar> {
  double _sliderValue = 0.0;
  bool _isDragging = false;
  int? _hoverPositionSeconds;

  Duration get _totalDuration => widget.endTime.difference(widget.startTime);
  double get _progress => widget.currentPosition.inMilliseconds / _totalDuration.inMilliseconds.clamp(1, double.infinity);

  @override
  void initState() {
    super.initState();
    _sliderValue = _progress;
  }

  @override
  void didUpdateWidget(CatchUpTimeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _sliderValue = _progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDurationMs = _totalDuration.inMilliseconds;
    final currentMs = widget.currentPosition.inMilliseconds.clamp(0, totalDurationMs);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(widget.startTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDuration(widget.currentPosition),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatTime(widget.endTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceVariant,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withOpacity(0.2),
              ),
              child: Slider(
                value: _sliderValue,
                min: 0.0,
                max: 1.0,
                enabled: widget.enabled,
                onChanged: widget.enabled ? _onSliderChanged : null,
                onChangeStart: widget.enabled ? _onDragStart : null,
                onChangeEnd: widget.enabled ? _onDragEnd : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Time markers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeMarker(0, '0%', theme),
                _buildTimeMarker(0.25, '25%', theme),
                _buildTimeMarker(0.5, '50%', theme),
                _buildTimeMarker(0.75, '75%', theme),
                _buildTimeMarker(1.0, '100%', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeMarker(double position, String label, ThemeData theme) {
    return MouseRegion(
      onEnter: (_) {
        final seconds = (_totalDuration.inSeconds * position).round();
        setState(() {
          _hoverPositionSeconds = seconds;
        });
      },
      onExit: (_) {
        setState(() {
          _hoverPositionSeconds = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_hoverPositionSeconds != null &&
                (widget.currentPosition.inSeconds - _totalDuration.inSeconds * position).abs() < 60)
              Text(
                _formatDuration(Duration(seconds: (_totalDuration.inSeconds * position).round())),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
    });
    
    final positionMs = (value * _totalDuration.inMilliseconds).round();
    final newPosition = Duration(milliseconds: positionMs);
    
    widget.onSeek?.call(newPosition);
  }

  void _onDragStart(double value) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragEnd(double value) {
    setState(() {
      _isDragging = false;
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
