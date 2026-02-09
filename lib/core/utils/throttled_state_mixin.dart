import 'dart:async';
import 'package:flutter/widgets.dart';

/// ✅ 节流 setState Mixin：防止频繁调用 setState 阻塞主线程
/// 
/// 使用方法：
/// ```dart
/// class MyWidget extends StatefulWidget {
///   ...
/// }
/// 
/// class _MyWidgetState extends State<MyWidget> with ThrottledStateMixin {
///   void someMethod() {
///     // 使用节流 setState（100ms内多次调用只执行一次）
///     throttledSetState(() {
///       _someValue = newValue;
///     });
///     
///     // 或使用立即 setState（重要状态变化）
///     immediateSetState(() {
///       _importantValue = newValue;
///     });
///   }
/// }
/// ```
mixin ThrottledStateMixin<T extends StatefulWidget> on State<T> {
  Timer? _setStateTimer;
  VoidCallback? _pendingSetState;
  static const _throttleDuration = Duration(milliseconds: 300);

  /// 节流 setState：100ms内多次调用只执行最后一次
  void throttledSetState(VoidCallback fn) {
    _pendingSetState = fn;
    
    // 如果已经有定时器在运行，不创建新的
    if (_setStateTimer?.isActive ?? false) {
      return;
    }

    // 创建新的定时器
    _setStateTimer = Timer(_throttleDuration, () {
      if (_pendingSetState != null && mounted) {
        setState(_pendingSetState!);
        _pendingSetState = null;
      }
    });
  }

  /// 立即 setState：用于重要状态变化，不节流
  void immediateSetState(VoidCallback fn) {
    _setStateTimer?.cancel();
    _pendingSetState = null;
    if (mounted) {
      setState(fn);
    }
  }

  /// 清空待执行的 setState 队列（切换页面/数据时调用）
  void clearPendingSetState() {
    _setStateTimer?.cancel();
    _pendingSetState = null;
  }

  @override
  void dispose() {
    clearPendingSetState();
    super.dispose();
  }
}
