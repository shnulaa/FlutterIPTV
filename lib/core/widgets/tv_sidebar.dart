import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../navigation/app_router.dart';
import '../i18n/app_strings.dart';
import 'tv_focusable.dart';

/// TV端共享侧边栏组件
/// 失去焦点收起，获得焦点展开
class TVSidebar extends StatefulWidget {
  final int selectedIndex;
  final Widget child;
  final VoidCallback? onRight; // 按右键时的回调

  /// 用于外部获取菜单焦点节点列表
  static List<FocusNode>? menuFocusNodes;

  /// 当前选中的菜单索引
  static int? selectedMenuIndex;

  const TVSidebar({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.onRight,
  });

  @override
  State<TVSidebar> createState() => _TVSidebarState();
}

class _TVSidebarState extends State<TVSidebar> {
  bool _expanded = false;
  final List<FocusNode> _menuFocusNodes = [];
  Timer? _navDelayTimer; // 延迟导航定时器
  int? _pendingNavIndex; // 待导航的菜单索引

  @override
  void initState() {
    super.initState();
    // 创建5个菜单项的焦点节点
    for (int i = 0; i < 5; i++) {
      _menuFocusNodes.add(FocusNode());
    }
    // 暴露给外部
    TVSidebar.menuFocusNodes = _menuFocusNodes;
    TVSidebar.selectedMenuIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(TVSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      TVSidebar.selectedMenuIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _navDelayTimer?.cancel();
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    TVSidebar.menuFocusNodes = null;
    TVSidebar.selectedMenuIndex = null;
    super.dispose();
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    return [
      _NavItem(icon: Icons.home_rounded, label: AppStrings.of(context)?.home ?? 'Home', route: null),
      _NavItem(icon: Icons.live_tv_rounded, label: AppStrings.of(context)?.channels ?? 'Channels', route: AppRouter.channels),
      _NavItem(icon: Icons.favorite_rounded, label: AppStrings.of(context)?.favorites ?? 'Favorites', route: AppRouter.favorites),
      _NavItem(icon: Icons.search_rounded, label: AppStrings.of(context)?.search ?? 'Search', route: AppRouter.search),
      _NavItem(icon: Icons.settings_rounded, label: AppStrings.of(context)?.settings ?? 'Settings', route: AppRouter.settings),
    ];
  }

  void _onNavItemTap(int index, String? route) {
    if (index == widget.selectedIndex) return;

    if (index == 0) {
      // 返回首页：直接 pop 到首页
      Navigator.of(context).popUntil((r) => r.settings.name == AppRouter.home || r.isFirst);
    } else if (route != null) {
      if (widget.selectedIndex == 0) {
        // 从首页跳转，直接 push
        Navigator.pushNamed(context, route);
      } else {
        // 从其他页面跳转，使用 pushReplacementNamed 替换当前页面
        Navigator.pushReplacementNamed(context, route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems(context);
    final width = _expanded ? 150.0 : 52.0;

    return Row(
      children: [
        // 侧边栏
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _expanded = hasFocus);
            // 当侧边栏获得焦点时，自动聚焦到当前选中的菜单项
            if (hasFocus && widget.selectedIndex < _menuFocusNodes.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final targetNode = _menuFocusNodes[widget.selectedIndex];
                if (targetNode.canRequestFocus && !targetNode.hasFocus) {
                  targetNode.requestFocus();
                }
              });
            }
          },
          child: Container(
            width: width,
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
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Logo
                _buildLogo(),
                const SizedBox(height: 16),
                // Nav Items
                Expanded(
                  child: TVFocusTraversalGroup(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: _expanded ? 6 : 4),
                      itemCount: navItems.length,
                      itemBuilder: (context, index) => _buildNavItem(index, navItems[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // 主内容
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 8),
      child: _expanded
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.getGradient(context).createShader(bounds),
                    child: const Text('Lotus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
          : Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = widget.selectedIndex == index;
    final focusNode = index < _menuFocusNodes.length ? _menuFocusNodes[index] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Focus(
        focusNode: focusNode,
        autofocus: index == widget.selectedIndex,
        onFocusChange: (hasFocus) {
          // 强制刷新UI
          if (mounted) setState(() {});

          // 延迟触发导航
          if (hasFocus && index != widget.selectedIndex) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = index;
            _navDelayTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted && _pendingNavIndex == index) {
                _onNavItemTap(index, item.route);
              }
            });
          } else if (!hasFocus && _pendingNavIndex == index) {
            // 失去焦点时取消待导航
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
            // 手动确认时立即导航，取消延迟
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            _onNavItemTap(index, item.route);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
            // 按右键时取消延迟导航
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            widget.onRight!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _onNavItemTap(index, item.route),
          child: Builder(
            builder: (context) {
              // 直接检查 FocusNode 的实际焦点状态
              final isFocused = focusNode?.hasFocus ?? false;
              // 只有当侧边栏展开时才显示焦点高亮
              final showHighlight = isFocused && _expanded;
              final showSelected = isSelected && !showHighlight;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 8, vertical: 10),
                decoration: BoxDecoration(
                  gradient: showHighlight ? AppTheme.getGradient(context) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _expanded
                    ? Row(
                        children: [
                          Icon(item.icon, color: showHighlight ? Colors.white : (showSelected ? AppTheme.getPrimaryColor(context) : AppTheme.getTextMuted(context)), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.label,
                                style: TextStyle(
                                  color: showHighlight ? Colors.white : (showSelected ? AppTheme.getPrimaryColor(context) : AppTheme.getTextSecondary(context)),
                                  fontSize: 12,
                                  fontWeight: (showHighlight || showSelected) ? FontWeight.w600 : FontWeight.normal,
                                )),
                          ),
                        ],
                      )
                    : Center(child: Icon(item.icon, color: showHighlight ? Colors.white : (showSelected ? AppTheme.getPrimaryColor(context) : AppTheme.getTextMuted(context)), size: 18)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String? route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
