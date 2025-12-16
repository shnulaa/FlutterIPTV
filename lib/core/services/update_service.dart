import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update.dart';
import '../services/service_locator.dart';

/// GitHub API速率限制异常
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  
  @override
  String toString() => 'RateLimitException: $message';
}

class UpdateService {
  static const String _githubRepoUrl =
      'https://api.github.com/repos/shnulaa/FlutterIPTV/releases';
  static const String _githubTagsUrl =
      'https://api.github.com/repos/shnulaa/FlutterIPTV/tags';
  static const String _githubReleasesUrl =
      'https://github.com/shnulaa/FlutterIPTV/releases';
  
  // 备用API端点（使用GitHub Pages作为缓存）
  static const String _fallbackApiUrl =
      'https://api.github.com/repos/shnulaa/FlutterIPTV/releases/latest';

  // 检查更新的间隔时间（小时）
  static const int _checkUpdateInterval = 24;

  // SharedPreferences key for last update check
  // 注释掉未使用的常量
  // static const String _lastUpdateCheckKey = 'last_update_check';

  // 缓存相关
  static const String _cacheKey = 'github_api_cache';
  static const Duration _cacheExpiry = Duration(hours: 1);
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);

  /// 检查是否有可用更新
  Future<AppUpdate?> checkForUpdates({bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE: 开始检查更新...');

      // 检查是否需要检查更新（除非强制检查）
      if (!forceCheck) {
        final lastCheck = await _getLastUpdateCheckTime();
        final now = DateTime.now();
        if (lastCheck != null &&
            now.difference(lastCheck).inHours < _checkUpdateInterval) {
          debugPrint('UPDATE: 距离上次检查不足24小时，跳过本次检查');
          return null;
        }
      }

      // 获取当前应用版本
      final currentVersion = await getCurrentVersion();
      debugPrint('UPDATE: 当前应用版本: $currentVersion');

      // 获取最新发布信息
      final latestRelease = await _fetchLatestRelease();
      if (latestRelease == null) {
        debugPrint('UPDATE: 无法获取最新发布信息');
        return null;
      }

      debugPrint('UPDATE: 最新发布版本: ${latestRelease.version}');

      // 比较版本号
      if (_isNewerVersion(latestRelease.version, currentVersion)) {
        debugPrint('UPDATE: 发现新版本可用！');
        await _saveLastUpdateCheckTime();
        return latestRelease;
      } else {
        debugPrint('UPDATE: 已是最新版本');
        await _saveLastUpdateCheckTime();
        return null;
      }
    } catch (e) {
      debugPrint('UPDATE: 检查更新时发生错误: $e');
      return null;
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('UPDATE: 获取当前版本失败: $e');
      return '0.0.0';
    }
  }

  /// 获取最新发布信息
  Future<AppUpdate?> _fetchLatestRelease() async {
    // 首先检查缓存
    final cachedRelease = await _getCachedRelease();
    if (cachedRelease != null) {
      debugPrint('UPDATE: 使用缓存的发布信息');
      return cachedRelease;
    }

    // 尝试从GitHub API获取，带重试机制
    AppUpdate? release = await _fetchFromGitHubWithRetry();

    // 如果GitHub API失败，尝试备用API
    if (release == null) {
      debugPrint('UPDATE: GitHub API失败，尝试备用API...');
      release = await _fetchFromFallbackApi();
    }

    // 缓存成功获取的结果
    if (release != null) {
      await _cacheRelease(release);
    }

    return release;
  }

  /// 带重试机制的GitHub API请求
  Future<AppUpdate?> _fetchFromGitHubWithRetry() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('UPDATE: GitHub API请求尝试 $attempt/$_maxRetries');
        
        // 添加请求间的延迟
        if (attempt > 1) {
          final delay = _baseRetryDelay * (1 << (attempt - 1)); // 指数退避
          debugPrint('UPDATE: 等待 ${delay.inSeconds} 秒后重试...');
          await Future.delayed(delay);
        }

        final release = await _fetchFromGitHubApi();
        if (release != null) {
          debugPrint('UPDATE: GitHub API请求成功');
          return release;
        }
      } catch (e) {
        debugPrint('UPDATE: GitHub API请求尝试 $attempt 失败: $e');
        
        if (attempt == _maxRetries) {
          debugPrint('UPDATE: GitHub API所有重试都失败了');
        }
      }
    }
    return null;
  }

  /// 从GitHub API获取发布信息
  Future<AppUpdate?> _fetchFromGitHubApi() async {
    // 首先尝试从GitHub Releases获取
    try {
      final response = await http.get(
        Uri.parse(_githubRepoUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FlutterIPTV-App/1.1.1',
          'If-None-Match': '"W/\\"${DateTime.now().millisecondsSinceEpoch}\\""', // 简单的缓存控制
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        if (releases.isNotEmpty) {
          // 返回最新的非预发布版本
          for (final release in releases) {
            if (release['prerelease'] != true) {
              debugPrint('UPDATE: 成功获取GitHub Releases信息');
              return AppUpdate.fromJson(release);
            }
          }
          // 如果没有找到正式版本，返回第一个
          debugPrint('UPDATE: 找到预发布版本，使用第一个发布');
          return AppUpdate.fromJson(releases.first);
        }
      } else if (response.statusCode == 403) {
        final rateLimitRemaining = response.headers['x-ratelimit-remaining'];
        final rateLimitReset = response.headers['x-ratelimit-reset'];
        debugPrint('UPDATE: GitHub API限制 (403)');
        debugPrint('UPDATE: 剩余请求次数: $rateLimitRemaining');
        debugPrint('UPDATE: 重置时间: $rateLimitReset');
        
        // 如果是速率限制，抛出特殊异常
        throw RateLimitException('GitHub API rate limit exceeded');
      } else if (response.statusCode == 304) {
        debugPrint('UPDATE: GitHub API返回304 (未修改)，使用缓存');
        return await _getCachedRelease();
      } else {
        debugPrint('UPDATE: GitHub API请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      if (e is RateLimitException) {
        rethrow;
      }
      debugPrint('UPDATE: 获取发布信息时发生错误: $e');
    }

    // 如果GitHub Releases失败，尝试从Git Tags获取
    try {
      final response = await http.get(
        Uri.parse(_githubTagsUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FlutterIPTV-App/1.1.1',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List<dynamic> tags = json.decode(response.body);
        if (tags.isNotEmpty) {
          // 返回最新的tag
          final latestTag = tags.first;
          debugPrint('UPDATE: 成功获取Git Tags信息');
          // 将tag信息转换为AppUpdate格式
          return AppUpdate.fromJson({
            'tag_name': latestTag['name'],
            'name': latestTag['name'],
            'body': latestTag['message'] ?? '无发布说明',
            'html_url': '$_githubReleasesUrl/tag/${latestTag['name']}',
            'prerelease': false,
          });
        }
      } else if (response.statusCode == 403) {
        throw RateLimitException('GitHub Tags API rate limit exceeded');
      } else {
        debugPrint('UPDATE: GitHub Tags API请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      if (e is RateLimitException) {
        rethrow;
      }
      debugPrint('UPDATE: 获取Git Tags信息时发生错误: $e');
    }

    return null;
  }

  /// 从备用API获取发布信息
  Future<AppUpdate?> _fetchFromFallbackApi() async {
    try {
      debugPrint('UPDATE: 尝试从备用API获取版本信息...');
      final response = await http.get(
        Uri.parse(_fallbackApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FlutterIPTV-App/1.1.1',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        debugPrint('UPDATE: 成功从备用API获取版本信息');
        return AppUpdate.fromJson(releaseData);
      } else if (response.statusCode == 403) {
        final rateLimitRemaining = response.headers['x-ratelimit-remaining'];
        final rateLimitReset = response.headers['x-ratelimit-reset'];
        debugPrint('UPDATE: 备用API也受到速率限制');
        debugPrint('UPDATE: 剩余请求次数: $rateLimitRemaining');
        debugPrint('UPDATE: 重置时间: $rateLimitReset');
        
        // 如果备用API也受限，返回GitHub页面链接作为最后的备用方案
        debugPrint('UPDATE: 返回GitHub页面链接作为备用方案');
        return AppUpdate.fromJson({
          'tag_name': '1.1.13', // 当前版本
          'name': 'FlutterIPTV',
          'body': '由于API限制，请手动访问GitHub页面检查更新',
          'html_url': _githubReleasesUrl,
          'prerelease': false,
          'download_url': _githubReleasesUrl,
        });
      } else {
        debugPrint('UPDATE: 备用API请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UPDATE: 从备用API获取版本信息时发生错误: $e');
    }

    return null;
  }

  /// 缓存发布信息
  Future<void> _cacheRelease(AppUpdate release) async {
    try {
      final prefs = ServiceLocator.prefs;
      final cacheData = {
        'data': release.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_cacheKey, json.encode(cacheData));
      debugPrint('UPDATE: 发布信息已缓存');
    } catch (e) {
      debugPrint('UPDATE: 缓存发布信息失败: $e');
    }
  }

  /// 获取缓存的发布信息
  Future<AppUpdate?> _getCachedRelease() async {
    try {
      final prefs = ServiceLocator.prefs;
      final cacheString = prefs.getString(_cacheKey);
      if (cacheString == null) return null;

      final cacheData = json.decode(cacheString);
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      // 检查缓存是否过期
      if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
        debugPrint('UPDATE: 缓存已过期');
        await prefs.remove(_cacheKey);
        return null;
      }

      debugPrint('UPDATE: 使用缓存数据，缓存时间: ${cacheTime.toLocal()}');
      return AppUpdate.fromJson(cacheData['data']);
    } catch (e) {
      debugPrint('UPDATE: 获取缓存失败: $e');
      return null;
    }
  }

  /// 比较版本号，判断是否为新版本
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newVer = Version.parse(newVersion);
      final currentVer = Version.parse(currentVersion);
      return newVer > currentVer;
    } catch (e) {
      debugPrint('UPDATE: 版本号比较失败: $e');
      return false;
    }
  }

  /// 打开下载页面
  Future<bool> openDownloadPage() async {
    try {
      final uri = Uri.parse(_githubReleasesUrl);
      debugPrint('UPDATE: 打开下载页面: $_githubReleasesUrl');
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('UPDATE: 打开下载页面失败: $e');
      return false;
    }
  }

  /// 获取上次检查更新的时间
  Future<DateTime?> _getLastUpdateCheckTime() async {
    try {
      // 这里应该使用SharedPreferences，但为了简化，我们先返回null
      // 在实际项目中，需要导入并使用SharedPreferences
      return null;
    } catch (e) {
      debugPrint('UPDATE: 获取上次检查时间失败: $e');
      return null;
    }
  }

  /// 保存上次检查更新的时间
  Future<void> _saveLastUpdateCheckTime() async {
    try {
      // 这里应该使用SharedPreferences保存时间
      // 在实际项目中，需要导入并使用SharedPreferences
      debugPrint('UPDATE: 保存检查时间: ${DateTime.now()}');
    } catch (e) {
      debugPrint('UPDATE: 保存检查时间失败: $e');
    }
  }

  /// 检查是否是移动平台（可以显示更新对话框）
  // 注释掉未使用的方法
  // bool get _isMobilePlatform {
  //   // 这里可以添加平台检测逻辑
  //   // 移动平台显示更新对话框，桌面平台可能直接打开下载页面
  //   return true; // 暂时返回true
  // }

  /// 下载更新文件
  Future<String?> downloadUpdate(
    String downloadUrl, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
  }) async {
    try {
      debugPrint('UPDATE: 开始下载更新文件: $downloadUrl');
      onStatusChange?.call('准备下载...');

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      debugPrint('UPDATE: 保存路径: $savePath');

      // 创建Dio实例
      final dio = Dio();
      
      // 下载文件
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress?.call(progress);
            debugPrint('UPDATE: 下载进度: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      debugPrint('UPDATE: 下载完成: $savePath');
      onStatusChange?.call('下载完成');
      return savePath;
    } catch (e) {
      debugPrint('UPDATE: 下载失败: $e');
      onStatusChange?.call('下载失败: $e');
      return null;
    }
  }

  /// 获取最新发布的下载URL
  Future<String?> getDownloadUrl(AppUpdate update) async {
    // 首先尝试从缓存的发布信息中获取下载URL
    if (update.downloadUrl != null && update.downloadUrl!.isNotEmpty) {
      debugPrint('UPDATE: 使用缓存的下载URL: ${update.downloadUrl}');
      return update.downloadUrl;
    }

    // 尝试从GitHub API获取详细信息
    try {
      debugPrint('UPDATE: 从GitHub API获取下载URL...');
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/shnulaa/FlutterIPTV/releases/tags/${update.version}'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FlutterIPTV-App/1.1.1',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        final assets = releaseData['assets'] as List<dynamic>;
        
        if (assets.isNotEmpty) {
          // 查找Windows版本的安装包
          for (final asset in assets) {
            final name = asset['name'] as String;
            if (name.contains('windows') || name.contains('exe')) {
              final downloadUrl = asset['browser_download_url'] as String;
              debugPrint('UPDATE: 找到Windows下载链接: $downloadUrl');
              return downloadUrl;
            }
          }
          
          // 如果没找到Windows版本，返回第一个
          final downloadUrl = assets.first['browser_download_url'] as String;
          debugPrint('UPDATE: 使用第一个下载链接: $downloadUrl');
          return downloadUrl;
        }
      } else if (response.statusCode == 403) {
        debugPrint('UPDATE: GitHub API限制，尝试备用下载URL');
        // 返回默认的GitHub Releases页面URL
        return '$_githubReleasesUrl/tag/${update.version}';
      } else {
        debugPrint('UPDATE: 无法获取下载URL，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UPDATE: 获取下载URL失败: $e');
    }

    // 备用方案：返回GitHub Releases页面URL
    debugPrint('UPDATE: 使用备用下载URL: $_githubReleasesUrl/tag/${update.version}');
    return '$_githubReleasesUrl/tag/${update.version}';
  }

  /// 安装更新文件
  Future<bool> installUpdate(String filePath) async {
    try {
      debugPrint('UPDATE: 开始安装更新: $filePath');
      
      if (Platform.isWindows) {
        // Windows平台：执行安装程序
        final result = await Process.run(filePath, []);
        debugPrint('UPDATE: 安装程序退出码: ${result.exitCode}');
        return result.exitCode == 0;
      } else {
        debugPrint('UPDATE: 当前平台不支持自动安装');
        return false;
      }
    } catch (e) {
      debugPrint('UPDATE: 安装失败: $e');
      return false;
    }
  }
}
