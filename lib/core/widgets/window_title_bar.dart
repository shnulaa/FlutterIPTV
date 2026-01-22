import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';
import '../platform/windows_pip_channel.dart';

/// 自动隐藏的Windows标题栏
/// 鼠标移到顶部区域时显示，移开后自动隐藏
class WindowTitleBar extends StatefulWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const WindowTitleBar({
    super.key,
    this.title = 'Lotus IPTV',
    this.leading,
    this.actions,
  });

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  bool _isVisible = false;
  Timer? _hideTimer;

  // 触发区域高度（鼠标进入此区域显示标题栏）
  static const double _triggerHeight = 8.0;
  // 标题栏高度
  static const double _barHeight = 32.0;
  // 自动隐藏延迟
  static const Duration _hideDelay = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    // 监听 mini 模式状态变化
    WindowsPipChannel.pipModeNotifier.addListener(_onPipModeChanged);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WindowsPipChannel.pipModeNotifier.removeListener(_onPipModeChanged);
    super.dispose();
  }

  void _onPipModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showTitleBar() {
    _hideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    // Mini 模式下完全不显示标题栏
    if (WindowsPipChannel.isInPipMode) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 触发区域（始终存在，用于检测鼠标进入）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _triggerHeight,
          child: MouseRegion(
            onEnter: (_) => _showTitleBar(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // 标题栏（带动画）
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          top: _isVisible ? 0 : -_barHeight,
          left: 0,
          right: 0,
          height: _barHeight,
          child: MouseRegion(
            onEnter: (_) => _cancelHideTimer(),
            onExit: (_) => _startHideTimer(),
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getPrimaryColor(context).withOpacity(0.15),
                            AppTheme.getBackgroundColor(context),
                          ]
                        : [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getBackgroundColor(context).withOpacity(0.9),
                            AppTheme.getPrimaryColor(context).withOpacity(0.08),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // App icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.live_tv,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // Draggable area
                    const Expanded(child: SizedBox()),
                    // Window buttons
                    _WindowButton(
                      icon: Icons.remove,
                      onPressed: () => windowManager.minimize(),
                    ),
                    _MaximizeButton(),
                    _WindowButton(
                      icon: Icons.close,
                      hoverColor: Colors.red,
                      onPressed: () => windowManager.close(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered ? (widget.hoverColor ?? const Color(0x33FFFFFF)) : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverColor != null ? Colors.white : AppTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _isHovered = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (_isMaximized) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
          _checkMaximized();
        },
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered ? const Color(0x33FFFFFF) : Colors.transparent,
          child: Icon(
            _isMaximized ? Icons.filter_none : Icons.crop_square,
            size: 14,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }
}
