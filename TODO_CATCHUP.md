# IPTV回放功能实现清单

## Phase 1: 数据层

- [x] 1.1 修改 `lib/core/models/channel.dart`
  - [x] 添加 `supportsCatchUp` 字段 (bool)
  - [x] 添加 `catchUpSource` 字段 (String?)
  - [x] 添加 `catchUpType` 字段 (String?)
  - [x] 添加 `catchUpDays` 字段 (int, 默认7)
  - [x] 更新 `copyWith` 方法

- [x] 1.2 修改 `lib/core/utils/m3u_parser.dart`
  - [x] 在 `_parseExtInf()` 方法中解析 `catchup` 属性
  - [x] 解析 `catchup-source` 属性
  - [x] 解析 `catchup-type` 属性
  - [x] 传递到Channel构造函数

- [x] 1.3 新建 `lib/core/services/catchup_service.dart`
  - [x] 实现 `buildCatchUpUrl()` 方法
  - [x] 支持 `${utc:yyyyMMddHHmmss}` 变量替换
  - [x] 支持 `${utcend:yyyyMMddHHmmss}` 变量替换
  - [x] 支持UTC和本地时间转换
  - [x] 实现 `validateCatchUpUrl()` 方法

- [x] 1.4 修改 `lib/core/database/database_helper.dart`
  - [x] 添加数据库迁移脚本
  - [x] 添加 `catchup_source` 列
  - [x] 添加 `catchup_type` 列
  - [x] 添加 `catchup_days` 列

## Phase 2: 业务层

- [x] 2.1 新建 `lib/core/models/catchup_models.dart`
  - [x] 定义 `CatchUpProgram` 模型
  - [x] 定义 `CatchUpTimeRange` 模型
  - [x] 定义 `CatchUpState` 模型
  - [x] 定义 `CatchUpConfig` 模型

- [x] 2.2 新建 `lib/features/catchup/providers/catchup_provider.dart`
  - [x] 实现 `isInCatchUpMode` 状态
  - [x] 实现 `currentProgram` 状态
  - [x] 实现 `catchUpStartTime` 状态
  - [x] 实现 `catchUpEndTime` 状态
  - [x] 实现 `enterCatchUpMode()` 方法
  - [x] 实现 `exitCatchUpMode()` 方法
  - [x] 实现 `seekTo()` 方法
  - [x] 实现 `getProgress()` 方法
  - [x] 实现DLNA位置转换方法

- [x] 2.3 修改 `lib/features/player/providers/player_provider.dart`
  - [x] 添加 `_isInCatchUpMode` 状态
  - [x] 添加 `_catchUpStartTime` 状态
  - [x] 添加 `setCatchUpMode()` 方法
  - [x] 添加 `handleDlnaSeek()` 方法（带位置转换）
  - [x] 添加 `_getDlnaSyncPosition()` 方法
  - [x] 添加 `playCatchUp()` 方法
  - [x] 添加 `switchToLive()` 方法
  - [x] 添加 `seekForward()` 方法
  - [x] 添加 `seekBackward()` 方法

## Phase 3: UI层

- [x] 3.1 新建 `lib/features/catchup/screens/catchup_time_picker.dart`
  - [x] 实现日期选择（7天范围）
  - [x] 实现时间轴选择
  - [x] 实现节目标题显示
  - [x] 实现确认/取消按钮
  - [x] 支持键盘导航

- [x] 3.2 新建 `lib/features/catchup/widgets/catchup_time_bar.dart`
  - [x] 渲染时间轴
  - [x] 显示已播放/未播放区域
  - [x] 显示当前位置标记
  - [x] 支持鼠标拖动
  - [x] 支持键盘导航
  - [x] 支持悬停预览时间

- [x] 3.3 修改 `lib/features/epg/screens/epg_screen.dart`
  - [x] 添加回放入口（演示占位符）
  - [ ] 过往节目显示"[回看]"按钮
  - [ ] 支持回看的节目高亮显示
  - [ ] 点击回看按钮打开时间选择器
  - [ ] 支持键盘C键快捷键

- [ ] 3.4 修改 `lib/features/player/screens/player_screen.dart`
  - [ ] 回放模式标识（顶部栏"[回放]"）
  - [ ] 时间轴控件集成
  - [ ] 回放控制栏（返回直播、快退、快进）
  - [ ] 键盘快捷键（←→跳转、↑↓快退进、B返回直播）
  - [ ] 鼠标操作支持
  - [ ] 控制栏自动隐藏

## Phase 4: 国际化

- [x] 4.1 修改 `lib/core/i18n/app_strings.dart`
  - [x] 添加 `catchUp` / `回放`
  - [x] 添加 `catchUpMode` / `回放模式`
  - [x] 添加 `returnToLive` / `返回直播`
  - [x] 添加 `selectCatchUpTime` / `选择回看时间`
  - [x] 添加 `noCatchUpSupport` / `该频道不支持回放`
  - [x] 添加 `rewindSeconds` / `快退 {seconds} 秒`
  - [x] 添加 `forwardSeconds` / `快进 {seconds} 秒`
  - [x] 添加 `catchUpProgress` / `{current}/{total}`
  - [x] 添加 `selectDate` / `选择日期`

## Phase 5: 测试与验证

- [ ] 5.1 功能测试
  - [ ] M3U解析catchup属性
  - [ ] 回放URL构建
  - [ ] 时间选择器交互
  - [ ] 回放播放
  - [ ] 快退/快进
  - [ ] 返回直播
  - [ ] 键盘操作
  - [ ] 鼠标操作

- [ ] 5.2 DLNA兼容性测试
  - [ ] 直播模式下DLNA控制正常
  - [ ] 回放模式下DLNA控制正常
  - [ ] DLNA Seek映射正确
  - [ ] 位置同步正确

- [ ] 5.3 边界情况测试
  - [ ] EPG未加载时回放入口处理
  - [ ] 回放URL无效时错误提示
  - [ ] 回放流播放失败重试
  - [ ] 切换回直播状态同步

## DLNA兼容性（零修改）

以下位置完成DLNA兼容：

- [x] `player_provider.dart` - 在`handleDlnaSeek()`中实现位置转换
  - 回放模式：绝对位置 → 相对位置
  - 直播模式：直接使用绝对位置
- [x] `player_provider.dart` - 在`_getDlnaSyncPosition()`中实现位置转换
  - 回放模式：返回相对位置
  - 直播模式：返回绝对位置

**注意**：DLNA相关代码 `dlna_service.dart` 和 `dlna_provider.dart` **无需修改**

## 依赖关系

```
Phase 1 (数据层)
    │
    ▼
Phase 2 (业务层)
    │
    ▼
Phase 3 (UI层) ←──┬── 依赖 Phase 1 和 Phase 2
    │             │
    ▼             │
Phase 4 (国际化)  │
    │             │
    ▼             │
Phase 5 (测试) ───┘
```

## 预估工作量

| Phase | 任务数 | 预估时间 |
|-------|-------|---------|
| Phase 1 | 4项 | 2小时 |
| Phase 2 | 3项 | 2.5小时 |
| Phase 3 | 4项 | 4小时 |
| Phase 4 | 1项 | 0.5小时 |
| Phase 5 | 3项 | 1小时 |
| **总计** | **15项** | **约10小时** |

## 不修改的文件

以下文件保持不变，不影响现有功能：

- `lib/core/services/dlna_service.dart`
- `lib/features/settings/providers/dlna_provider.dart`
- 其他未列出的文件
