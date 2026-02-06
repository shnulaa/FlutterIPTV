import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../platform/platform_detector.dart';
import '../i18n/app_strings.dart';
import '../models/channel.dart';
import 'tv_focusable.dart';
import 'channel_logo_widget.dart';

/// A card widget for displaying channel information
/// 使用固定宽高比，内部布局自适应
/// TV端优化：无特效，长按显示菜单
/// 
/// 功能特性：
/// - 自动滚动：
///   * Windows端：鼠标悬停时滚动显示完整内容，移开后恢复原样
///   * TV端：焦点聚焦时滚动显示完整内容，失去焦点后恢复原样
/// - 响应式布局：根据设备类型（TV/Mobile/Desktop）自适应显示
/// - EPG信息：显示当前和下一个节目信息
class ChannelCard extends StatefulWidget {
  final String name;
  final String? logoUrl;
  final Channel? channel; // 新增：完整的 Channel 对象，用于 ChannelLogoWidget
  final String? groupName;
  final String? currentProgram;
  final String? nextProgram;
  final bool isFavorite;
  final bool isPlaying;
  final bool isUnavailable;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTest;
  final VoidCallback? onLeft;
  final VoidCallback? onDown;
  final VoidCallback? onUp; // 添加onUp回调
  final VoidCallback? onFocused; // 获得焦点时的回调
  final bool autofocus;
  final FocusNode? focusNode;

