# Catchup 功能平台差异化设计文档

## 1. 平台概述

本应用支持三个主要平台：
- **Android TV**：大屏电视，遥控器操作
- **Mobile**（Android/iOS）：手机/平板，触摸操作
- **Windows**：桌面应用，鼠标键盘操作

每个平台在交互方式、UI 布局、性能优化方面都有显著差异。

---

## 2. 平台差异对比表

| 特性 | Android TV | Mobile | Windows |
|------|-----------|--------|---------|
| **输入方式** | 遥控器（方向键+OK） | 触摸屏 | 鼠标+键盘 |
| **屏幕尺寸** | 大屏（40-75寸） | 小屏（4-7寸） | 中大屏（13-27寸） |
| **屏幕方向** | 横屏固定 | 竖屏/横屏切换 | 横屏为主 |
| **焦点管理** | 必需（遥控器导航） | 不需要 | 可选 |
| **手势支持** | 无 | 丰富 | 有限 |
| **多窗口** | 不支持 | 分屏 | 完全支持 |
| **性能要求** | 中等 | 低（省电） | 高 |
| **网络环境** | WiFi 稳定 | WiFi/4G/5G | WiFi/有线 |
| **存储空间** | 较大 | 有限 | 充足 |
| **播放器** | ExoPlayer | ExoPlayer/AVPlayer | Media Foundation |

---

## 3. Android TV 详细设计

### 3.1 UI 布局特点


**布局原则：**
- 10-foot UI 设计（3米观看距离）
- 大字体、大图标、大间距
- 焦点清晰可见
- 避免小元素和复杂交互

**Catchup 界面布局：**

```
┌────────────────────────────────────────────────────────────┐
│  [CCTV1]                                    [设置] [收藏]  │  ← 顶部栏（焦点区域1）
├────────────────────────────────────────────────────────────┤
│                                                            │
│                    视频播放区域                             │
│                    (16:9 全屏)                             │
│                                                            │
├────────────────────────────────────────────────────────────┤
│  [🔴 直播]  [📺 回看]                                      │  ← 模式切换（焦点区域2）
├────────────────────────────────────────────────────────────┤
│  新闻联播  19:00-19:30                                     │  ← 节目信息（焦点区域3）
├────────────────────────────────────────────────────────────┤
│  ◀ 2月27日  |  2月28日  |  2月29日 ▶                      │  ← 日期选择（焦点区域4）
├────────────────────────────────────────────────────────────┤
│  [时间轴 - 横向滚动]                                        │  ← 时间轴（焦点区域5）
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐                          │
│  │早间│  │午间│  │新闻│  │晚间│                           │
│  │新闻│  │新闻│  │联播│  │新闻│                           │
│  └────┘  └────┘  └────┘  └────┘                          │
├────────────────────────────────────────────────────────────┤
│  [节目列表 - 纵向滚动]                                      │  ← 节目列表（焦点区域6）
│  ▶ 19:00-19:30  新闻联播                                   │
│    18:00-19:00  综合新闻                                   │
│    17:00-18:00  今日说法                                   │
│    16:00-17:00  第一时间                                   │
└────────────────────────────────────────────────────────────┘
```

### 3.2 焦点导航设计

**焦点流转规则：**

```
上键：当前区域 → 上一个区域
下键：当前区域 → 下一个区域
左键：区域内向左 / 上一个节目
右键：区域内向右 / 下一个节目
OK键：选择/播放
返回键：返回上一级 / 返回直播
```

**焦点区域优先级：**
1. 播放控制（最高优先级）
2. 模式切换
3. 日期选择
4. 时间轴
5. 节目列表
6. 顶部工具栏


### 3.3 遥控器按键映射

