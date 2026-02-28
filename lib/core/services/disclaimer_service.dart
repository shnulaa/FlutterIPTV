import 'service_locator.dart';

/// 免责声明服务
/// 管理用户是否已同意免责声明的状态
class DisclaimerService {
  static const String _disclaimerAcceptedKey = 'disclaimer_accepted';

  /// 检查用户是否已同意免责声明
  Future<bool> hasAccepted() async {
    try {
      final prefs = ServiceLocator.prefs;
      final accepted = prefs.getBool(_disclaimerAcceptedKey) ?? false;
      ServiceLocator.log.d('DISCLAIMER: 检查免责声明状态 = $accepted');
      return accepted;
    } catch (e) {
      ServiceLocator.log.e('DISCLAIMER: 检查免责声明状态失败 - $e');
      return false;
    }
  }

  /// 设置用户已同意免责声明
  Future<void> setAccepted() async {
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setBool(_disclaimerAcceptedKey, true);
      ServiceLocator.log.d('DISCLAIMER: 用户已同意免责声明');
    } catch (e) {
      ServiceLocator.log.e('DISCLAIMER: 保存免责声明状态失败 - $e');
    }
  }

  /// 重置免责声明状态（用于测试或重置应用）
  Future<void> reset() async {
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.remove(_disclaimerAcceptedKey);
      ServiceLocator.log.d('DISCLAIMER: 免责声明状态已重置');
    } catch (e) {
      ServiceLocator.log.e('DISCLAIMER: 重置免责声明状态失败 - $e');
    }
  }
}
