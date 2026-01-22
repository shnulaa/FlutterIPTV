import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/models/channel.dart';
import '../../../features/catchup/screens/catchup_time_picker.dart';

class EpgScreen extends StatelessWidget {
  final String? channelId;

  const EpgScreen({
    super.key,
    this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(context),
        title: Text(
          'Program Guide',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 50,
                color: AppTheme.getTextMuted(context).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'EPG Coming Soon',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Electronic Program Guide will be available in a future update',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Demo catch-up button (to be integrated with full EPG implementation)
            ElevatedButton.icon(
              onPressed: () => _showCatchUpDemo(context),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('回放 (演示)'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCatchUpDemo(BuildContext context) {
    // Demo catch-up picker (placeholder)
    final demoChannel = Channel(
      playlistId: 1,
      name: 'CCTV-1 (演示)',
      url: '',
      supportsCatchUp: true,
      catchUpSource: r'http://example.com/catchup?start=${utc:yyyyMMddHHmmss}&end=${utcend:yyyyMMddHHmmss}',
      catchUpDays: 7,
    );
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CatchUpTimePicker(
        channel: demoChannel,
        onCancel: () => Navigator.pop(context),
        onConfirm: (url, startTime, endTime) {
          debugPrint('EPG Demo: Catch-up URL: $url');
          debugPrint('  Start: $startTime, End: $endTime');
          Navigator.pop(context);
        },
      ),
    );
  }
}
