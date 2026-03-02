# M3U Catchup（回看）功能设计文档

## 1. 功能概述

Catchup 功能允许用户回看过去播出的电视节目内容，是现代 IPTV 应用的重要功能之一。

### 1.1 核心价值
- 用户可以观看错过的节目
- 提升用户体验和应用竞争力
- 支持时移播放（Time-shift）

### 1.2 适用场景
- 观看过去 7 天内的节目
- 暂停直播并从任意时间点继续观看
- 快进/快退历史内容

## 2. M3U Catchup 标准

### 2.1 M3U 扩展属性

M3U 文件中需要包含以下 catchup 相关属性：

#### 全局配置（针对整个 M3U 文件）

```
#EXTM3U catchup="append" catchup-source="?playbackbegin=${(b)yyyyMMddHHmmss}&playbackend=${(e)yyyyMMddHHmmss}"
#EXTINF:-1 tvg-id="channel1",CCTV1
http://hostname:port/xxx
#EXTINF:-1 tvg-id="channel2",CCTV2
http://hostname:port/yyy
```

全局配置会应用到所有频道，除非单个频道有自己的配置。

#### 单个频道配置（覆盖全局配置）

**方式 1：使用 append 模式（追加参数到原始 URL）**
```
#EXTINF:-1 catchup="append" catchup-source="?playseek=${(b)yyyyMMddHHmmss}-${(e)yyyyMMddHHmmss}",CCTV1
http://hostname:port/xxx
```

**方式 2：使用 default 模式（完全替换 URL）**
```
#EXTINF:-1 catchup="default" catchup-source="http://hostname:port/xxx2?playseek=${(b)yyyyMMddHHmmss}-${(e)yyyyMMddHHmmss}",CCTV1
http://hostname:port/xxx
```

**关键属性说明：**

- `catchup`: 回看类型（append/default/shift/flussonic/xc/vod）
- `catchup-days`: 可回看的天数（通常 1-7 天）
- `catchup-source`: 回看源 URL 模板，包含时间占位符

### 2.2 Catchup 类型详解

#### append 模式
将时间参数追加到原始 URL 后面
```
原始: http://example.com/stream.m3u8
回看: http://example.com/stream.m3u8?utc=1234567890&lutc=1234567900
```

#### default 模式
使用 catchup-source 完全替换原始 URL

#### shift 模式
时移模式，支持从当前时间往前回看


#### flussonic 模式
专门用于 Flussonic 媒体服务器

#### xc 模式
用于 Xtream Codes API

### 2.3 时间占位符详解

Catchup 功能支持多种时间格式的占位符，用于在 URL 中动态插入时间参数。

#### 标准日期时间格式

**格式 1：使用 ${(b)} 和 ${(e)} 占位符**
```
#EXTINF:-1 catchup="append" catchup-source="?playseek=${(b)yyyyMMddHHmmss}-${(e)yyyyMMddHHmmss}",CCTV1
http://hostname:port/xxx
```
- `${(b)yyyyMMddHHmmss}`: 开始时间，格式如 20260228143000
- `${(e)yyyyMMddHHmmss}`: 结束时间，格式如 20260228153000

**格式 2：使用 {utc} 占位符（UTC 时间）**
```
#EXTINF:-1 catchup="append" catchup-source="?playseek=${(b)yyyyMMddHHmmss:utc}-${(e)yyyyMMddHHmmss:utc}",CCTV1
http://hostname:port/xxx
```
添加 `:utc` 后缀表示使用 UTC 时间而非本地时间

**格式 3：简化的 UTC 格式**
```
#EXTINF:-1 catchup="append" catchup-source="?playseek={utc:YmdHMS}-{utcend:YmdHMS}",CCTV1
http://hostname:port/xxx
```
- `{utc:YmdHMS}`: 开始时间的 UTC 格式
- `{utcend:YmdHMS}`: 结束时间的 UTC 格式

#### Unix 时间戳格式