```dart
// TV 遥控器按键处理伪代码
class TvCatchupController {
  FocusNode currentFocus;
  List<FocusNode> focusNodes;
  
  void handleKeyEvent(KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        moveFocusUp();
        break;
      case LogicalKeyboardKey.arrowDown:
        moveFocusDown();
        break;
      case LogicalKeyboardKey.arrowLeft:
        handleLeftKey();
        break;
      case LogicalKeyboardKey.arrowRight:
        handleRightKey();
        break;
      case LogicalKeyboardKey.select:  // OK 键
        handleOkKey();
        break;
      case LogicalKeyboardKey.goBack:  // 返回键
        handleBackKey();
        break;
      case LogicalKeyboardKey.mediaPlayPause:
        togglePlayPause();
        break;
    }
  }
  
  void handleLeftKey() {
    if (currentFocus == timelineFocus) {
      // 时间轴向左滚动
      scrollTimeline(direction: -1);
    } else if (currentFocus == dateFocus) {
      // 切换到前一天
      selectPreviousDate();
    } else if (currentFocus == programListFocus) {
      // 播放上一个节目
      playPreviousProgram();
    }
  }
  
  void handleRightKey() {
    if (currentFocus == timelineFocus) {
      // 时间轴向右滚动
      scrollTimeline(direction: 1);
    } else if (currentFocus == dateFocus) {
      // 切换到后一天
      selectNextDate();
    } else if (currentFocus == programListFocus) {
      // 播放下一个节目
      playNextProgram();
    }
  }
  
  void handleOkKey() {
    if (currentFocus == programListFocus) {
      // 播放选中的节目
      playSelectedProgram();
    } else if (currentFocus == timelineFocus) {
      // 显示节目详情
      showProgramDetails();
    } else if (currentFocus == modeSwitchFocus) {
      // 切换直播/回看模式
      toggleMode();
    }
  }
  
  void handleBackKey() {
    if (isInCatchupMode) {
      // 返回直播
      returnToLive();
    } else {
      // 退出播放器
      exitPlayer();
    }
  }
}
```

### 3.4 性能优化（TV）

```dart
// TV 特定优化
class TvOptimizations {
  // 1. 预加载相邻节目
  void preloadAdjacentPrograms() {
    final currentIndex = getCurrentProgramIndex();
    if (currentIndex > 0) {
      preloadProgram(currentIndex - 1);  // 上一个
    }
    if (currentIndex < programList.length - 1) {
      preloadProgram(currentIndex + 1);  // 下一个
    }
  }
  
  // 2. 图片缓存策略（TV 内存较大）
  void configureTvImageCache() {
    PaintingBinding.instance.imageCache.maximumSize = 200;  // 增加缓存
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;  // 100MB
  }
  
  // 3. 列表虚拟化（大屏显示更多项）
  Widget buildProgramList() {
    return ListView.builder(
      itemCount: programs.length,
      itemExtent: 80.0,  // TV 上更大的项高度
      cacheExtent: 800.0,  // 预渲染更多项
      itemBuilder: (context, index) {
        return TvProgramListItem(program: programs[index]);
      },
    );
  }
  
  // 4. 焦点动画优化
  Widget buildFocusableItem(Widget child) {
    return Focus(
      onFocusChange: (hasFocus) {
        // 使用硬件加速的动画
        if (hasFocus) {
          animateScale(from: 1.0, to: 1.1, duration: 150);
        }
      },
      child: child,
    );
  }
}
```

---

## 4. Mobile 详细设计

### 4.1 UI 布局特点

**布局原则：**
- 适配小屏幕（4-7寸）
- 支持竖屏和横屏
- 触摸友好（最小点击区域 44x44dp）
- 单手操作优化

**竖屏布局：**

```
┌──────────────────────┐
│ [<] CCTV1      [⋮]   │  ← 顶部栏
├──────────────────────┤
│                      │
│   视频播放区域        │
│   (16:9)             │
│                      │
├──────────────────────┤
│ 🔴直播 | 📺回看       │  ← 标签切换
├──────────────────────┤
│ 新闻联播             │
│ 19:00-19:30          │
├──────────────────────┤
│ ◀ 2/28 ▶            │  ← 日期选择（紧凑）
├──────────────────────┤
│ [时间轴 - 横向滚动]   │
│ ━━━━━━━━━━━━━━━━━   │
├──────────────────────┤
│ [节目列表]           │
│ ▶ 19:00 新闻联播     │
│   18:00 综合新闻     │
│   17:00 今日说法     │
│   16:00 第一时间     │
│   ...                │
└──────────────────────┘
```

**横屏布局：**

```
┌────────────────────────────────────────────┐
│                                            │
│          视频播放区域（全屏）               │
│                                            │
│  [控制栏悬浮在底部]                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  [<] 19:00-19:30 新闻联播    [回看] [⋮]   │
└────────────────────────────────────────────┘
```


