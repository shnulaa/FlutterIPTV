import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  final UpdateService _updateService = UpdateService();

  /// 检查更新并显示更新对话框
  Future<void> checkAndShowUpdateDialog(BuildContext context,
      {bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE_MANAGER: 开始检查更新...');

      final update =
          await _updateService.checkForUpdates(forceCheck: forceCheck);

      if (update != null && context.mounted) {
        debugPrint('UPDATE_MANAGER: 发现新版本，显示更新对话框');
        _showUpdateDialog(context, update);
      } else {
        debugPrint('UPDATE_MANAGER: 没有发现新版本');
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 检查更新时发生错误: $e');
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdate(BuildContext context) async {
    try {
      debugPrint('UPDATE_MANAGER: 手动检查更新...');

      // 显示加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('正在检查更新...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final update = await _updateService.checkForUpdates(forceCheck: true);

      // 隐藏加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (update != null && context.mounted) {
        debugPrint('UPDATE_MANAGER: 发现新版本，显示更新对话框');
        _showUpdateDialog(context, update);
      } else if (context.mounted) {
        debugPrint('UPDATE_MANAGER: 已是最新版本');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已是最新版本'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 手动检查更新时发生错误: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(BuildContext context, AppUpdate update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        update: update,
        onUpdate: () => _handleUpdate(context, update),
        onCancel: () {
          Navigator.of(context).pop();
          debugPrint('UPDATE_MANAGER: 用户选择稍后更新');
        },
      ),
    );
  }

  /// 处理更新操作
  Future<void> _handleUpdate(BuildContext context, AppUpdate update) async {
    try {
      debugPrint('UPDATE_MANAGER: 用户选择立即更新');

      // 关闭更新对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 获取下载URL
      debugPrint('UPDATE_MANAGER: 正在获取下载URL...');
      final downloadUrl = await _updateService.getDownloadUrl(update);
      if (downloadUrl == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取下载链接'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 检查是否是GitHub页面URL（当API受限时返回的备用方案）
      if (downloadUrl.contains('github.com') && !downloadUrl.contains('.exe')) {
        debugPrint('UPDATE_MANAGER: 检测到GitHub页面URL，需要手动下载');
        _showManualDownloadDialog(context, downloadUrl);
        return;
      }

      // 显示下载进度对话框并开始下载
      debugPrint('UPDATE_MANAGER: 开始下载更新文件...');
      final downloadedFile = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          double progress = 0.0;
          String status = '准备下载...';
          
          // 开始下载
          Future.delayed(const Duration(milliseconds: 100), () async {
            try {
              final file = await _updateService.downloadUpdate(
                downloadUrl,
                onProgress: (p) {
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                    progress = p;
                  }
                },
                onStatusChange: (s) {
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                    status = s;
                  }
                },
              );
              
              if (file != null && context.mounted) {
                Navigator.of(context).pop(file);
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          });
          
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 标题和图标
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: progress < 1.0
                                ? const Icon(
                                    Icons.download,
                                    color: Color(0xFF6366F1),
                                    size: 28,
                                  )
                                : const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '下载更新',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  downloadUrl.split('/').last,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 进度条
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFF374151),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress < 1.0 ? const Color(0xFF6366F1) : Colors.green,
                              ),
                              minHeight: 6,
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
      );

      if (downloadedFile != null && context.mounted) {
        debugPrint('UPDATE_MANAGER: 下载完成，开始安装: $downloadedFile');
        
        // 询问用户是否立即安装
        final shouldInstall = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('下载完成'),
            content: const Text('更新文件已下载完成，是否立即安装？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('稍后安装'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  '立即安装',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (shouldInstall == true) {
          final installSuccess = await _updateService.installUpdate(downloadedFile);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(installSuccess ? '安装程序已启动' : '安装失败'),
                backgroundColor: installSuccess ? Colors.green : Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 处理更新时发生错误: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示手动下载对话框
  void _showManualDownloadDialog(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API受限，需要手动下载'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '由于GitHub API请求频率限制，无法直接下载更新。请手动下载并安装最新版本：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. 点击下方按钮打开下载页面\n'
              '2. 下载最新的安装包\n'
              '3. 运行安装程序完成更新',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openDownloadPage(downloadUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              '打开下载页面',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开下载页面
  Future<void> _openDownloadPage(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('UPDATE_MANAGER: 已打开下载页面: $url');
      } else {
        debugPrint('UPDATE_MANAGER: 无法打开URL: $url');
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 打开下载页面失败: $e');
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      return await _updateService.getCurrentVersion();
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 获取当前版本失败: $e');
      return '0.0.0';
    }
  }
}
