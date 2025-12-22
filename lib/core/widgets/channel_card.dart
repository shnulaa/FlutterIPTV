import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../platform/platform_detector.dart';
import 'tv_focusable.dart';

/// A 16:9 card widget for displaying channel information
/// TV端优化：无特效，长按显示菜单
class ChannelCard extends StatelessWidget {
  final String name;
  final String? logoUrl;
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
  final bool autofocus;
  final FocusNode? focusNode;

  const ChannelCard({
    super.key,
    required this.name,
    this.logoUrl,
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
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetector.isTV;

    return TVFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      onSelect: onTap,
      onLeft: onLeft,
      onDown: onDown,
      focusScale: isTV ? 1.0 : 1.03, // TV端不缩放
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? const Color(0xFF1E1E2E) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isFocused
                  ? AppTheme.focusBorderColor
                  : isPlaying
                      ? AppTheme.successColor
                      : AppTheme.glassBorderColor,
              width: isFocused ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onLongPress: isTV ? () => _showTVMenu(context) : onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo area - 固定高度
            SizedBox(
              height: 80,
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
                      color: const Color(0xFF0A0A0A),
                      child: Center(
                        child: logoUrl != null && logoUrl!.isNotEmpty
                            ? _buildChannelLogo(logoUrl!)
                            : _buildPlaceholder(),
                      ),
                    ),
                    // Playing indicator
                    if (isPlaying)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.lotusGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 5),
                              SizedBox(width: 3),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    // 非TV端显示收藏和测试按钮
                    if (!isTV)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onTest != null) _buildTestButton(),
                            const SizedBox(width: 4),
                            _buildFavoriteButton(),
                          ],
                        ),
                      ),
                    // TV端只显示收藏图标（小）
                    if (isTV && isFavorite)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.favorite, color: AppTheme.primaryColor, size: 16),
                      ),
                    // Unavailable indicator
                    if (isUnavailable)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('失效', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Expanded 填充剩余空间，内容靠下
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (currentProgram != null && currentProgram!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.play_circle_filled, color: AppTheme.primaryColor, size: 9),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(currentProgram!, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (nextProgram != null && nextProgram!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: AppTheme.textMuted, size: 9),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(nextProgram!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ] else if (currentProgram == null && groupName != null) ...[
                      const SizedBox(height: 2),
                      Text(groupName!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TV端长按菜单
  void _showTVMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收藏/取消收藏
            TVFocusable(
              autofocus: true,
              onSelect: () {
                Navigator.pop(ctx);
                onFavoriteToggle?.call();
              },
              builder: (context, isFocused, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isFocused ? AppTheme.primaryColor : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: child,
                );
              },
              child: Row(
                children: [
                  Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(isFavorite ? '取消收藏' : '添加收藏', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 测试频道
            if (onTest != null)
              TVFocusable(
                onSelect: () {
                  Navigator.pop(ctx);
                  onTest?.call();
                },
                builder: (context, isFocused, child) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isFocused ? AppTheme.primaryColor : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: child,
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('测试频道', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTest,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isUnavailable ? AppTheme.warningColor.withAlpha(200) : const Color(0x80000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.speed_rounded, color: Colors.white, size: 12),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onFavoriteToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
            color: isFavorite ? AppTheme.primaryColor : Colors.white,
            size: 12,
          ),
        ),
      ),
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
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.file(File(url), fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => _buildPlaceholder()),
      );
    }
  }
}