### 4.2 手势交互设计

```dart
// Mobile 手势处理伪代码
class MobileCatchupGestures {
  
  // 1. 视频区域手势
  Widget buildVideoGestureDetector() {
    return GestureDetector(
      onTap: () {
        // 单击：显示/隐藏控制栏
        toggleControlsVisibility();
      },
      onDoubleTap: () {
        // 双击：播放/暂停
        togglePlayPause();
      },
      onHorizontalDragUpdate: (details) {
        // 左右滑动：快进/快退
        if (details.delta.dx > 0) {
          seekForward(seconds: 10);
        } else {
          seekBackward(seconds: 10);
        }
      },
      onVerticalDragUpdate: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isLeftSide = details.localPosition.dx < screenWidth / 2;
        
        if (isLeftSide) {
          // 左侧上下滑动：调节亮度
          adjustBrightness(details.delta.dy);
        } else {
          // 右侧上下滑动：调节音量
          adjustVolume(details.delta.dy);
        }
      },
      onLongPress: () {
        // 长按：显示上下文菜单
        showContextMenu();
      },
      child: VideoPlayer(),
    );
  }
  
  // 2. 时间轴手势
  Widget buildTimelineGesture() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // 拖动时间轴
        scrollTimeline(details.delta.dx);
      },
      onTapUp: (details) {
        // 点击时间轴上的节目
        final program = getProgramAtPosition(details.localPosition);
        if (program != null) {
          showProgramPreview(program);
        }
      },
      child: TimelineWidget(),
    );
  }
  
  // 3. 节目列表手势
  Widget buildProgramListGesture() {
    return ListView.builder(
      itemCount: programs.length,
      itemBuilder: (context, index) {
        return Dismissible(
          key: Key(programs[index].id.toString()),
          background: Container(
            color: Colors.blue,
            child: Icon(Icons.favorite),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            child: Icon(Icons.delete),
          ),
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              // 右滑：添加到收藏
              addToFavorites(programs[index]);
            } else {
              // 左滑：删除历史
              removeFromHistory(programs[index]);
            }
          },
          child: ProgramListItem(
            program: programs[index],
            onTap: () => playProgram(programs[index]),
            onLongPress: () => showProgramOptions(programs[index]),
          ),
        );
      },
    );
  }
  
  // 4. 下拉刷新
  Widget buildRefreshableList() {
    return RefreshIndicator(
      onRefresh: () async {
        await refreshEpgData();
      },
      child: buildProgramListGesture(),
    );
  }
}
```

### 4.3 响应式布局

```dart
// Mobile 响应式设计
class MobileResponsiveLayout {
  
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final screenSize = MediaQuery.of(context).size;
    
    if (orientation == Orientation.portrait) {
      return buildPortraitLayout();
    } else {
      return buildLandscapeLayout();
    }
  }
  
  Widget buildPortraitLayout() {
    return Column(
      children: [
        // 顶部栏
        AppBar(height: 56),
        // 视频播放器（16:9）
        AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer(),
        ),
        // 模式切换标签
        TabBar(tabs: ['直播', '回看']),
        // 节目信息卡片
        ProgramInfoCard(height: 80),
        // 日期选择器（紧凑）
        CompactDatePicker(height: 50),
        // 时间轴（横向滚动）
        TimelineWidget(height: 100),
        // 节目列表（占据剩余空间）
        Expanded(
          child: ProgramList(),
        ),
      ],
    );
  }
  
  Widget buildLandscapeLayout() {
    return Stack(
      children: [
        // 全屏视频
        Positioned.fill(
          child: VideoPlayer(),
        ),
        // 底部控制栏（自动隐藏）
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: Duration(milliseconds: 300),
            child: BottomControlBar(),
          ),
        ),
        // 侧边节目列表（可滑出）
        Positioned(
          right: showSidebar ? 0 : -300,
          top: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 300,
            child: ProgramSidebar(),
          ),
        ),
      ],
    );
  }
}
```

### 4.4 性能优化（Mobile）

