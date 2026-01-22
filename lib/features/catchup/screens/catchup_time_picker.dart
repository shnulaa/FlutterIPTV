import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/epg_entry.dart';
import '../../../core/services/catchup_service.dart';

class CatchUpTimePicker extends StatefulWidget {
  final Channel channel;
  final EpgEntry? program;
  final VoidCallback onCancel;
  final Function(String url, DateTime startTime, DateTime endTime) onConfirm;

  const CatchUpTimePicker({
    super.key,
    required this.channel,
    this.program,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<CatchUpTimePicker> createState() => _CatchUpTimePickerState();
}

class _CatchUpTimePickerState extends State<CatchUpTimePicker> {
  final CatchUpService _catchUpService = CatchUpService();
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late List<DateTime> _availableDates;
  
  late final int _maxDays;
  String? _errorMessage;

  _CatchUpTimePickerState();

  @override
  void initState() {
    super.initState();
    
    _maxDays = widget.channel.catchUpDays;
    _availableDates = _generateAvailableDates(_maxDays);
    
    // Initialize with program time or current time
    if (widget.program != null) {
      _selectedDate = widget.program!.startTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.program!.startTime);
    } else {
      final now = DateTime.now();
      _selectedDate = _availableDates.isNotEmpty ? _availableDates.last : now;
      _selectedTime = TimeOfDay.now();
    }
  }

  List<DateTime> _generateAvailableDates(int days) {
    final List<DateTime> dates = [];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      dates.add(now.subtract(Duration(days: i)));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FocusTraversalGroup(
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                '选择回看时间',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              
              // Channel info
              Text(
                widget.channel.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Date selector
              Text(
                '选择日期',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableDates.length,
                  itemBuilder: (context, index) {
                    final date = _availableDates[index];
                    final isSelected = isSameDay(date, _selectedDate);
                    final isToday = isSameDay(date, DateTime.now());
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 70,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.primary, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MM/dd').format(date),
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                _getDayLabel(date),
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary.withOpacity(0.8)
                                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Time selector
              Text(
                '选择时间',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              
              // Time display with increment/decrement
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _decrementHour,
                    icon: const Icon(Icons.chevron_left),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 100,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _formatTime(_selectedTime),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _incrementHour,
                    icon: const Icon(Icons.chevron_right),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Program info
              if (widget.program != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.program!.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDateTime(widget.program!.startTime)} - ${_formatDateTime(widget.program!.endTime)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _confirm,
                    child: const Text('确认'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) {
      return '今天';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(date, yesterday)) {
      return '昨天';
    }
    final formatter = DateFormat('EEE', 'zh_CN');
    return formatter.format(date);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MM/dd HH:mm').format(date);
  }

  void _incrementHour() {
    setState(() {
      _selectedTime = TimeOfDay(
        hour: (_selectedTime.hour + 1) % 24,
        minute: _selectedTime.minute,
      );
    });
  }

  void _decrementHour() {
    setState(() {
      _selectedTime = TimeOfDay(
        hour: (_selectedTime.hour - 1 + 24) % 24,
        minute: _selectedTime.minute,
      );
    });
  }

  void _confirm() {
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Validate
    if (!_catchUpService.isTimeAvailable(
      selectedDateTime,
      days: _maxDays,
    )) {
      setState(() {
        _errorMessage = '所选时间不在回放范围内（${_maxDays}天内）';
      });
      return;
    }

    // Build the URL
    if (widget.channel.catchUpSource == null) {
      setState(() {
        _errorMessage = '该频道不支持回放';
      });
      return;
    }

    // Calculate end time (default 1 hour after start, or use program duration)
    DateTime endTime;
    if (widget.program != null) {
      endTime = widget.program!.endTime;
    } else {
      endTime = selectedDateTime.add(const Duration(hours: 1));
    }

    final url = _catchUpService.buildUrl(
      template: widget.channel.catchUpSource!,
      startTime: selectedDateTime,
      endTime: endTime,
      useUtc: true,
    );

    widget.onConfirm(url, selectedDateTime, endTime);
  }
}
