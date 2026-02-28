import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/disclaimer_service.dart';
import '../services/service_locator.dart';

/// 全屏免责声明页面
/// 用户必须同意才能继续使用应用
class DisclaimerScreen extends StatefulWidget {
  final VoidCallback? onAccepted;
  
  const DisclaimerScreen({
    super.key,
    this.onAccepted,
  });

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  final _disclaimerService = DisclaimerService();
  bool _isProcessing = false;
  
  // TV 端焦点管理
  final FocusNode _acceptButtonFocus = FocusNode();
  final FocusNode _declineButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // TV 端默认焦点在同意按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _acceptButtonFocus.requestFocus();
      ServiceLocator.log.d('初始焦点已设置到同意按钮', tag: 'Disclaimer');
    });
  }

  @override
  void dispose() {
    _acceptButtonFocus.dispose();
    _declineButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前语言
    final locale = Localizations.maybeLocaleOf(context);
    final isZh = locale?.languageCode == 'zh';
    
    final theme = Theme.of(context);
    final isTV = MediaQuery.of(context).size.width > 1000;

    // 文本内容
    final title = isZh ? '免责声明' : 'Disclaimer';
    final content = isZh ? '''1. 本应用仅供个人学习、研究和交流使用。

2. 本应用不提供任何视频内容，所有内容均来自用户自行添加的第三方源。

3. 用户需自行承担使用本应用的风险，并遵守所在地区的法律法规。

4. 开发者不对用户添加的内容来源、合法性、准确性负责。

5. 如果您所在地区的法律禁止使用此类应用，请立即停止使用并卸载。

6. 继续使用本应用即表示您已阅读、理解并同意本免责声明。''' : '''1. This application is for personal learning, research, and communication purposes only.

2. This application does not provide any video content. All content comes from third-party sources added by users.

3. Users are responsible for the risks of using this application and must comply with local laws and regulations.

4. The developer is not responsible for the source, legality, or accuracy of user-added content.

5. If the laws in your region prohibit the use of such applications, please stop using and uninstall immediately.

6. Continued use of this application indicates that you have read, understood, and agreed to this disclaimer.''';
    final acceptText = isZh ? '同意并继续' : 'Accept and Continue';
    final declineText = isZh ? '拒绝' : 'Decline';

    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTV ? 800 : 600,
                    maxHeight: constraints.maxHeight,
                  ),
                  padding: EdgeInsets.all(isTV ? 32 : 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 标题 - 紧凑布局
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                            size: isTV ? 36 : 40,
                          ),
                          SizedBox(width: isTV ? 12 : 12),
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isTV ? 28 : 28,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isTV ? 24 : 32),

                      // 免责声明内容 - 使用 Expanded 确保占用剩余空间
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          padding: EdgeInsets.all(isTV ? 24 : 24),
                          child: SingleChildScrollView(
                            child: Text(
                              content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                fontSize: isTV ? 16 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isTV ? 24 : 32),

                      // 按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 拒绝按钮
                          _DeclineButton(
                            text: declineText,
                            isTV: isTV,
                            isProcessing: _isProcessing,
                            focusNode: _declineButtonFocus,
                            onPressed: _handleDecline,
                          ),
                          SizedBox(width: isTV ? 24 : 16),

                          // 同意按钮
                          _AcceptButton(
                            text: acceptText,
                            isTV: isTV,
                            isProcessing: _isProcessing,
                            focusNode: _acceptButtonFocus,
                            onPressed: _handleAccept,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 处理同意
  Future<void> _handleAccept() async {
    if (_isProcessing) {
      ServiceLocator.log.d('正在处理中，忽略重复点击', tag: 'Disclaimer');
      return;
    }

    setState(() => _isProcessing = true);
    ServiceLocator.log.d('用户点击同意按钮', tag: 'Disclaimer');

    try {
      ServiceLocator.log.d('开始保存免责声明状态...', tag: 'Disclaimer');
      await _disclaimerService.setAccepted();
      ServiceLocator.log.d('免责声明状态已保存到 SharedPreferences', tag: 'Disclaimer');
      
      // 验证保存结果
      final saved = await _disclaimerService.hasAccepted();
      ServiceLocator.log.d('验证保存结果: $saved', tag: 'Disclaimer');
      
      if (saved) {
        ServiceLocator.log.d('保存成功，调用 onAccepted 回调', tag: 'Disclaimer');
        // 调用回调通知父组件
        widget.onAccepted?.call();
        ServiceLocator.log.d('onAccepted 回调已调用', tag: 'Disclaimer');
      } else {
        ServiceLocator.log.e('保存失败，验证结果为 false', tag: 'Disclaimer');
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    } catch (e, stackTrace) {
      ServiceLocator.log.e('保存免责声明状态失败: $e', tag: 'Disclaimer');
      ServiceLocator.log.e('堆栈: $stackTrace', tag: 'Disclaimer');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 处理拒绝
  void _handleDecline() {
    if (_isProcessing) return;

    ServiceLocator.log.d('用户点击拒绝，退出应用', tag: 'Disclaimer');
    
    // 退出应用
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }
}

/// 拒绝按钮
class _DeclineButton extends StatefulWidget {
  final String text;
  final bool isTV;
  final bool isProcessing;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _DeclineButton({
    required this.text,
    required this.isTV,
    required this.isProcessing,
    required this.focusNode,
    required this.onPressed,
  });

  @override
  State<_DeclineButton> createState() => _DeclineButtonState();
}

class _DeclineButtonState extends State<_DeclineButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
      ServiceLocator.log.d('拒绝按钮焦点变化: $_isFocused', tag: 'Disclaimer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      focusNode: widget.focusNode,
      onPressed: widget.isProcessing ? null : widget.onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isTV ? 48 : 32,
          vertical: widget.isTV ? 20 : 16,
        ),
        side: BorderSide(
          color: _isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: _isFocused ? 2 : 1,
        ),
      ),
      child: Text(
        widget.text,
        style: TextStyle(
          fontSize: widget.isTV ? 20 : 18,
        ),
      ),
    );
  }
}

/// 同意按钮
class _AcceptButton extends StatefulWidget {
  final String text;
  final bool isTV;
  final bool isProcessing;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _AcceptButton({
    required this.text,
    required this.isTV,
    required this.isProcessing,
    required this.focusNode,
    required this.onPressed,
  });

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    ServiceLocator.log.d('同意按钮初始化', tag: 'Disclaimer');
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
      ServiceLocator.log.d('同意按钮焦点变化: $_isFocused', tag: 'Disclaimer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      focusNode: widget.focusNode,
      onPressed: widget.isProcessing ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isTV ? 48 : 32,
          vertical: widget.isTV ? 20 : 16,
        ),
        backgroundColor: _isFocused
            ? theme.colorScheme.primary
            : theme.colorScheme.primaryContainer,
        foregroundColor: _isFocused
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onPrimaryContainer,
      ),
      child: widget.isProcessing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            )
          : Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.isTV ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