```
#EXTM3U catchup="append" catchup-source="?starttime=${(b)timestamp}&endtime=${(e)timestamp}"
#EXTINF:-1,CCTV1
http://hostname:port/xxx
```
- `${(b)timestamp}`: 开始时间的 Unix 时间戳（秒）
- `${(e)timestamp}`: 结束时间的 Unix 时间戳（秒）

#### 常用占位符列表

| 占位符 | 说明 | 示例值 |
|--------|------|--------|
| `${(b)yyyyMMddHHmmss}` | 开始时间（本地） | 20260228143000 |
| `${(e)yyyyMMddHHmmss}` | 结束时间（本地） | 20260228153000 |
| `${(b)yyyyMMddHHmmss:utc}` | 开始时间（UTC） | 20260228063000 |
| `${(e)yyyyMMddHHmmss:utc}` | 结束时间（UTC） | 20260228073000 |
| `${(b)timestamp}` | 开始时间戳 | 1709118600 |
| `${(e)timestamp}` | 结束时间戳 | 1709122200 |
| `{utc:YmdHMS}` | UTC 开始时间 | 20260228063000 |
| `{utcend:YmdHMS}` | UTC 结束时间 | 20260228073000 |
| `${(b)yyyy-MM-dd}` | 开始日期 | 2026-02-28 |
| `${duration}` | 持续时间（秒） | 3600 |
| `${offset}` | 时间偏移量 | -3600 |

### 2.4 完整配置示例

#### 示例 1：全局配置 + 单个频道覆盖

```m3u
#EXTM3U catchup="append" catchup-days="7" catchup-source="?playbackbegin=${(b)yyyyMMddHHmmss}&playbackend=${(e)yyyyMMddHHmmss}"

#EXTINF:-1 tvg-id="cctv1",CCTV1 综合
http://server.com/cctv1.m3u8

#EXTINF:-1 tvg-id="cctv2" catchup="default" catchup-source="http://archive.com/cctv2?start=${(b)timestamp}&end=${(e)timestamp}",CCTV2 财经
http://server.com/cctv2.m3u8

#EXTINF:-1 tvg-id="cctv3" catchup="disabled",CCTV3 综艺
http://server.com/cctv3.m3u8
```

**说明：**
- CCTV1：使用全局 append 配置
- CCTV2：使用自己的 default 配置（覆盖全局）
- CCTV3：禁用回看功能

#### 示例 2：不同时间格式

```m3u
#EXTM3U catchup="append" catchup-days="3"

#EXTINF:-1 catchup-source="?utc=${(b)yyyyMMddHHmmss:utc}&utcend=${(e)yyyyMMddHHmmss:utc}",频道A（UTC格式）
http://server.com/channelA.m3u8

#EXTINF:-1 catchup-source="?start={utc:YmdHMS}&end={utcend:YmdHMS}",频道B（简化UTC）
http://server.com/channelB.m3u8

#EXTINF:-1 catchup-source="?starttime=${(b)timestamp}&endtime=${(e)timestamp}",频道C（时间戳）
http://server.com/channelC.m3u8
```

#### 示例 3：Flussonic 和 Xtream Codes

```m3u
#EXTM3U

#EXTINF:-1 catchup="flussonic" catchup-source="?utc=${(b)timestamp}&lutc=${(e)timestamp}",Flussonic频道
http://flussonic.server.com/stream/index.m3u8

#EXTINF:-1 catchup="xc" catchup-source="&start=${(b)timestamp}&end=${(e)timestamp}",XC频道
http://xc.server.com:8080/live/username/password/12345.m3u8
```

## 3. 系统架构设计

### 3.1 模块划分

```
catchup/
├── models/
│   ├── catchup_config.dart          # Catchup 配置模型
│   ├── catchup_program.dart         # 节目单模型
│   └── catchup_time_range.dart      # 时间范围模型
├── services/
│   ├── catchup_parser_service.dart  # M3U Catchup 解析服务
│   ├── catchup_url_builder.dart     # URL 构建服务
│   └── epg_service.dart             # EPG 节目单服务
├── providers/
│   └── catchup_provider.dart        # Catchup 状态管理
└── widgets/
    ├── catchup_timeline.dart        # 时间轴组件
    ├── program_list.dart            # 节目列表
    └── catchup_player_controls.dart # 播放控制
```


