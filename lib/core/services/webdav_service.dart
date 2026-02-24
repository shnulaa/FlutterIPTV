import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/backup_file.dart';
import 'service_locator.dart';

/// WebDAV 服务
/// 
/// 使用 Dio 实现 WebDAV 协议的基本操作
class WebDAVService {
  Dio? _dio;
  String? _serverUrl;
  String? _username;
  String? _password;
  String? _remotePath;

  /// 配置 WebDAV 连接
  void configure({
    required String serverUrl,
    required String username,
    required String password,
    String remotePath = '/',
  }) {
    _serverUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    _username = username;
    _password = password;
    _remotePath = remotePath.endsWith('/') ? remotePath : '$remotePath/';

    _dio = Dio(BaseOptions(
      baseUrl: _serverUrl!,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Authorization': 'Basic ${_encodeBasicAuth(username, password)}',
      },
    ));

    ServiceLocator.log.i('WebDAV 配置完成: $_serverUrl', tag: 'WebDAVService');
  }

  /// Base64 编码认证信息
  String _encodeBasicAuth(String username, String password) {
    final credentials = '$username:$password';
    final bytes = credentials.codeUnits;
    return base64Encode(bytes);
  }

  /// 测试连接
  Future<bool> testConnection() async {
    if (_dio == null) {
      ServiceLocator.log.e('WebDAV 未配置', tag: 'WebDAVService');
      throw Exception('WebDAV 未配置');
    }

    try {
      ServiceLocator.log.i('开始测试 WebDAV 连接...', tag: 'WebDAVService');
      ServiceLocator.log.d('服务器: $_serverUrl', tag: 'WebDAVService');
      ServiceLocator.log.d('远程路径: $_remotePath', tag: 'WebDAVService');
      ServiceLocator.log.d('用户名: $_username', tag: 'WebDAVService');
      
      // 使用 PROPFIND 方法测试连接
      final response = await _dio!.request(
        _remotePath!,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '0',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      ServiceLocator.log.d('响应状态码: ${response.statusCode}', tag: 'WebDAVService');
      
      // 如果目录不存在（404），尝试创建
      if (response.statusCode == 404) {
        ServiceLocator.log.i('远程目录不存在，尝试创建: $_remotePath', tag: 'WebDAVService');
        await createDirectory(_remotePath!);
        return true;
      }
      
      final success = response.statusCode == 207 || response.statusCode == 200;
      ServiceLocator.log.i('WebDAV 连接测试${success ? "成功" : "失败"}', tag: 'WebDAVService');
      return success;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('WebDAV 连接测试失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow; // 重新抛出异常，让调用者能看到具体错误
    }
  }

  /// 创建远程目录
  Future<void> createDirectory(String path) async {
    if (_dio == null) {
      throw Exception('WebDAV 未配置');
    }

    try {
      ServiceLocator.log.i('创建远程目录: $path', tag: 'WebDAVService');
      
      final response = await _dio!.request(
        path,
        options: Options(
          method: 'MKCOL',
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      ServiceLocator.log.d('创建目录响应状态码: ${response.statusCode}', tag: 'WebDAVService');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        ServiceLocator.log.i('远程目录创建成功', tag: 'WebDAVService');
      } else if (response.statusCode == 405) {
        // 405 表示目录已存在
        ServiceLocator.log.i('远程目录已存在', tag: 'WebDAVService');
      } else {
        throw Exception('创建目录失败，状态码: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      ServiceLocator.log.e('创建远程目录失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 上传备份文件
  Future<void> uploadBackup({
    required String localFilePath,
    required Function(double progress) onProgress,
  }) async {
    if (_dio == null) {
      throw Exception('WebDAV 未配置');
    }

    try {
      final file = File(localFilePath);
      final fileName = localFilePath.split(RegExp(r'[/\\]')).last;
      final remotePath = '$_remotePath$fileName';

      ServiceLocator.log.i('开始上传备份到 WebDAV: $remotePath', tag: 'WebDAVService');

      final fileBytes = await file.readAsBytes();

      await _dio!.put(
        remotePath,
        data: fileBytes,
        options: Options(
          headers: {
            'Content-Type': 'application/zip',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            onProgress(sent / total);
          }
        },
      );

      ServiceLocator.log.i('备份上传成功', tag: 'WebDAVService');
    } catch (e, stackTrace) {
      ServiceLocator.log.e('上传备份失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 获取 WebDAV 备份列表
  Future<List<BackupFile>> listBackups() async {
    if (_dio == null) {
      throw Exception('WebDAV 未配置');
    }

    try {
      ServiceLocator.log.d('获取 WebDAV 备份列表...', tag: 'WebDAVService');

      final response = await _dio!.request(
        _remotePath!,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '1',
          },
        ),
      );

      if (response.statusCode != 207) {
        throw Exception('获取文件列表失败: ${response.statusCode}');
      }

      final backupFiles = <BackupFile>[];
      final responseData = response.data.toString();
      
      ServiceLocator.log.d('PROPFIND 响应长度: ${responseData.length}', tag: 'WebDAVService');
      
      // 使用正则表达式提取 .zip 文件信息
      // 匹配 <D:response> 或 <response> 块（兼容不同的命名空间）
      final responsePattern = RegExp(r'<[^:>]*:?response[^>]*>(.*?)</[^:>]*:?response>', dotAll: true);
      final responseMatches = responsePattern.allMatches(responseData);

      ServiceLocator.log.d('找到 ${responseMatches.length} 个 response 块', tag: 'WebDAVService');

      for (final responseMatch in responseMatches) {
        final responseBlock = responseMatch.group(1) ?? '';
        
        // 提取 href（兼容不同的命名空间）
        final hrefPattern = RegExp(r'<[^:>]*:?href[^>]*>([^<]*)</[^:>]*:?href>');
        final hrefMatch = hrefPattern.firstMatch(responseBlock);
        final href = hrefMatch?.group(1);
        
        ServiceLocator.log.d('解析到 href: $href', tag: 'WebDAVService');
        
        if (href == null || !href.endsWith('.zip')) {
          continue;
        }
        
        final fileName = href.split('/').last;
        
        ServiceLocator.log.d('文件名: $fileName', tag: 'WebDAVService');
        
        // 验证文件名格式：backup_数字.zip
        if (!_isValidBackupFileName(fileName)) {
          ServiceLocator.log.d('跳过非标准格式的备份文件: $fileName', tag: 'WebDAVService');
          continue;
        }
        
        // 提取文件大小（兼容不同的命名空间）
        final sizePattern = RegExp(r'<[^:>]*:?getcontentlength[^>]*>(\d+)</[^:>]*:?getcontentlength>');
        final sizeMatch = sizePattern.firstMatch(responseBlock);
        final size = int.tryParse(sizeMatch?.group(1) ?? '0') ?? 0;
        
        // 提取修改时间（优先从文件名解析，fallback 到 WebDAV 属性）
        DateTime modifiedTime = DateTime.now();
        
        // 尝试从文件名解析时间戳：backup_1771852442578.zip
        final timestampPattern = RegExp(r'backup_(\d{13})\.zip');
        final timestampMatch = timestampPattern.firstMatch(fileName);
        
        if (timestampMatch != null) {
          try {
            final timestamp = int.parse(timestampMatch.group(1)!);
            modifiedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            ServiceLocator.log.d('从文件名解析时间: $modifiedTime', tag: 'WebDAVService');
          } catch (e) {
            ServiceLocator.log.w('从文件名解析时间戳失败: ${timestampMatch.group(1)}', tag: 'WebDAVService');
          }
        } else {
          // Fallback: 从 WebDAV 属性获取
          final timePattern = RegExp(r'<[^:>]*:?getlastmodified[^>]*>([^<]+)</[^:>]*:?getlastmodified>');
          final timeMatch = timePattern.firstMatch(responseBlock);
          final timeStr = timeMatch?.group(1);
          
          if (timeStr != null) {
            try {
              modifiedTime = DateTime.parse(timeStr);
              ServiceLocator.log.d('从 WebDAV 属性解析时间: $modifiedTime', tag: 'WebDAVService');
            } catch (e) {
              ServiceLocator.log.w('解析 WebDAV 时间失败: $timeStr', tag: 'WebDAVService');
            }
          }
        }
        
        ServiceLocator.log.d('找到备份文件: $fileName, href: $href, 大小: $size bytes', tag: 'WebDAVService');
        
        // 处理路径：从完整路径中提取相对于 _remotePath 的部分
        String relativePath = href;
        
        // 如果 href 是绝对路径（以 http 开头）
        if (href.startsWith('http://') || href.startsWith('https://')) {
          final uri = Uri.parse(href);
          relativePath = uri.path;
        }
        
        // 从 serverUrl 中提取路径部分
        String? baseUrlPath;
        if (_serverUrl != null) {
          try {
            final serverUri = Uri.parse(_serverUrl!);
            baseUrlPath = serverUri.path;
            ServiceLocator.log.d('BaseURL 路径: $baseUrlPath', tag: 'WebDAVService');
            if (baseUrlPath.isNotEmpty && baseUrlPath != '/') {
              // 如果 relativePath 以 baseUrlPath 开头，移除它
              if (relativePath.startsWith(baseUrlPath)) {
                relativePath = relativePath.substring(baseUrlPath.length);
                if (!relativePath.startsWith('/')) {
                  relativePath = '/$relativePath';
                }
                ServiceLocator.log.d('移除 baseUrlPath 后的路径: $relativePath', tag: 'WebDAVService');
              }
            }
          } catch (e) {
            ServiceLocator.log.w('解析 serverUrl 失败: $_serverUrl', tag: 'WebDAVService');
          }
        }
        
        backupFiles.add(BackupFile.fromWebDAV(
          name: fileName,
          path: relativePath, // 使用处理后的相对路径
          size: size,
          modifiedTime: modifiedTime,
        ));
      }

      ServiceLocator.log.i('获取到 ${backupFiles.length} 个 WebDAV 备份', tag: 'WebDAVService');
      
      // 按创建时间倒序排列（最新的在前面）
      backupFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return backupFiles;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('获取 WebDAV 备份列表失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 验证备份文件名格式
  /// 
  /// 有效格式：backup_1771852442578.zip
  /// - 必须以 "backup_" 开头
  /// - 后面跟 13 位数字（时间戳）
  /// - 以 ".zip" 结尾
  bool _isValidBackupFileName(String fileName) {
    final pattern = RegExp(r'^backup_\d{13}\.zip$');
    return pattern.hasMatch(fileName);
  }

  /// 下载备份文件
  Future<String> downloadBackup({
    required String remotePath,
    required String localPath,
    required Function(double progress) onProgress,
  }) async {
    if (_dio == null) {
      throw Exception('WebDAV 未配置');
    }

    try {
      ServiceLocator.log.i('开始从 WebDAV 下载备份: $remotePath', tag: 'WebDAVService');
      ServiceLocator.log.d('本地保存路径: $localPath', tag: 'WebDAVService');
      ServiceLocator.log.d('BaseURL: $_serverUrl', tag: 'WebDAVService');

      // remotePath 已经是相对于 baseUrl 的路径，直接使用
      ServiceLocator.log.d('使用路径: $remotePath', tag: 'WebDAVService');

      await _dio!.download(
        remotePath,
        localPath,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            ServiceLocator.log.d('下载进度: ${(progress * 100).toStringAsFixed(1)}%', tag: 'WebDAVService');
            onProgress(progress);
          }
        },
      );

      // 验证文件是否下载成功
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('文件下载失败：文件不存在');
      }
      
      final fileSize = await file.length();
      ServiceLocator.log.i('备份下载成功: $localPath (大小: $fileSize bytes)', tag: 'WebDAVService');
      return localPath;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('下载备份失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 删除 WebDAV 备份
  Future<void> deleteBackup(String remotePath) async {
    if (_dio == null) {
      throw Exception('WebDAV 未配置');
    }

    try {
      ServiceLocator.log.i('删除 WebDAV 备份: $remotePath', tag: 'WebDAVService');
      ServiceLocator.log.d('BaseURL: $_serverUrl', tag: 'WebDAVService');
      
      // remotePath 已经是相对于 baseUrl 的路径，直接使用
      ServiceLocator.log.d('使用路径: $remotePath', tag: 'WebDAVService');
      
      final response = await _dio!.delete(
        remotePath,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      ServiceLocator.log.d('删除响应状态码: ${response.statusCode}', tag: 'WebDAVService');
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('删除失败，状态码: ${response.statusCode}');
      }
      
      ServiceLocator.log.i('删除成功', tag: 'WebDAVService');
    } catch (e, stackTrace) {
      ServiceLocator.log.e('删除 WebDAV 备份失败', tag: 'WebDAVService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 是否已配置
  bool get isConfigured => _dio != null;

  /// 获取当前配置信息（用于显示或重新配置）
  Map<String, String?> get currentConfig => {
    'serverUrl': _serverUrl,
    'username': _username,
    'password': _password,
    'remotePath': _remotePath,
  };
}