```dart
// Mobile 特定优化（省电、省流量）
class MobileOptimizations {
  
  // 1. 图片加载优化
  void configureImageLoading() {
    // 根据网络状态调整图片质量
    if (isOnMobileData) {
      imageQuality = ImageQuality.low;
      enableImageCompression = true;
    } else {
      imageQuality = ImageQuality.high;
      enableImageCompression = false;
    }
  }
  
  // 2. EPG 数据加载策略
  Future<void> loadEpgData() async {
    // 仅加载当前日期 ± 1 天
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));
    final tomorrow = today.add(Duration(days: 1));
    
    await loadEpgForDateRange(yesterday, tomorrow);
  }
  
  // 3. 列表优化（小屏显示较少项）
  Widget buildOptimizedList() {
    return ListView.builder(
      itemCount: programs.length,
      itemExtent: 60.0,  // Mobile 上较小的项高度
      cacheExtent: 300.0,  // 较小的预渲染范围
      addAutomaticKeepAlives: false,  // 不保持状态
      addRepaintBoundaries: true,  // 优化重绘
      itemBuilder: (context, index) {
        return MobileProgramListItem(program: programs[index]);
      },
    );
  }
  
  // 4. 后台播放优化
  void configureBackgroundPlayback() {
    // 进入后台时降低视频质量
    AppLifecycleState.paused.listen(() {
      if (isPlayingCatchup) {
        reduceVideoQuality();
      }
    });
    
    // 返回前台时恢复
    AppLifecycleState.resumed.listen(() {
      restoreVideoQuality();
    });
  }
  
  // 5. 电池优化
  void enableBatterySaving() {
    // 降低刷新率
    if (batteryLevel < 20) {
      disableAnimations();
      reducePollingFrequency();
    }
  }
}
```

---

## 5. Windows 详细设计

### 5.1 UI 布局特点

**布局原则：**
- 充分利用大屏空间
- 支持窗口调整大小
- 鼠标悬停交互
- 键盘快捷键丰富

**Windows 布局：**

```
┌──────────────────────────────────────────────────────────────┐
│ [<] CCTV1                    [最小化] [最大化] [关闭]         │
├────────────────────────────┬─────────────────────────────────┤
│                            │  [日期选择器]                    │
│                            │  ◀ 2月27日 | 2月28日 | 2月29日 ▶│
│                            ├─────────────────────────────────┤
│                            │  [节目列表 - 可调整宽度]         │
│      视频播放区域           │  ▶ 19:00-19:30  新闻联播        │
│      (可调整大小)           │    18:00-19:00  综合新闻        │
│                            │    17:00-18:00  今日说法        │
│                            │    16:00-17:00  第一时间        │
│                            │    15:00-16:00  新闻直播间      │
│                            │    ...                          │
├────────────────────────────┴─────────────────────────────────┤
│  [播放控制栏]                                                 │
│  ▶ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 🔊│
│  19:00-19:30 新闻联播                    [🔴返回直播] [⚙️]   │
└──────────────────────────────────────────────────────────────┘
```


### 5.2 鼠标和键盘交互

```dart
// Windows 交互处理伪代码
class WindowsCatchupController {
  
  // 1. 鼠标悬停效果
  Widget buildHoverableItem(Program program) {
    return MouseRegion(
      onEnter: (_) {
        // 显示节目预览
        showProgramPreview(program);
        // 高亮显示
        setState(() => hoveredProgram = program);
      },
      onExit: (_) {
        // 隐藏预览
        hidePreview();
        setState(() => hoveredProgram = null);
      },
      child: GestureDetector(
        onTap: () => playProgram(program),
        onSecondaryTap: () => showContextMenu(program),
        child: ProgramListItem(
          program: program,
          isHovered: hoveredProgram == program,
        ),
      ),
    );
  }
  
  // 2. 键盘快捷键
  Widget buildKeyboardShortcuts() {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): VolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): VolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): FullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): ExitFullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyL): ReturnToLiveIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyM): MuteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyN): NextProgramIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyP): PreviousProgramIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): SearchIntent(),
      },
      child: Actions(
        actions: {
          PlayPauseIntent: CallbackAction(onInvoke: (_) => togglePlayPause()),
          SeekBackwardIntent: CallbackAction(onInvoke: (_) => seekBackward(10)),
          SeekForwardIntent: CallbackAction(onInvoke: (_) => seekForward(10)),
          // ... 其他动作
        },
        child: Focus(
          autofocus: true,
          child: CatchupPlayerWidget(),
        ),
      ),
    );
  }
  
  // 3. 右键菜单
  void showContextMenu(Program program) {
    showMenu(
      context: context,
      position: mousePosition,
      items: [
        PopupMenuItem(
          child: Text('播放'),
          onTap: () => playProgram(program),
        ),
        PopupMenuItem(
          child: Text('添加到收藏'),
          onTap: () => addToFavorites(program),
        ),
        PopupMenuItem(
          child: Text('查看详情'),
          onTap: () => showProgramDetails(program),
        ),
        PopupMenuItem(
          child: Text('分享'),
          onTap: () => shareProgram(program),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          child: Text('复制链接'),
          onTap: () => copyProgramLink(program),
        ),
      ],
    );
  }
  
  // 4. 滚轮控制
  Widget buildScrollableTimeline() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          // 鼠标滚轮控制时间轴滚动
          scrollTimeline(event.scrollDelta.dy);
        }
      },
      child: TimelineWidget(),
    );
  }
}
```