### 3.2 数据流程

```
用户选择频道 
  → 检查是否支持 Catchup
    → 加载 EPG 节目单数据
      → 显示时间轴和节目列表
        → 用户选择历史节目
          → 构建 Catchup URL
            → 播放历史内容
```

## 4. 核心功能模块

### 4.1 M3U 解析增强

**需要扩展现有的 M3U 解析器：**

- 识别并提取 catchup 相关属性（全局和单个频道）
- 验证 catchup 配置的有效性
- 存储 catchup 配置到频道模型中
- 处理配置优先级（单个频道配置覆盖全局配置）

**解析流程：**

1. **解析全局配置**
   - 读取 #EXTM3U 行
   - 提取 catchup、catchup-source、catchup-days 等属性
   - 保存为默认配置

2. **解析单个频道**
   - 读取 #EXTINF 行
   - 提取频道特定的 catchup 属性
   - 如果存在，覆盖全局配置
   - 如果不存在，使用全局配置

3. **配置优先级**
   ```
   单个频道配置 > 全局配置 > 默认值
   ```

**数据模型扩展：**

```dart
class Channel {
  String id;
  String name;
  String url;
  String? tvgId;
  
  // Catchup 配置
  CatchupConfig? catchupConfig;
}

class CatchupConfig {
  String type;              // append, default, shift, etc.
  String? source;           // catchup-source 模板
  int? days;                // 可回看天数
  bool enabled;             // 是否启用
  bool isGlobal;            // 是否来自全局配置
}
```

**正则表达式示例：**

```dart
// 全局配置
final globalCatchupRegex = RegExp(r'#EXTM3U.*catchup="([^"]+)"');
final globalSourceRegex = RegExp(r'catchup-source="([^"]+)"');

// 单个频道配置
final channelCatchupRegex = RegExp(r'catchup="([^"]+)"');
final channelSourceRegex = RegExp(r'catchup-source="([^"]+)"');
final catchupDaysRegex = RegExp(r'catchup-days="(\d+)"');
```

### 4.2 EPG（电子节目单）集成

**EPG 数据来源：**
- XMLTV 格式的 EPG 文件
- 在线 EPG API 服务
- M3U 文件中的 tvg-id 关联


**EPG 功能需求：**
- 解析 XMLTV 格式
- 根据 tvg-id 匹配频道和节目
- 缓存节目单数据（本地数据库）
- 定期更新 EPG 数据
- 显示节目名称、时间、描述

### 4.3 Catchup URL 构建器

**核心职责：**
- 根据 catchup 类型生成正确的 URL
- 替换时间占位符为实际时间戳
- 处理不同服务器的 URL 格式差异

**时间计算：**
- 将用户选择的节目时间转换为 UTC 时间戳
- 计算节目的开始和结束时间
- 处理时区转换

### 4.4 播放器集成

**播放器需要支持：**
- 播放 Catchup URL 生成的流
- 显示当前播放的历史时间点
- 支持进度条拖动（如果流支持）
- 区分直播和回看模式


## 5. 用户界面设计

### 5.1 频道详情页增强

**新增元素：**
- Catchup 可用标识（图标或文字）
- "回看" 按钮入口
- 当前正在播放的节目信息

### 5.2 Catchup 时间轴界面

**主要组件：**
- 水平滚动的时间轴
- 当前时间指示器
- 节目块（按时间段显示）
- 日期选择器（切换不同日期）

**交互设计：**
- 点击节目块开始播放
- 拖动时间轴快速浏览
- 显示节目详情（标题、时间、描述）

### 5.3 播放器控制增强

**回看模式特有控制：**
- 显示历史播放时间
- "返回直播" 按钮
- 节目信息叠加层
- 快进/快退按钮（如支持）

## 5.4 播放页面交互详细设计

### 5.4.1 播放页面布局

