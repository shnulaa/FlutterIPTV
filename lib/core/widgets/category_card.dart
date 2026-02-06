import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../platform/platform_detector.dart';
import 'tv_focusable.dart';
import 'auto_scroll_text.dart';

/// A category chip/card for the home screen
/// TV端优化：无特效
class CategoryCard extends StatefulWidget {
  final String name;
  final int channelCount;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  const CategoryCard({
    super.key,
    required this.name,
    required this.channelCount,
    this.icon = Icons.folder_rounded,
    this.color,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();

  static IconData getIconForCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('sport') || lowerName.contains('体育')) return Icons.sports_soccer_rounded;
    if (lowerName.contains('movie') || lowerName.contains('电影')) return Icons.movie_rounded;
    if (lowerName.contains('news') || lowerName.contains('新闻')) return Icons.newspaper_rounded;
    if (lowerName.contains('music') || lowerName.contains('音乐')) return Icons.music_note_rounded;
    if (lowerName.contains('kid') || lowerName.contains('少儿')) return Icons.child_care_rounded;
    if (lowerName.contains('cctv') || lowerName.contains('央视')) return Icons.account_balance_rounded;
    if (lowerName.contains('卫视')) return Icons.satellite_alt_rounded;
    return Icons.live_tv_rounded;
  }
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? AppTheme.getPrimaryColor(context);
    final isTV = PlatformDetector.isTV;

    return TVFocusable(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onSelect: widget.onTap,
      onFocus: () => setState(() => _isFocused = true),
      onBlur: () => setState(() => _isFocused = false),
      focusScale: isTV ? 1.0 : 1.03,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: isFocused ? LinearGradient(colors: [cardColor.withAlpha(180), cardColor.withAlpha(120)]) : LinearGradient(colors: [cardColor.withAlpha(60), cardColor.withAlpha(30)]),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isFocused ? AppTheme.getPrimaryColor(context).withAlpha(200) : AppTheme.getGlassBorderColor(context),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoScrollText(
                  text: widget.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  forceScroll: _isHovered || _isFocused,
                ),
                const SizedBox(height: 3),
                Text('${widget.channelCount} 频道', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
