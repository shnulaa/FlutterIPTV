import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Windows API 函数类型定义
typedef GetForegroundWindowNative = IntPtr Function();
typedef GetForegroundWindowDart = int Function();

typedef GetWindowLongNative = Int32 Function(IntPtr hWnd, Int32 nIndex);
typedef GetWindowLongDart = int Function(int hWnd, int nIndex);

typedef SetWindowLongNative = Int32 Function(
    IntPtr hWnd, Int32 nIndex, Int32 dwNewLong);
typedef SetWindowLongDart = int Function(int hWnd, int nIndex, int dwNewLong);

typedef SetWindowPosNative = Int32 Function(IntPtr hWnd, IntPtr hWndInsertAfter,
    Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef SetWindowPosDart = int Function(
    int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

typedef ShowWindowNative = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef ShowWindowDart = int Function(int hWnd, int nCmdShow);

typedef GetSystemMetricsNative = Int32 Function(Int32 nIndex);
typedef GetSystemMetricsDart = int Function(int nIndex);

typedef GetWindowRectNative = Int32 Function(IntPtr hWnd, Pointer<RECT> lpRect);
typedef GetWindowRectDart = int Function(int hWnd, Pointer<RECT> lpRect);

// RECT 结构体
final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

/// Windows 原生全屏 API
class WindowsFullscreenNative {
  static bool _initialized = false;
  static DynamicLibrary? _user32;

  // Windows API 常量
  static const int gwlStyle = -16;
  static const int wsOverlappedWindow = 0x00CF0000;
  static const int swpFrameChanged = 0x0020;
  static const int swpNomove = 0x0002;
  static const int swpNosize = 0x0001;
  static const int swpNozorder = 0x0004;
  static const int swpShowwindow = 0x0040;
  static const int swShow = 5;

  // 保存原始窗口状态
  static int? _savedStyle;
  static int? _savedX;
  static int? _savedY;
  static int? _savedWidth;
  static int? _savedHeight;

  // 函数指针
  static GetForegroundWindowDart? _getForegroundWindow;
  static GetWindowLongDart? _getWindowLong;
  static SetWindowLongDart? _setWindowLong;
  static SetWindowPosDart? _setWindowPos;
  static ShowWindowDart? _showWindow;
  static GetSystemMetricsDart? _getSystemMetrics;
  static GetWindowRectDart? _getWindowRect;

  /// 初始化 Windows API
  static bool initialize() {
    if (_initialized) return true;
    if (!Platform.isWindows) return false;

    try {
      _user32 = DynamicLibrary.open('user32.dll');

      _getForegroundWindow = _user32!
          .lookup<NativeFunction<GetForegroundWindowNative>>(
              'GetForegroundWindow')
          .asFunction();

      _getWindowLong = _user32!
          .lookup<NativeFunction<GetWindowLongNative>>('GetWindowLongW')
          .asFunction();

      _setWindowLong = _user32!
          .lookup<NativeFunction<SetWindowLongNative>>('SetWindowLongW')
          .asFunction();

      _setWindowPos = _user32!
          .lookup<NativeFunction<SetWindowPosNative>>('SetWindowPos')
          .asFunction();

      _showWindow = _user32!
          .lookup<NativeFunction<ShowWindowNative>>('ShowWindow')
          .asFunction();

      _getSystemMetrics = _user32!
          .lookup<NativeFunction<GetSystemMetricsNative>>('GetSystemMetrics')
          .asFunction();

      _getWindowRect = _user32!
          .lookup<NativeFunction<GetWindowRectNative>>('GetWindowRect')
          .asFunction();

      _initialized = true;
      return true;
    } catch (e) {
      print('Failed to initialize Windows API: $e');
      return false;
    }
  }

  /// 获取当前窗口句柄
  static int? getWindowHandle() {
    if (!_initialized && !initialize()) return null;
    try {
      final hwnd = _getForegroundWindow!();
      return hwnd != 0 ? hwnd : null;
    } catch (e) {
      print('Failed to get window handle: $e');
      return null;
    }
  }

  /// 检查是否全屏
  static bool isFullScreen() {
    final hwnd = getWindowHandle();
    if (hwnd == null) return false;

    try {
      final style = _getWindowLong!(hwnd, gwlStyle);
      return (style & wsOverlappedWindow) == 0;
    } catch (e) {
      print('Failed to check fullscreen: $e');
      return false;
    }
  }

  /// 进入全屏
  static bool enterFullScreen() {
    final hwnd = getWindowHandle();
    if (hwnd == null) return false;

    try {
      // 保存当前窗口样式
      _savedStyle = _getWindowLong!(hwnd, gwlStyle);
      
      // 获取并保存当前窗口位置和大小
      final rect = calloc<RECT>();
      try {
        if (_getWindowRect!(hwnd, rect) != 0) {
          _savedX = rect.ref.left;
          _savedY = rect.ref.top;
          _savedWidth = rect.ref.right - rect.ref.left;
          _savedHeight = rect.ref.bottom - rect.ref.top;
        }
      } finally {
        calloc.free(rect);
      }

      // 获取屏幕尺寸
      final screenWidth = _getSystemMetrics!(0); // SM_CXSCREEN
      final screenHeight = _getSystemMetrics!(1); // SM_CYSCREEN

      // 移除窗口边框和标题栏
      _setWindowLong!(hwnd, gwlStyle, _savedStyle! & ~wsOverlappedWindow);

      // 设置窗口位置和大小为全屏
      _setWindowPos!(
        hwnd,
        0,
        0,
        0,
        screenWidth,
        screenHeight,
        swpFrameChanged | swpNozorder | swpShowwindow,
      );

      return true;
    } catch (e) {
      print('Failed to enter fullscreen: $e');
      return false;
    }
  }

  /// 退出全屏
  static bool exitFullScreen() {
    final hwnd = getWindowHandle();
    if (hwnd == null) return false;

    try {
      // 恢复窗口样式
      if (_savedStyle != null) {
        _setWindowLong!(hwnd, gwlStyle, _savedStyle!);
      }

      // 恢复窗口位置和大小
      if (_savedX != null && _savedY != null && 
          _savedWidth != null && _savedHeight != null) {
        _setWindowPos!(
          hwnd,
          0,
          _savedX!,
          _savedY!,
          _savedWidth!,
          _savedHeight!,
          swpFrameChanged | swpNozorder | swpShowwindow,
        );
      }

      // 显示窗口
      _showWindow!(hwnd, swShow);

      return true;
    } catch (e) {
      print('Failed to exit fullscreen: $e');
      return false;
    }
  }

  /// 切换全屏状态
  static bool toggleFullScreen() {
    try {
      if (isFullScreen()) {
        return exitFullScreen();
      } else {
        return enterFullScreen();
      }
    } catch (e) {
      print('Failed to toggle fullscreen: $e');
      return false;
    }
  }
}
