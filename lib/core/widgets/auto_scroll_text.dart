import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double scrollSpeed;
  final Duration scrollDelay;
  final TextAlign textAlign;
  final bool forceScroll; // 新增：强制滚动控制

  const AutoScrollText({
    super.key,
    required this.text,
    this.style,
    this.scrollSpeed = 30.0,
    this.scrollDelay = const Duration(milliseconds: 1000),
    this.textAlign = TextAlign.left,
    this.forceScroll = false, // 默认false，保持原有行为
    double? width, // 保持参数兼容性，但实际由布局决定
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOverflowing = false;
  bool _isHovering = false;
  double _scrollDistance = 0;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 2) // 初始值，会被计算值覆盖
        );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      // 重置状态
      _controller.stop();
      _controller.reset();
      _checkOverflow();
    }
    
    // 当 forceScroll 状态改变时，重新触发滚动逻辑
    if (oldWidget.forceScroll != widget.forceScroll) {
      if (widget.forceScroll && _isOverflowing) {
        _startScrolling();
      } else if (!widget.forceScroll && !_isHovering) {
        _controller.stop();
        _controller.animateTo(0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  void _checkOverflow() {
    // 延迟执行以确保布局完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? renderBox =
          _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final containerWidth = renderBox.size.width;
        final textWidth = textPainter.width;

        if (textWidth > containerWidth) {
          final distance = textWidth - containerWidth + 20; // 额外缓冲
          final durationSeconds = distance / widget.scrollSpeed;

          setState(() {
            _isOverflowing = true;
            _scrollDistance = distance;
            _controller.duration =
                Duration(milliseconds: (durationSeconds * 1000).toInt());
          });

          // 如果当前处于 Hover 状态，且发现溢出，重新触发滚动
          if (_isHovering) {
            _startScrolling();
          }
        } else {
          if (_isOverflowing) {
            setState(() {
              _isOverflowing = false;
            });
            _controller.reset();
          }
        }
      }
    });
  }

  void _onHover(bool hovering) {
    setState(() {
      _isHovering = hovering;
    });

    if (hovering || widget.forceScroll) {
      // 每次 Hover 时或强制滚动时重新检查溢出，以适应布局宽度的变化
      _checkOverflow();
    } else {
      // Hover 结束且非强制滚动，停止滚动
      _controller.stop();
      _controller.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  void _startScrolling() {
    // 延迟滚动
    Future.delayed(widget.scrollDelay, () {
      if (mounted && (_isHovering || widget.forceScroll) && _isOverflowing) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 MouseRegion 包裹来检测 Hover
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: !_isOverflowing
          ? Text(
              widget.text,
              key: _textKey,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: widget.textAlign,
            )
          : ClipRect(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(-_animation.value * _scrollDistance, 0),
                    child: Text(
                      widget.text,
                      key: _textKey, // 保持 Key 以便测量
                      style: widget.style,
                      maxLines: 1,
                      overflow: TextOverflow.visible, // 允许溢出以便滚动显示
                      softWrap: false,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
