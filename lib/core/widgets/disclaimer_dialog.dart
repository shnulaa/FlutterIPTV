import 'package:flutter/material.dart';

/// 免责声明对话框
/// 首次启动时显示，用户必须同意才能继续使用
class DisclaimerDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const DisclaimerDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 Localizations.maybeLocaleOf 获取当前语言
    final locale = Localizations.maybeLocaleOf(context);
    final isZh = locale?.languageCode == 'zh';
    
    final theme = Theme.of(context);
    final isTV = MediaQuery.of(context).size.width > 1000;

    // 直接使用文本，避免 AppStrings.of(context) 返回 null
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
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTV ? 800 : 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 免责声明内容（可滚动）
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 拒绝按钮
                  _DeclineButton(
                    text: declineText,
                    onPressed: onDecline,
                    isTV: isTV,
                  ),
                  const SizedBox(width: 12),

                  // 同意按钮
                  _AcceptButton(
                    text: acceptText,
                    onPressed: onAccept,
                    isTV: isTV,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 拒绝按钮
class _DeclineButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isTV;

  const _DeclineButton({
    required this.text,
    required this.onPressed,
    required this.isTV,
  });

  @override
  State<_DeclineButton> createState() => _DeclineButtonState();
}

class _DeclineButtonState extends State<_DeclineButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isTV ? 32 : 24,
            vertical: widget.isTV ? 16 : 12,
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
            fontSize: widget.isTV ? 18 : 16,
          ),
        ),
      ),
    );
  }
}

/// 同意按钮
class _AcceptButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isTV;

  const _AcceptButton({
    required this.text,
    required this.onPressed,
    required this.isTV,
  });

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    // 延迟请求焦点，确保对话框已完全显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      autofocus: true, // 默认焦点在同意按钮
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isTV ? 32 : 24,
            vertical: widget.isTV ? 16 : 12,
          ),
          backgroundColor: _isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          foregroundColor: _isFocused
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onPrimaryContainer,
        ),
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.isTV ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
