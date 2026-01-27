import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_update.dart';
import 'service_locator.dart';

class UpdateService {
  // 使用 GitHub Pages 静态文件，无请求次数限制
  // static const String _versionJsonUrl = 'https://shnulaa.github.io/FlutterIPTV/version.json';
  // static const String _githubReleasesUrl = 'https://github.com/shnulaa/FlutterIPTV/releases';

  static const String _versionJsonUrl = 'https://hk.gh-proxy.org/https://raw.githubusercontent.com/shnulaa/FlutterIPTV/main/docs/version.json';
  static const String _githubReleasesUrl = 'https://github.com/shnulaa/FlutterIPTV/releases';

  // 检查更新的间隔时间（小时）
  static const int _checkUpdateInterval = 24;
  static const String _lastUpdateCheckKey = 'last_update_check';

  /// 检查是否有可用更新
  Future<AppUpdate?> checkForUpdates({bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE: 开始检查更新...');

      // 检查是否需要检查更新（除非强制检查）
      if (!forceCheck) {
        final lastCheck = await _getLastUpdateCheckTime();
        final now = DateTime.now();
        if (lastCheck != null && now.difference(lastCheck).inHours < _checkUpdateInterval) {
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

  /// 从 GitHub Pages 获取最新发布信息
  Future<AppUpdate?> _fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_versionJsonUrl),
        headers: {
          'User-Agent': 'FlutterIPTV-App',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // 使用异步方法获取正确的下载链接
        return await AppUpdate.fromVersionJsonAsync(data);
      } else {
        debugPrint('UPDATE: 获取版本信息失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UPDATE: 获取发布信息时发生错误: $e');
    }
    return null;
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

  /// 下载更新文件
  Future<File?> downloadUpdate(AppUpdate update, {Function(double)? onProgress}) async {
    try {
      final downloadUrl = update.downloadUrl;
      if (downloadUrl.isEmpty) {
        debugPrint('UPDATE: 下载链接为空');
        return null;
      }

      debugPrint('UPDATE: 开始下载: $downloadUrl');

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      
      // 从 URL 中提取文件名
      String fileName;
      final uri = Uri.parse(downloadUrl);
      final urlFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (urlFileName.isNotEmpty) {
        fileName = urlFileName;
      } else if (Platform.isWindows) {
        fileName = 'flutter_iptv_update.exe';
      } else {
        fileName = 'flutter_iptv_update.apk';
      }
      
      final file = File('${tempDir.path}/$fileName');
      debugPrint('UPDATE: 保存到: ${file.path}');

      // 下载文件
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'FlutterIPTV-App';
      
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        debugPrint('UPDATE: 下载失败，状态码: ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      debugPrint('UPDATE: 文件大小: $contentLength bytes');
      int receivedBytes = 0;
      
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(receivedBytes / contentLength);
        }
      }
      
      await sink.close();
      
      debugPrint('UPDATE: 下载完成: ${file.path}, 大小: $receivedBytes bytes');
      return file;
    } catch (e, stack) {
      debugPrint('UPDATE: 下载更新时发生错误: $e');
      debugPrint('UPDATE: Stack: $stack');
      return null;
    }
  }

  /// 获取上次检查更新的时间
  Future<DateTime?> _getLastUpdateCheckTime() async {
    try {
      final prefs = ServiceLocator.prefs;
      final timestamp = prefs.getInt(_lastUpdateCheckKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('UPDATE: 获取上次检查时间失败: $e');
      return null;
    }
  }

  /// 保存上次检查更新的时间
  Future<void> _saveLastUpdateCheckTime() async {
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('UPDATE: 保存检查时间: ${DateTime.now()}');
    } catch (e) {
      debugPrint('UPDATE: 保存检查时间失败: $e');
    }
  }
}