```
┌─────────────────────────────────────────┐
│  [返回] CCTV1          [设置] [收藏]    │  ← 顶部工具栏
├─────────────────────────────────────────┤
│                                         │
│                                         │
│          视频播放区域                    │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│  🔴 直播中 | 📺 回看                     │  ← 模式切换标签
├─────────────────────────────────────────┤
│  [节目信息叠加层]                        │
│  新闻联播                                │
│  19:00 - 19:30 (30分钟)                 │
│  今日要闻...                             │
├─────────────────────────────────────────┤
│  ◀ 2月27日 | 2月28日 | 2月29日 ▶        │  ← 日期选择器
├─────────────────────────────────────────┤
│  [时间轴滚动区域]                        │
│  06:00  09:00  12:00  15:00  18:00     │
│  ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤      │
│  │早间│  │午间│  │  │新闻│  │  │       │
│  │新闻│  │新闻│  │  │联播│  │  │       │
│         ▲ 当前时间指示器                 │
├─────────────────────────────────────────┤
│  [节目列表]                              │
│  ✓ 19:00-19:30 新闻联播 (正在播放)      │
│    18:00-19:00 综合新闻                 │
│    17:00-18:00 今日说法                 │
│    ...                                  │
└─────────────────────────────────────────┘
```

### 5.4.2 交互流程

#### 进入回看模式
1. 用户在播放直播时，点击 "📺 回看" 标签
2. 系统检查频道是否支持 Catchup
3. 加载 EPG 数据和时间轴
4. 显示最近 7 天的节目列表
5. 默认定位到当前时间

#### 选择历史节目
**方式 1：通过时间轴**
1. 用户在时间轴上左右滑动
2. 点击某个节目块
3. 显示节目详情弹窗（标题、时间、描述、海报）
4. 点击 "播放" 按钮开始回看

**方式 2：通过节目列表**
1. 用户在节目列表中滚动
2. 点击某个节目项
3. 直接开始播放该节目

**方式 3：通过日期选择**
1. 点击日期选择器的左右箭头
2. 或点击日期打开日历选择器
3. 选择具体日期后，时间轴和列表更新

#### 播放控制交互
**基础控制：**
- 播放/暂停：点击视频中央或底部按钮
- 音量调节：侧边音量条或音量键
- 全屏切换：双击视频或全屏按钮

**回看特有控制：**
- 进度条拖动：拖动到节目内的任意时间点
- 快进 10 秒：双击视频右侧或快进按钮
- 快退 10 秒：双击视频左侧或快退按钮
- 返回直播：点击 "🔴 返回直播" 按钮

#### 节目切换
**自动切换：**
- 当前节目播放结束后，自动播放下一个节目
- 显示 "即将播放下一个节目" 提示（5 秒倒计时）
- 用户可以取消自动播放

**手动切换：**
- 上一个节目：遥控器左键或屏幕左滑
- 下一个节目：遥控器右键或屏幕右滑
- 在节目列表中直接选择

### 5.4.3 视觉反馈

**加载状态：**
- 显示加载动画和进度提示
- "正在加载节目单..."
- "正在构建回看链接..."
- "正在缓冲视频..."

**播放状态指示：**
- 直播模式：红色 "🔴 直播" 标识
- 回看模式：蓝色 "📺 回看" 标识 + 历史时间
- 暂停状态：大号暂停图标叠加

**时间轴状态：**
- 已播放部分：深色填充
- 当前节目：高亮边框
- 可回看范围：正常显示
- 不可回看：灰色禁用

**错误提示：**
- "该节目暂不支持回看"
- "回看链接已过期"
- "网络连接失败，请重试"

### 5.4.4 手势和快捷键

**触摸手势（移动端/平板）：**
- 单击：显示/隐藏控制栏
- 双击：播放/暂停
- 左右滑动：快退/快进 10 秒
- 上下滑动（左侧）：调节亮度
- 上下滑动（右侧）：调节音量
- 双指缩放：调整画面比例

**遥控器操作（TV 端）：**
- OK 键：播放/暂停
- 返回键：退出播放或返回直播
- 左右键：快退/快进或切换节目
- 上下键：调节音量或浏览节目列表
- 菜单键：打开设置菜单