### 5.3 窗口管理

```dart
// Windows 窗口管理
class WindowsWindowManager {
  
  // 1. 窗口大小调整
  void handleWindowResize(Size newSize) {
    if (newSize.width < 800) {
      // 小窗口：隐藏侧边栏
      setState(() => showSidebar = false);
    } else {
      // 大窗口：显示侧边栏
      setState(() => showSidebar = true);
    }
    
    // 调整布局
    updateLayout(newSize);
  }
  
  // 2. 分屏支持
  Widget buildResizableLayout() {
    return Row(
      children: [
        // 视频区域（可调整）
        Expanded(
          flex: videoFlex,
          child: VideoPlayer(),
        ),
        // 分隔条
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              adjustSplitRatio(details.delta.dx);
            },
            child: Container(
              width: 4,
              color: Colors.grey,
            ),
          ),
        ),
        // 节目列表区域（可调整）
        Expanded(
          flex: sidebarFlex,
          child: ProgramList(),
        ),
      ],
    );
  }
  
  // 3. 多窗口支持
  void openProgramInNewWindow(Program program) {
    // Windows 支持多窗口
    WindowManager.createWindow(
      title: program.title,
      width: 800,
      height: 600,
      child: CatchupPlayerWindow(program: program),
    );
  }
  
  // 4. 画中画模式
  void enablePictureInPicture() {
    WindowManager.setPictureInPictureMode(
      enabled: true,
      aspectRatio: 16 / 9,
      onClose: () => exitPictureInPicture(),
    );
  }
}
```

### 5.4 性能优化（Windows）

```dart
// Windows 特定优化（充分利用硬件）
class WindowsOptimizations {
  
  // 1. 硬件加速
  void enableHardwareAcceleration() {
    // 使用 GPU 加速视频解码
    videoPlayer.setRenderMode(RenderMode.hardwareAcceleration);
    
    // 启用 DirectX 渲染
    enableDirectXRendering();
  }
  
  // 2. 多线程处理
  Future<void> loadEpgDataParallel() async {
    // 使用 Isolate 并行加载 EPG
    final results = await Future.wait([
      compute(loadEpgForChannel, channel1),
      compute(loadEpgForChannel, channel2),
      compute(loadEpgForChannel, channel3),
    ]);
    
    mergeEpgResults(results);
  }
  
  // 3. 缓存策略（Windows 存储空间大）
  void configureWindowsCache() {
    // 更大的图片缓存
    PaintingBinding.instance.imageCache.maximumSize = 500;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;  // 200MB
    
    // 缓存更多 EPG 数据（7天）
    epgCacheDays = 7;
    
    // 预加载视频片段
    enableVideoPreloading = true;
  }
  
  // 4. 列表虚拟化（大屏显示更多）
  Widget buildVirtualizedList() {
    return ListView.builder(
      itemCount: programs.length,
      itemExtent: 70.0,
      cacheExtent: 1000.0,  // 预渲染更多
      itemBuilder: (context, index) {
        return WindowsProgramListItem(program: programs[index]);
      },
    );
  }
  
  // 5. 网络优化
  void configureNetworking() {
    // 使用更大的缓冲区
    httpClient.bufferSize = 8 * 1024 * 1024;  // 8MB
    
    // 并发请求数
    httpClient.maxConcurrentRequests = 10;
    
    // 启用 HTTP/2
    httpClient.enableHttp2 = true;
  }
}
```

