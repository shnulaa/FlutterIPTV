import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/constants/user_agent_presets.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/settings_provider.dart';
import 'user_agent_qr_dialog.dart';

class UserAgentDialog extends StatefulWidget {
  const UserAgentDialog({super.key});

  @override
  State<UserAgentDialog> createState() => _UserAgentDialogState();
}

class _UserAgentDialogState extends State<UserAgentDialog> {
  late String _selectedPreset;
  late TextEditingController _customController;
  late FocusNode _customFocusNode;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final currentUserAgent = settings.userAgent;
    
    // Check if current user-agent matches a preset
    final presetKey = UserAgentPresets.getKeyByValue(currentUserAgent);
    _selectedPreset = presetKey ?? 'custom';
    
    // 始终显示当前的User-Agent值
    _customController = TextEditingController(
      text: currentUserAgent,
    );
    _customFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocusNode.dispose();
    super.dispose();
  }

  void _onPresetChanged(String? value) {
    if (value == null) return;
    
    setState(() {
      _selectedPreset = value;
      if (value != 'custom') {
        // 选择预设时，显示预设的User-Agent值
        final preset = UserAgentPresets.getPreset(value);
        if (preset != null) {
          _customController.text = preset;
        }
      }
      // 如果选择"自定义"，保持当前输入框的内容不变
    });
  }

  Future<void> _saveUserAgent() async {
    final settings = context.read<SettingsProvider>();
    final userAgent = _customController.text.trim();
    
    if (userAgent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)!.userAgentCustomHint),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    await settings.setUserAgent(userAgent);
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)!.userAgentSaved),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resetUserAgent() async {
    final settings = context.read<SettingsProvider>();
    await settings.resetUserAgent();
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)!.userAgentReset),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showQRDialog() async {
    await showDialog(
      context: context,
      builder: (context) => UserAgentQRDialog(
        onUserAgentReceived: (userAgent) {
          setState(() {
            _selectedPreset = 'custom';
            _customController.text = userAgent;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context)!;
    final isTV = PlatformDetector.isTV;
    
    return AlertDialog(
      title: Text(strings.userAgent),
      content: SingleChildScrollView(
        child: SizedBox(
          width: isTV ? 600 : 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preset dropdown
              Text(
                strings.userAgentPreset,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPreset,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: 'wget', child: Text(strings.userAgentPresetWget)),
                  DropdownMenuItem(value: 'chrome_windows', child: Text(strings.userAgentPresetChromeWin)),
                  DropdownMenuItem(value: 'chrome_mac', child: Text(strings.userAgentPresetChromeMac)),
                  DropdownMenuItem(value: 'firefox', child: Text(strings.userAgentPresetFirefox)),
                  DropdownMenuItem(value: 'safari', child: Text(strings.userAgentPresetSafari)),
                  DropdownMenuItem(value: 'edge', child: Text(strings.userAgentPresetEdge)),
                  DropdownMenuItem(value: 'vlc', child: Text(strings.userAgentPresetVLC)),
                  DropdownMenuItem(value: 'ffmpeg', child: Text(strings.userAgentPresetFFmpeg)),
                  DropdownMenuItem(value: 'android_chrome', child: Text(strings.userAgentPresetAndroid)),
                  DropdownMenuItem(value: 'ios_safari', child: Text(strings.userAgentPresetIOS)),
                  DropdownMenuItem(value: 'custom', child: Text(strings.userAgentPresetCustom)),
                ],
                onChanged: _onPresetChanged,
              ),
              
              const SizedBox(height: 16),
              
              // Custom input
              Text(
                strings.userAgentCustom,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // TV端：只读Text显示，避免焦点陷阱
              // 其他平台：TextField可编辑
              if (isTV)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Text(
                    _customController.text.isEmpty 
                        ? strings.userAgentCustomHint 
                        : _customController.text,
                    style: TextStyle(
                      color: _customController.text.isEmpty 
                          ? Colors.grey 
                          : null,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _customController,
                  focusNode: _customFocusNode,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: strings.userAgentCustomHint,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  readOnly: _selectedPreset != 'custom', // 预设时只读，自定义时可编辑
                ),
              
              // QR scan button for TV
              if (isTV) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showQRDialog,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(strings.userAgentScanQR),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: _resetUserAgent,
          child: Text(strings.reset),
        ),
        ElevatedButton(
          onPressed: _saveUserAgent,
          child: Text(strings.save),
        ),
      ],
    );
  }
}