**键盘快捷键（桌面端）：**
- 空格：播放/暂停
- ←/→：快退/快进 10 秒
- ↑/↓：音量增减
- F：全屏切换
- Esc：退出全屏
- L：返回直播
- M：静音切换

### 5.4.5 上下文菜单

长按节目项或右键点击显示菜单：
- 播放
- 添加到收藏
- 分享节目
- 查看详情
- 设置提醒（未来节目）

### 5.4.6 智能功能

**记忆播放位置：**
- 记录用户上次观看的位置
- 再次打开时提示 "继续播放" 或 "从头播放"

**推荐相关节目：**
- 根据观看历史推荐类似节目
- 显示同时段其他频道的节目

**快速跳转：**
- 跳到节目开始
- 跳到节目结束前 30 秒
- 跳过片头/片尾（如果有标记）


## 6. 数据存储设计

### 6.1 数据库表结构

**catchup_configs 表：**
- channel_id (外键)
- catchup_type (enum)
- catchup_days (int)
- catchup_source (text)
- enabled (boolean)

**epg_programs 表：**
- id (主键)
- channel_id (外键)
- tvg_id (text)
- title (text)
- description (text)
- start_time (datetime)
- end_time (datetime)
- category (text)

**catchup_history 表（用户观看历史）：**
- id (主键)
- channel_id (外键)
- program_id (外键)
- watched_at (datetime)
- duration (int)

### 6.2 缓存策略

- EPG 数据缓存 24 小时
- 节目列表按频道分页加载
- 图片资源本地缓存


## 7. 技术实现要点

### 7.1 M3U 解析增强

**解析流程：**
1. 读取 M3U 文件每一行
2. 识别 #EXTINF 标签
3. 使用正则表达式提取 catchup 属性
4. 验证属性值的合法性
5. 创建 CatchupConfig 对象

**正则表达式示例：**
- `catchup="([^"]+)"`
- `catchup-days="(\d+)"`
- `catchup-source="([^"]+)"`

### 7.2 时间处理

**关键点：**
- 使用 DateTime 类处理时间
- UTC 和本地时区转换
- 时间戳格式化（Unix timestamp）
- 处理夏令时问题

**时间戳生成：**
```
开始时间戳 = 节目开始时间.toUtc().millisecondsSinceEpoch / 1000
结束时间戳 = 节目结束时间.toUtc().millisecondsSinceEpoch / 1000
```


### 7.3 URL 构建算法

**Append 模式示例：**
```
原始 URL: http://server.com/stream.m3u8
Catchup Source: ?utc={utc}&lutc={lutc}

步骤：
1. 获取节目开始时间和结束时间
2. 转换为 UTC 时间戳
3. 替换占位符
4. 拼接到原始 URL

结果: http://server.com/stream.m3u8?utc=1234567890&lutc=1234567900
```

**Default 模式示例：**
```
Catchup Source: http://archive.com/{utc}/{duration}/stream.m3u8

步骤：
1. 计算 duration = 结束时间 - 开始时间
2. 替换所有占位符
3. 使用新 URL 替换原始 URL

结果: http://archive.com/1234567890/3600/stream.m3u8
```

### 7.4 EPG 数据处理

**XMLTV 解析：**
- 使用 XML 解析库（xml 包）
- 提取 programme 节点
- 匹配 channel 属性和 tvg-id


**数据同步：**
- 后台定期下载 EPG 文件
- 增量更新数据库
- 清理过期节目数据

## 8. 性能优化

### 8.1 加载优化

- 懒加载节目列表（按需加载）
- 虚拟滚动（长列表优化）
- 图片懒加载和缩略图
- EPG 数据分批加载

### 8.2 内存优化

- 限制内存中的节目数量
- 及时释放不用的资源
- 使用对象池复用

### 8.3 网络优化

- EPG 数据压缩传输
- 使用 CDN 加速
- 断点续传支持
- 请求合并和去重


## 9. 错误处理

### 9.1 常见错误场景

**M3U 解析错误：**
- Catchup 属性格式错误
- 缺少必需属性
- 不支持的 catchup 类型

**EPG 数据错误：**
- EPG 文件下载失败
- XML 格式错误
- tvg-id 匹配失败