---

## 6. 平台特定伪代码实现

### 6.1 Catchup URL 构建器（通用）

```dart
class CatchupUrlBuilder {
  
  String buildCatchupUrl({
    required Channel channel,
    required EpgProgram program,
  }) {
    if (!channel.catchupEnabled || channel.catchupSource == null) {
      throw Exception('Catchup not enabled for this channel');
    }
    
    final catchupType = channel.catchupType ?? 'append';
    final catchupSource = channel.catchupSource!;
    final originalUrl = channel.url;
    
    switch (catchupType) {
      case 'append':
        return buildAppendUrl(originalUrl, catchupSource, program);
      case 'default':
        return buildDefaultUrl(catchupSource, program);
      case 'shift':
        return buildShiftUrl(originalUrl, catchupSource, program);
      case 'flussonic':
        return buildFlussonicUrl(originalUrl, catchupSource, program);
      case 'xc':
        return buildXcUrl(originalUrl, catchupSource, program);
      default:
        throw Exception('Unknown catchup type: $catchupType');
    }
  }
  
  String buildAppendUrl(
    String originalUrl,
    String catchupSource,
    EpgProgram program,
  ) {
    // 替换占位符
    final processedSource = replacePlaceholders(catchupSource, program);
    
    // 追加到原始 URL
    final separator = originalUrl.contains('?') ? '&' : '?';
    return originalUrl + separator + processedSource.substring(1);  // 去掉开头的 ?
  }
  
  String buildDefaultUrl(
    String catchupSource,
    EpgProgram program,
  ) {
    // 完全替换 URL
    return replacePlaceholders(catchupSource, program);
  }
  
  String replacePlaceholders(String template, EpgProgram program) {
    String result = template;
    
    // 时间戳占位符
    result = result.replaceAll(
      r'${(b)timestamp}',
      program.startTime.toString(),
    );
    result = result.replaceAll(
      r'${(e)timestamp}',
      program.endTime.toString(),
    );
    
    // 日期时间格式占位符
    final startDateTime = DateTime.fromMillisecondsSinceEpoch(
      program.startTime * 1000,
    );
    final endDateTime = DateTime.fromMillisecondsSinceEpoch(
      program.endTime * 1000,
    );
    
    // yyyyMMddHHmmss 格式
    result = result.replaceAll(
      r'${(b)yyyyMMddHHmmss}',
      formatDateTime(startDateTime, 'yyyyMMddHHmmss'),
    );
    result = result.replaceAll(
      r'${(e)yyyyMMddHHmmss}',
      formatDateTime(endDateTime, 'yyyyMMddHHmmss'),
    );
    
    // UTC 格式
    result = result.replaceAll(
      r'${(b)yyyyMMddHHmmss:utc}',
      formatDateTime(startDateTime.toUtc(), 'yyyyMMddHHmmss'),
    );
    result = result.replaceAll(
      r'${(e)yyyyMMddHHmmss:utc}',
      formatDateTime(endDateTime.toUtc(), 'yyyyMMddHHmmss'),
    );
    
    // 简化 UTC 格式
    result = result.replaceAll(
      '{utc:YmdHMS}',
      formatDateTime(startDateTime.toUtc(), 'yyyyMMddHHmmss'),
    );
    result = result.replaceAll(
      '{utcend:YmdHMS}',
      formatDateTime(endDateTime.toUtc(), 'yyyyMMddHHmmss'),
    );
    
    // 持续时间
    result = result.replaceAll(
      r'${duration}',
      program.duration.toString(),
    );
    
    return result;
  }
  
  String formatDateTime(DateTime dt, String format) {
    if (format == 'yyyyMMddHHmmss') {
      return '${dt.year}'
          '${dt.month.toString().padLeft(2, '0')}'
          '${dt.day.toString().padLeft(2, '0')}'
          '${dt.hour.toString().padLeft(2, '0')}'
          '${dt.minute.toString().padLeft(2, '0')}'
          '${dt.second.toString().padLeft(2, '0')}';
    }
    // 其他格式...
    return dt.toIso8601String();
  }
}
```

