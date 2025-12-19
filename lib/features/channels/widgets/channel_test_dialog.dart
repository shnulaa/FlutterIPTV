import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../providers/channel_provider.dart';

/// 频道测试对话框返回结果
class ChannelTestDialogResult {
  final List<ChannelTestResult> results;
  final bool movedToUnavailable; // 是否已移动到失效分类
  final bool runInBackground; // 是否转入后台执行
  final int remainingCount; // 剩余未测试数量

  ChannelTestDialogResult({
    required this.results,
    this.movedToUnavailable = false,
    this.runInBackground = false,
    this.remainingCount = 0,
  });
}

/// 频道测试对话框
class ChannelTestDialog extends StatefulWidget {
  final List<Channel> channels;

  const ChannelTestDialog({
    super.key,
    required this.channels,
  });

  @override
  State<ChannelTestDialog> createState() => _ChannelTestDialogState();
}

class _ChannelTestDialogState extends State<ChannelTestDialog> {
  final ChannelTestService _testService = ChannelTestService();
  StreamSubscription<ChannelTestProgress>? _subscription;
  
  bool _isTesting = false;
  bool _isComplete = false;
  int _total = 0;
  int _completed = 0;
  int _available = 0;
  int _unavailable = 0;
  String _currentChannelName = '';
  List<ChannelTestResult> _results = [];
  bool _showOnlyFailed = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _isTesting = true;
      _isComplete = false;
      _total = widget.channels.length;
      _completed = 0;
      _available = 0;
      _unavailable = 0;
      _results = [];
    });

    _subscription = _testService.testChannels(widget.channels).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _completed = progress.completed;
            _available = progress.available;
            _unavailable = progress.unavailable;
            _currentChannelName = progress.currentChannel.name;
            _results = progress.results;
            _isComplete = progress.isComplete;
            if (_isComplete) {
              _isTesting = false;
            }
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isTesting = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isTesting = false;
            _isComplete = true;
          });
        }
      },
    );
  }

  void _stopTest() {
    _subscription?.cancel();
    setState(() {
      _isTesting = false;
    });
  }

  List<ChannelTestResult> get _filteredResults {
    if (_showOnlyFailed) {
      return _results.where((r) => !r.isAvailable).toList();
    }
    return _results;
  }

  Future<void> _moveToUnavailableGroup(BuildContext context) async {
    final unavailableChannelIds = _results
        .where((r) => !r.isAvailable)
        .map((r) => r.channel.id)
        .whereType<int>()
        .toList();

    if (unavailableChannelIds.isEmpty) return;

    // 移动到失效分类
    await context.read<ChannelProvider>().markChannelsAsUnavailable(unavailableChannelIds);

    // 返回结果，标记已移动
    if (mounted) {
      Navigator.of(context).pop(ChannelTestDialogResult(
        results: _results,
        movedToUnavailable: true,
      ));
    }
  }

  void _runInBackground(BuildContext context) {
    // 停止当前测试
    _subscription?.cancel();
    
    // 获取剩余未测试的频道
    final testedIds = _results.map((r) => r.channel.id).toSet();
    final remainingChannels = widget.channels
        .where((c) => !testedIds.contains(c.id))
        .toList();
    
    // 启动后台测试
    final backgroundService = BackgroundTestService();
    backgroundService.startTest(remainingChannels);
    
    // 关闭对话框，返回特殊标记表示后台执行
    Navigator.of(context).pop(ChannelTestDialogResult(
      results: _results,
      movedToUnavailable: false,
      runInBackground: true,
      remainingCount: remainingChannels.length,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '频道测试',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '共 ${widget.channels.length} 个频道',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 进度区域
            if (_isTesting || _isComplete) ...[
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _completed / _total : 0,
                  backgroundColor: AppTheme.cardColor,
                  color: AppTheme.primaryColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),

              // 统计信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('已测试', '$_completed/$_total', AppTheme.textPrimary),
                  _buildStatItem('可用', '$_available', Colors.green),
                  _buildStatItem('不可用', '$_unavailable', AppTheme.errorColor),
                ],
              ),

              const SizedBox(height: 12),

              // 当前测试频道
              if (_isTesting)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '正在测试: $_currentChannelName',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // 筛选选项
              if (_results.isNotEmpty)
                Row(
                  children: [
                    const Text(
                      '测试结果',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    FilterChip(
                      label: Text('仅显示失败 ($_unavailable)'),
                      selected: _showOnlyFailed,
                      onSelected: (v) => setState(() => _showOnlyFailed = v),
                      selectedColor: AppTheme.errorColor.withOpacity(0.2),
                      checkmarkColor: AppTheme.errorColor,
                      labelStyle: TextStyle(
                        color: _showOnlyFailed ? AppTheme.errorColor : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // 结果列表
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _filteredResults.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              '暂无结果',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredResults.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: AppTheme.surfaceColor,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final result = _filteredResults[index];
                            return _buildResultItem(result);
                          },
                        ),
                ),
              ),
            ] else ...[
              // 未开始测试时的提示
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 48,
                      color: AppTheme.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '点击开始测试按钮检测频道可用性',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '测试将检查每个频道的连接状态',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 操作按钮
            Column(
              children: [
                Row(
                  children: [
                    if (_isComplete && _unavailable > 0) ...[
                      Expanded(
                        child: TVFocusable(
                          onSelect: () => _moveToUnavailableGroup(context),
                          child: OutlinedButton.icon(
                            onPressed: () => _moveToUnavailableGroup(context),
                            icon: const Icon(Icons.folder_special_rounded, size: 18),
                            label: const Text('移至失效分类'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TVFocusable(
                        autofocus: !_isTesting && !_isComplete,
                        onSelect: _isTesting ? _stopTest : (_isComplete ? () => Navigator.of(context).pop() : _startTest),
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? _stopTest : (_isComplete ? () => Navigator.of(context).pop() : _startTest),
                          icon: Icon(
                            _isTesting ? Icons.stop_rounded : (_isComplete ? Icons.check_rounded : Icons.play_arrow_rounded),
                            size: 20,
                          ),
                          label: Text(_isTesting ? '停止测试' : (_isComplete ? '完成' : '开始测试')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTesting ? AppTheme.errorColor : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 后台执行按钮
                if (_isTesting) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TVFocusable(
                      onSelect: () => _runInBackground(context),
                      child: OutlinedButton.icon(
                        onPressed: () => _runInBackground(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('后台执行'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.cardColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(ChannelTestResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // 状态图标
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: result.isAvailable
                  ? Colors.green.withOpacity(0.2)
                  : AppTheme.errorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              result.isAvailable ? Icons.check_rounded : Icons.close_rounded,
              color: result.isAvailable ? Colors.green : AppTheme.errorColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          // 频道名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.channel.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (result.error != null)
                  Text(
                    result.error!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 响应时间
          if (result.responseTime != null)
            Text(
              '${result.responseTime}ms',
              style: TextStyle(
                color: result.isAvailable ? AppTheme.textMuted : AppTheme.errorColor,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}


/// 后台测试进度对话框
class BackgroundTestProgressDialog extends StatefulWidget {
  const BackgroundTestProgressDialog({super.key});

  @override
  State<BackgroundTestProgressDialog> createState() => _BackgroundTestProgressDialogState();
}

class _BackgroundTestProgressDialogState extends State<BackgroundTestProgressDialog> {
  final BackgroundTestService _backgroundService = BackgroundTestService();
  late BackgroundTestProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = _backgroundService.currentProgress;
    _backgroundService.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    _backgroundService.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate(BackgroundTestProgress progress) {
    if (mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _progress.isRunning ? Icons.sync_rounded : Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '后台测试',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _progress.isRunning ? '测试进行中...' : '测试完成',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress.progress,
                backgroundColor: AppTheme.cardColor,
                color: AppTheme.primaryColor,
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 16),

            // 统计信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('已测试', '${_progress.completed}/${_progress.total}', AppTheme.textPrimary),
                _buildStatItem('可用', '${_progress.available}', Colors.green),
                _buildStatItem('不可用', '${_progress.unavailable}', AppTheme.errorColor),
              ],
            ),

            // 当前测试频道
            if (_progress.isRunning && _progress.currentChannelName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在测试: ${_progress.currentChannelName}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                if (_progress.isComplete && _progress.unavailable > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _moveToUnavailableGroup(context),
                      icon: const Icon(Icons.folder_special_rounded, size: 18),
                      label: const Text('移至失效分类'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _progress.isRunning
                        ? () {
                            _backgroundService.stopTest();
                          }
                        : () {
                            _backgroundService.clearResults();
                            Navigator.of(context).pop();
                          },
                    icon: Icon(
                      _progress.isRunning ? Icons.stop_rounded : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(_progress.isRunning ? '停止测试' : '完成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _progress.isRunning ? AppTheme.errorColor : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _moveToUnavailableGroup(BuildContext context) async {
    final unavailableChannelIds = _backgroundService.getUnavailableChannelIds();

    if (unavailableChannelIds.isEmpty) return;

    // 移动到失效分类
    await context.read<ChannelProvider>().markChannelsAsUnavailable(unavailableChannelIds);
    
    // 清除结果
    _backgroundService.clearResults();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 ${unavailableChannelIds.length} 个失效频道移至失效分类'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
