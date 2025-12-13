import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A widget that provides D-Pad focus support for TV and desktop navigation
class TVFocusable extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, bool isFocused, Widget child)? builder;
  final VoidCallback? onSelect;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final double focusScale;
  final bool showFocusBorder;
  final BorderRadius? borderRadius;
  
  const TVFocusable({
    super.key,
    required this.child,
    this.builder,
    this.onSelect,
    this.onFocus,
    this.onBlur,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.focusScale = 1.05,
    this.showFocusBorder = true,
    this.borderRadius,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> 
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.focusScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
    
    if (hasFocus) {
      _animationController.forward();
      widget.onFocus?.call();
    } else {
      _animationController.reverse();
      widget.onBlur?.call();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    
    final key = event.logicalKey;
    
    // Handle selection
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }
    
    // Handle directional navigation callbacks
    if (key == LogicalKeyboardKey.arrowLeft && widget.onLeft != null) {
      widget.onLeft!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
      widget.onRight!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onUp != null) {
      widget.onUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onDown != null) {
      widget.onDown!();
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onSelect,
        child: MouseRegion(
          cursor: widget.enabled 
              ? SystemMouseCursors.click 
              : SystemMouseCursors.basic,
          onEnter: (_) {
            if (!_focusNode.hasFocus && widget.enabled) {
              _focusNode.requestFocus();
            }
          },
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              final focusedChild = widget.builder != null
                  ? widget.builder!(context, _isFocused, widget.child)
                  : widget.child;
              
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: widget.showFocusBorder && _isFocused
                      ? BoxDecoration(
                          borderRadius: widget.borderRadius ??
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: AppTheme.focusBorderColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.focusColor.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: focusedChild,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A FocusTraversalGroup that uses a grid-based traversal policy
/// suitable for TV interfaces
class TVFocusTraversalGroup extends StatelessWidget {
  final Widget child;
  final FocusTraversalPolicy? policy;
  
  const TVFocusTraversalGroup({
    super.key,
    required this.child,
    this.policy,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: policy ?? const ReadingOrderTraversalPolicy(),
      child: child,
    );
  }
}

/// Custom traversal policy optimized for grid layouts
class GridTraversalPolicy extends ReadingOrderTraversalPolicy {
  final int crossAxisCount;
  
  GridTraversalPolicy({required this.crossAxisCount});
}

