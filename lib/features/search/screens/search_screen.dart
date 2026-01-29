import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../../../core/services/service_locator.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../../core/platform/native_player_channel.dart';
import '../widgets/qr_search_dialog.dart';

class SearchScreen extends StatefulWidget {
  final bool embedded;
  
  const SearchScreen({super.key, this.embedded = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field on mobile
    if (!PlatformDetector.useDPadNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
    final topPadding = isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0) : 0.0;

    final content = Column(
      children: [
        // 横屏时添加状态栏间距
        if (isLandscape && topPadding > 0 && widget.embedded)
          SizedBox(height: topPadding),
        _buildSearchHeader(),
        Expanded(child: _buildSearchResults()),
      ],
    );

    if (isTV) {
      return Scaffold(
        body: Container(
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
          child: TVSidebar(
            selectedIndex: 4, // 搜索页
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildSearchHeader() {
    final isTV = PlatformDetector.isTV || PlatformDetector.useDPadNavigation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;  // 与其他页面保持一致
    final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
    final topPadding = isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0) : (MediaQuery.of(context).padding.top + 8);
    
    return Container(
      height: isLandscape ? 24.0 : null,  // 横屏时固定高度24px，与AppBar一致
      padding: EdgeInsets.only(
        top: isLandscape ? 0 : (topPadding + 8),  // 横屏时不需要padding
        left: 16,
        right: 16,
        bottom: isLandscape ? 0 : 8,  // 横屏时不需要padding
      ),
      alignment: isLandscape ? Alignment.centerLeft : null,  // 横屏时垂直居中
      decoration: BoxDecoration(
        gradient: isLandscape ? null : LinearGradient(  // 横屏时移除渐变背景
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                ]
              : [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.3),
                ],
        ),
        boxShadow: isLandscape ? null : [  // 横屏时移除阴影
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button - 只在非嵌入模式下显示
          if (!widget.embedded)
            TVFocusable(
              onSelect: () => Navigator.pop(context),
              focusScale: 1.1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.getTextPrimary(context),
                  size: 20,
                ),
              ),
            ),

          if (!widget.embedded)
            const SizedBox(width: 12),

          // Search Field - TV 端使用可点击的搜索框
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: isTV 
                  ? _buildTVSearchField()
                  : _buildMobileSearchField(),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // QR Code Scan Button (TV only)
          if (isTV)
            TVFocusable(
              onSelect: _showQrSearchDialog,
              focusScale: 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimaryColor(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.getPrimaryColor(context),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTVSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TVFocusable(
      autofocus: false,  // 不自动聚焦到搜索框
      onSelect: () => _showTVSearchDialog(),
      focusScale: 1.02,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0x14FFFFFF)  // 白色 8% 透明度
              : const Color(0x08000000),  // 黑色 3% 透明度
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? const Color(0x26FFFFFF)  // 白色 15% 透明度
                : const Color(0x14000000),  // 黑色 8% 透明度
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AppTheme.getTextMuted(context),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _searchQuery.isEmpty 
                    ? (AppStrings.of(context)?.searchHint ?? 'Search channels...')
                    : _searchQuery,
                style: TextStyle(
                  color: _searchQuery.isEmpty 
                      ? AppTheme.getTextMuted(context)
                      : AppTheme.getTextPrimary(context),
                  fontSize: 14,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                }),
                child: Icon(
                  Icons.clear_rounded,
                  color: AppTheme.getTextMuted(context),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSearchField() {
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;  // 与其他页面保持一致
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(isLandscape ? 10 : 12),  // 横屏时圆角更小
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(
          color: AppTheme.getTextPrimary(context),
          fontSize: isLandscape ? 14 : 16,  // 横屏时字体更小
        ),
        decoration: InputDecoration(
          hintText: AppStrings.of(context)?.searchHint ?? 'Search channels...',
          hintStyle: TextStyle(
            color: AppTheme.getTextMuted(context),
            fontSize: isLandscape ? 14 : 16,  // 横屏时字体更小
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.getTextMuted(context),
            size: isLandscape ? 20 : 24,  // 横屏时图标更小
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppTheme.getTextMuted(context),
                    size: isLandscape ? 20 : 24,  // 横屏时图标更小
                  ),
                  padding: isLandscape ? const EdgeInsets.all(4) : null,  // 横屏时减少padding
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,  // 横屏时减少padding
            vertical: isLandscape ? 6 : 8,  // 横屏时减少padding
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  void _showTVSearchDialog() {
    final dialogController = TextEditingController(text: _searchQuery);
    final searchButtonFocusNode = FocusNode();
    final cancelButtonFocusNode = FocusNode();
    final inputFocusNode = FocusNode();
    bool isInputFocused = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.getSurfaceColor(context),
              title: Text(
                AppStrings.of(context)?.searchChannels ?? 'Search Channels',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 输入框区域 - 使用 Focus 包装来处理焦点
                    Focus(
                      onFocusChange: (hasFocus) {
                        setDialogState(() {
                          isInputFocused = hasFocus;
                        });
                      },
                      onKeyEvent: (node, event) {
                        // 当按下向下键时，移动焦点到搜索按钮
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                            searchButtonFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isInputFocused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: dialogController,
                          focusNode: inputFocusNode,
                          autofocus: true,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 18,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.of(context)?.searchHint ?? 'Search channels...',
                            hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
                            filled: true,
                            fillColor: AppTheme.getCardColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          onSubmitted: (value) {
                            setState(() {
                              _searchQuery = value;
                              _searchController.text = value;
                            });
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 取消按钮
                        Focus(
                          focusNode: cancelButtonFocusNode,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                inputFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                searchButtonFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.select ||
                                  event.logicalKey == LogicalKeyboardKey.enter) {
                                Navigator.pop(dialogContext);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasFocus ? AppTheme.getPrimaryColor(context) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(
                                    AppStrings.of(context)?.cancel ?? 'Cancel',
                                    style: const TextStyle(color: AppTheme.textMuted),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 搜索按钮
                        Focus(
                          focusNode: searchButtonFocusNode,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                inputFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                cancelButtonFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.select ||
                                  event.logicalKey == LogicalKeyboardKey.enter) {
                                setState(() {
                                  _searchQuery = dialogController.text;
                                  _searchController.text = dialogController.text;
                                });
                                Navigator.pop(dialogContext);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasFocus ? Colors.white : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = dialogController.text;
                                      _searchController.text = dialogController.text;
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.getPrimaryColor(context),
                                  ),
                                  child: Text(
                                    AppStrings.of(context)?.search ?? 'Search',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      searchButtonFocusNode.dispose();
      cancelButtonFocusNode.dispose();
      inputFocusNode.dispose();
    });
  }

  void _showQrSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => QrSearchDialog(
        onSearchReceived: (query) {
          setState(() {
            _searchQuery = query;
            _searchController.text = query;
          });
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        if (_searchQuery.isEmpty) {
          return _buildEmptySearch();
        }

        final results = provider.searchChannels(_searchQuery);

        if (results.isEmpty) {
          return _buildNoResults();
        }

        return _buildResultsGrid(results);
      },
    );
  }

  Widget _buildEmptySearch() {
    return Center(
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
              Icons.search_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.searchChannels ?? 'Search Channels',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.typeToSearch ?? 'Type to search by channel name or category',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),

          // Recent Searches (placeholder)
          const SizedBox(height: 40),
          if (PlatformDetector.useDPadNavigation) ...[
            Text(
              AppStrings.of(context)?.popularCategories ?? 'Popular Categories',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppStrings.of(context)?.sports ?? 'Sports',
                AppStrings.of(context)?.movies ?? 'Movies',
                AppStrings.of(context)?.news ?? 'News',
                AppStrings.of(context)?.music ?? 'Music',
                AppStrings.of(context)?.kids ?? 'Kids'
              ].map((category) {
                return TVFocusable(
                  onSelect: () {
                    _searchController.text = category;
                    setState(() => _searchQuery = category);
                  },
                  child: Chip(
                    label: Text(
                      category,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    ),
                    backgroundColor: AppTheme.getSurfaceColor(context),
                    side: BorderSide(color: AppTheme.getCardColor(context)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppTheme.getTextMuted(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(context)?.noResultsFound ?? 'No Results Found',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (AppStrings.of(context)?.noChannelsMatch ?? 'No channels match "{query}"').replaceAll('{query}', _searchQuery),
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<dynamic> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            (AppStrings.of(context)?.resultsFor ?? '{count} result(s) for "{query}"').replaceAll('{count}', '${results.length}').replaceAll('{query}', _searchQuery),
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ),

        // Results Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - (PlatformDetector.isMobile ? 16 : 40); // 减去padding
              final crossAxisCount = CardSizeCalculator.calculateCardsPerRow(availableWidth);
              
              return GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: PlatformDetector.isMobile ? 8 : 20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: CardSizeCalculator.aspectRatio(),
                  crossAxisSpacing: CardSizeCalculator.spacing,
                  mainAxisSpacing: CardSizeCalculator.spacing,
                ),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final channel = results[index];
                  final isFavorite = context.read<FavoritesProvider>().isFavorite(channel.id ?? 0);
                  final epgProvider = context.watch<EpgProvider>();
                  final currentProgram = epgProvider.getCurrentProgram(channel.epgId, channel.name);
                  final nextProgram = epgProvider.getNextProgram(channel.epgId, channel.name);

                  return ChannelCard(
                    name: channel.name,
                    logoUrl: channel.logoUrl,
                    channel: channel, // 传递完整的 channel 对象
                    groupName: channel.groupName,
                    currentProgram: currentProgram?.title,
                    nextProgram: nextProgram?.title,
                    isFavorite: isFavorite,
                    autofocus: index == 0 && PlatformDetector.useDPadNavigation,
                    onFavoriteToggle: () {
                      context.read<FavoritesProvider>().toggleFavorite(channel);
                    },
                    onTap: () {
                      // 保存上次播放的频道ID
                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.rememberLastChannel && channel.id != null) {
                        settingsProvider.setLastChannelId(channel.id);
                      }

                      // 检查是否启用了分屏模式
                      if (settingsProvider.enableMultiScreen) {
                        // TV 端使用原生分屏播放器
                        if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
                          final channelProvider = context.read<ChannelProvider>();
                          final channels = channelProvider.channels;
                          
                          // 找到当前点击频道的索引
                          final clickedIndex = channels.indexWhere((c) => c.url == channel.url);
                          
                          // 准备频道数据
                          final urls = channels.map((c) => c.url).toList();
                          final names = channels.map((c) => c.name).toList();
                          final groups = channels.map((c) => c.groupName ?? '').toList();
                          final sources = channels.map((c) => c.sources).toList();
                          final logos = channels.map((c) => c.logoUrl ?? '').toList();
                          
                          // 启动原生分屏播放器
                          NativePlayerChannel.launchMultiScreen(
                            urls: urls,
                            names: names,
                            groups: groups,
                            sources: sources,
                            logos: logos,
                            initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
                            volumeBoostDb: settingsProvider.volumeBoost,
                            defaultScreenPosition: settingsProvider.defaultScreenPosition,
                            onClosed: () {
                              ServiceLocator.log.d('Native multi-screen closed', tag: 'SearchScreen');
                            },
                          );
                        } else if (PlatformDetector.isDesktop) {
                          final multiScreenProvider = context.read<MultiScreenProvider>();
                          final defaultPosition = settingsProvider.defaultScreenPosition;
                          // 设置音量增强到分屏Provider
                          multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
                          multiScreenProvider.playChannelAtDefaultPosition(channel, defaultPosition);
                          
                          Navigator.pushNamed(context, AppRouter.player, arguments: {
                            'channelUrl': '',
                            'channelName': '',
                            'channelLogo': null,
                          });
                        } else {
                          Navigator.pushNamed(
                            context,
                            AppRouter.player,
                            arguments: {
                              'channelUrl': channel.url,
                              'channelName': channel.name,
                              'channelLogo': channel.logoUrl,
                            },
                          );
                        }
                      } else {
                        Navigator.pushNamed(
                          context,
                          AppRouter.player,
                          arguments: {
                            'channelUrl': channel.url,
                            'channelName': channel.name,
                            'channelLogo': channel.logoUrl,
                          },
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