  const ChannelCard({
    super.key,
    required this.name,
    this.logoUrl,
    this.channel,
    this.groupName,
    this.currentProgram,
    this.nextProgram,
    this.isFavorite = false,
    this.isPlaying = false,
    this.isUnavailable = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onTest,
    this.onLeft,
    this.onDown,
    this.onUp, // 添加onUp参数
    this.onFocused,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetector.isTV;
    final isMobile = PlatformDetector.isMobile;

    return TVFocusable(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onSelect: widget.onTap,
      onFocus: () {
        setState(() => _isFocused = true);
        widget.onFocused?.call();
      },
      onBlur: () {
        setState(() => _isFocused = false);
      },
      onLeft: widget.onLeft,
      onDown: widget.onDown,
      onUp: widget.onUp, // 添加onUp回调
      focusScale: isTV ? 1.0 : 1.03, // TV端不缩放
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE8E0F0)) : AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : widget.isPlaying
                      ? AppTheme.successColor
                      : AppTheme.getGlassBorderColor(context),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onLongPress: isTV ? () => _showTVMenu(context) : widget.onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo area - 固定占60%高度
            Expanded(
              flex: 55,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMedium),
                  topRight: Radius.circular(AppTheme.radiusMedium),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Logo
                    Container(
                      decoration: Theme.of(context).brightness == Brightness.dark
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF0A0A0A),
                                  AppTheme.getPrimaryColor(context).withOpacity(0.15),
                                ],
                              ),
                            )
                          : BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.getPrimaryColor(context).withOpacity(0.4),
                                  AppTheme.getPrimaryColor(context).withOpacity(0.99),
                                ],
                              ),
                            ),
                      child: Center(
                        child: widget.channel != null 
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: ChannelLogoWidget(
                                  channel: widget.channel!,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : (widget.logoUrl != null && widget.logoUrl!.isNotEmpty 
                                ? _buildChannelLogo(widget.logoUrl!) 
                                : _buildPlaceholder()),
                      ),
                    ),
                    // Playing indicator
                    if (widget.isPlaying)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6, vertical: isMobile ? 2 : 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.getGradient(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: isMobile ? 4 : 5),
                              SizedBox(width: isMobile ? 2 : 3),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: isMobile ? 7 : 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    // 非TV端显示收藏和测试按钮
                    if (!isTV)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onTest != null) _buildTestButton(isMobile),
                            SizedBox(width: isMobile ? 2 : 4),
                            _buildFavoriteButton(isMobile),
                          ],
                        ),
                      ),
                    // TV端只显示收藏图标（小）
                    if (isTV && widget.isFavorite)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.favorite, color: AppTheme.getPrimaryColor(context), size: 16),
                      ),
                    // Unavailable indicator
                    if (widget.isUnavailable)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 5, vertical: isMobile ? 1 : 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(AppStrings.of(context)?.unavailable ?? 'Unavailable', style: TextStyle(color: Colors.white, fontSize: isMobile ? 6 : 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 内容区域 - 固定占40%高度，内容自适应
            Expanded(
              flex: 40,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 4 : 8,
                  vertical: isMobile ? 3 : 5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 频道名称 - 始终显示，支持自动滚动
                    _AutoScrollText(
                      text: widget.name,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      shouldScroll: _isHovered || _isFocused,
                    ),
                    // EPG或分类信息 - 自适应显示
                    Expanded(
                      child: _buildInfoSection(context, isMobile),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息区域（EPG或分类）- 静态显示当前和下一个节目
  Widget _buildInfoSection(BuildContext context, bool isMobile) {
    final hasCurrentProgram = widget.currentProgram != null && widget.currentProgram!.isNotEmpty;
    final hasNextProgram = widget.nextProgram != null && widget.nextProgram!.isNotEmpty;
    final hasGroup = widget.groupName != null && widget.groupName!.isNotEmpty;
    final hasEpg = hasCurrentProgram || hasNextProgram;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // 如果有EPG信息，显示EPG
        if (hasEpg) ...[
          if (hasCurrentProgram) ...[
            SizedBox(height: isMobile ? 1 : 2),
            Row(
              children: [
                Icon(Icons.play_circle_filled, color: AppTheme.getPrimaryColor(context), size: isMobile ? 7 : 9),
                SizedBox(width: isMobile ? 2 : 3),
                Expanded(
                  child: _AutoScrollText(
                    text: widget.currentProgram!,
                    style: TextStyle(
                      color: AppTheme.getPrimaryColor(context), 
                      fontSize: isMobile ? 7 : 9,
                      height: 1.1,
                    ),
                    shouldScroll: _isHovered || _isFocused,
                  ),
                ),
              ],
            ),
          ],
          if (hasNextProgram) ...[
            SizedBox(height: isMobile ? 1 : 2),
            Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.getPrimaryColor(context).withOpacity(0.7), size: isMobile ? 7 : 9),
                SizedBox(width: isMobile ? 2 : 3),
                Expanded(
                  child: _AutoScrollText(
                    text: widget.nextProgram!,
                    style: TextStyle(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.8), 
                      fontSize: isMobile ? 7 : 9,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                    shouldScroll: _isHovered || _isFocused,
                  ),
                ),
              ],
            ),
          ],
        ] 
        // 如果没有EPG信息，显示分类和"暂无节目信息"
        else ...[
          if (hasGroup) ...[
            SizedBox(height: isMobile ? 1 : 2),
            _AutoScrollText(
              text: widget.groupName!,
              style: TextStyle(
                color: AppTheme.getPrimaryColor(context).withOpacity(0.8), 
                fontSize: isMobile ? 8 : 10,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
              shouldScroll: _isHovered || _isFocused,
            ),
          ],
          SizedBox(height: isMobile ? 1 : 2),
          Text(
            AppStrings.of(context)?.noProgramInfo ?? 'No Program Info',
            style: TextStyle(
              color: AppTheme.getPrimaryColor(context).withOpacity(0.6), 
              fontSize: isMobile ? 7 : 9,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // TV端长按菜单
  void _showTVMenu(BuildContext context) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收藏/取消收藏
            TVFocusable(
              autofocus: true,
              onSelect: () {
                Navigator.pop(ctx);
                widget.onFavoriteToggle?.call();
              },
              builder: (context, isFocused, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: child,
                );
              },
              child: Row(
                children: [
                  Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(widget.isFavorite ? (strings?.removeFavorites ?? 'Remove from favorites') : (strings?.addFavorites ?? 'Add to favorites'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 测试频道
            if (widget.onTest != null)
              TVFocusable(
                onSelect: () {
                  Navigator.pop(ctx);
                  widget.onTest?.call();
                },
                builder: (context, isFocused, child) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: child,
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(strings?.testChannel ?? 'Test channel', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(bool isMobile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTest,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 3 : 5),
          decoration: BoxDecoration(
            color: widget.isUnavailable ? AppTheme.warningColor.withAlpha(200) : const Color(0x80000000),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.speed_rounded, color: Colors.white, size: isMobile ? 10 : 12),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool isMobile) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onFavoriteToggle,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 3 : 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x80000000) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Icon(
                widget.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                color: widget.isFavorite ? AppTheme.getPrimaryColor(context) : (isDark ? Colors.white : Colors.grey[500]),
                size: isMobile ? 10 : 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    // 使用默认台标图片
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Image.asset('assets/images/default_logo.png', fit: BoxFit.contain),
    );
  }

  Widget _buildChannelLogo(String url) {
    if (url.startsWith('http')) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          memCacheWidth: 160, // 限制内存缓存大小
          memCacheHeight: 90,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.file(File(url), fit: BoxFit.contain, cacheWidth: 160, cacheHeight: 90, errorBuilder: (context, error, stackTrace) => _buildPlaceholder()),
      );
    }
  }
}

/// 自动滚动文本组件
/// 当文本超出容器宽度时，在悬停或聚焦状态下自动滚动显示完整内容
class _AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool shouldScroll;

  const _AutoScrollText({
    required this.text,
    this.style,
    this.shouldScroll = false,
  });

  @override
  State<_AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<_AutoScrollText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOverflowing = false;
  double _scrollDistance = 0;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(_AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _checkOverflow();
    }
    
    // 当shouldScroll状态改变时，控制动画
    if (oldWidget.shouldScroll != widget.shouldScroll) {
      if (widget.shouldScroll && _isOverflowing) {
        // 开始滚动
        _controller.repeat(reverse: true);
      } else {
        // 停止滚动并重置到初始位置
        _controller.stop();
        _controller.reset();
      }
    }
  }

  void _checkOverflow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        
        final containerWidth = renderBox.size.width;
        final textWidth = textPainter.width;
        
        setState(() {
          _isOverflowing = textWidth > containerWidth;
          if (_isOverflowing) {
            // 计算需要滚动的距离（文本宽度 - 容器宽度 + 一些额外空间）
            _scrollDistance = textWidth - containerWidth + 20;
          }
        });
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
    if (!_isOverflowing) {
      return Text(
        widget.text,
        key: _textKey,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(-_animation.value * _scrollDistance, 0),
            child: Text(
              widget.text,
              key: _textKey,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          );
        },
      ),
    );
  }
}