**播放错误：**
- Catchup URL 无效
- 流不可用（已过期）
- 网络连接问题

### 9.2 错误处理策略

- 显示友好的错误提示
- 提供重试机制
- 降级到直播模式
- 记录错误日志便于调试


## 10. 测试策略

### 10.1 单元测试

- M3U 解析器测试（各种 catchup 类型）
- URL 构建器测试（时间戳计算）
- EPG 解析器测试
- 时间转换函数测试

### 10.2 集成测试

- 完整的 Catchup 流程测试
- 不同服务器兼容性测试
- EPG 数据同步测试
- 播放器集成测试

### 10.3 用户测试

- UI/UX 可用性测试
- 不同设备兼容性测试
- 性能压力测试
- 真实场景测试

## 11. 实施计划

### 阶段一：基础架构（1-2 周）
- 扩展数据模型
- M3U 解析器增强
- 数据库表设计和创建

### 阶段二：核心功能（2-3 周）
- EPG 服务实现
- Catchup URL 构建器
- 基础 UI 组件


### 阶段三：播放器集成（1-2 周）
- 播放器适配
- 播放控制增强
- 直播/回看模式切换

### 阶段四：UI 完善（1-2 周）
- 时间轴组件
- 节目列表界面
- 交互优化

### 阶段五：测试和优化（1-2 周）
- 功能测试
- 性能优化
- Bug 修复
- 文档完善

## 12. 依赖和资源

### 12.1 第三方库

**推荐使用：**
- `xml`: XMLTV 解析
- `intl`: 时间格式化和国际化
- `sqflite`: 本地数据库
- `http`: 网络请求
- `cached_network_image`: 图片缓存

### 12.2 外部资源

- EPG 数据源（XMLTV 格式）
- 测试用 M3U 文件（包含 catchup 配置）
- 测试流服务器


## 13. 配置和设置

### 13.1 用户设置

**可配置项：**
- 启用/禁用 Catchup 功能
- 默认回看天数
- EPG 更新频率
- 自动下载 EPG
- 缓存大小限制

### 13.2 开发者配置

**配置文件：**
- EPG 数据源 URL
- Catchup 类型支持列表
- 时间格式配置
- 调试模式开关

## 14. 安全和隐私

### 14.1 数据安全

- 敏感 URL 参数加密存储
- HTTPS 传输
- 防止 URL 注入攻击

### 14.2 隐私保护

- 观看历史本地存储
- 用户可清除历史记录
- 不上传用户观看数据


## 15. 兼容性考虑

### 15.1 平台兼容性

- Android TV 遥控器支持
- iOS 手势操作
- Web 浏览器兼容
- 桌面应用适配

### 15.2 服务器兼容性

**需要支持的主流服务器：**
- Flussonic Media Server
- Xtream Codes
- Stalker Portal
- 标准 HLS/DASH 服务器

### 15.3 向后兼容

- 不支持 Catchup 的频道正常播放
- 旧版 M3U 文件兼容
- 渐进式功能增强

## 16. 监控和分析

### 16.1 功能使用统计

- Catchup 功能使用率
- 最受欢迎的回看节目
- 平均回看时长
- 错误率统计

### 16.2 性能监控

- EPG 加载时间
- URL 构建耗时
- 播放启动时间
- 内存使用情况


## 17. 未来扩展

### 17.1 高级功能

- 节目录制功能
- 节目提醒和预约
- 个性化推荐
- 多语言字幕支持
- 节目搜索功能

### 17.2 技术优化

- P2P 加速
- AI 节目推荐
- 智能预加载
- 离线下载

## 18. 参考资料

### 18.1 标准和规范

- M3U/M3U8 格式规范
- XMLTV EPG 格式标准
- HLS 协议规范
- MPEG-DASH 标准

### 18.2 相关项目

- Kodi PVR 插件
- TiviMate IPTV Player
- Perfect Player
- IPTV Smarters

---

**文档版本：** 1.0  
**创建日期：** 2026-02-28  
**最后更新：** 2026-02-28  
**作者：** Kiro AI Assistant
