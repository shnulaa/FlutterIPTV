import '../platform/platform_detector.dart';
import '../services/service_locator.dart';

/// 卡片尺寸计算工具类
/// 根据可用宽度动态计算卡片数量和尺寸，适配所有平台
class CardSizeCalculator {
  /// 卡片间距
  static double get spacing => PlatformDetector.isMobile ? 6.0 : 7.0;
  
  /// 卡片宽高比（宽:高）- 统一比例，无论有没有EPG
  /// 值越大卡片越扁，值越小卡片越高
  /// 调整为适中比例，确保EPG可见
  // static double get aspectRatio => PlatformDetector.isMobile ? 0.85 : 1;
  static double aspectRatio() {
    if (PlatformDetector.isMobile) {
      return 0.85;
    } else if (PlatformDetector.isTV) {
      return 0.9;
    } else {
      return 1;
    }
  }

  
  /// 计算每行卡片数量（用于频道页Grid）
  static int calculateCardsPerRow(double availableWidth) {
    int cardsPerRow;
    String mode;
    
    if (PlatformDetector.isMobile) {
      // 手机端：根据宽度判断横屏还是竖屏
      if (availableWidth > 700) {
        // 横屏模式 - 显示更多卡片
        mode = '横屏';
        if (availableWidth > 900) {
          cardsPerRow = 10;
        } else if (availableWidth > 800) {
          cardsPerRow = 9;
        } else {
          cardsPerRow = 9;
        }
      } else {
        // 竖屏模式
        mode = '竖屏';
        if (availableWidth > 450) {
          cardsPerRow = 6;
        } else if (availableWidth > 350) {
          cardsPerRow = 5;
        } else if (availableWidth > 250) {
          cardsPerRow = 4;
        } else {
          cardsPerRow = 3;
        }
      }
      ServiceLocator.log.d('频道页卡片计算 - 手机端$mode: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    } else if (PlatformDetector.isTV) {
      // TV端频道页：适中卡片数量，确保EPG可读
      // if (availableWidth > 1400) return 9;
      // if (availableWidth > 1200) return 8;
      // if (availableWidth > 1000) return 7;
      // if (availableWidth > 800) return 6;
      if (availableWidth > 1800) {
        cardsPerRow = 11;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 9;
      } else if (availableWidth > 1200) {
        cardsPerRow = 9;
      } else if (availableWidth > 1000) {
        cardsPerRow = 8;
      } else if (availableWidth > 800) {
        cardsPerRow = 8;
      } else if (availableWidth > 780) {
        cardsPerRow = 7;
      } else if (availableWidth > 750) {
        cardsPerRow = 7;
      } else if (availableWidth > 700) {
        cardsPerRow = 6;
      } else if (availableWidth > 600) {
        cardsPerRow = 6;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('频道页卡片计算 - TV端: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    } else {
      // Windows/Desktop端：适中卡片数量
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 5;
      } else if (availableWidth > 725) {
        cardsPerRow = 5;
      } else if (availableWidth > 700) {
        cardsPerRow = 5;
      } else if (availableWidth > 600) {
        cardsPerRow = 4;
      } else {
        cardsPerRow = 3;
      }
      ServiceLocator.log.d('频道页卡片计算 - Desktop端: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    }
  }
  
  /// 计算首页每行卡片数量（首页需要更多更小的卡片）
  static int calculateHomeCardsPerRow(double availableWidth) {
    int cardsPerRow;
    String mode;
    
    if (PlatformDetector.isMobile) {
      // 手机端：根据宽度判断横屏还是竖屏
      if (availableWidth > 700) {
        // 横屏模式 - 显示更多卡片
        mode = '横屏';
        if (availableWidth > 900) {
          cardsPerRow = 10;
        } else if (availableWidth > 800) {
          cardsPerRow = 9;
        } else {
          cardsPerRow = 9;
        }
      } else {
        // 竖屏模式
        mode = '竖屏';
        if (availableWidth > 450) {
          cardsPerRow = 5;
        } else if (availableWidth > 350) {
          cardsPerRow = 4;
        } else if (availableWidth > 250) {
          cardsPerRow = 4;
        } else {
          cardsPerRow = 3;
        }
      }
      ServiceLocator.log.d('首页卡片计算 - 手机端$mode: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    } else if (PlatformDetector.isTV) {
      // TV端首页：全宽约1800px，适中卡片数量
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 6;
      } else if (availableWidth > 700) {
        cardsPerRow = 6;
      } else if (availableWidth > 600) {
        cardsPerRow = 5;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('首页卡片计算 - TV端: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    } else {
      // Windows首页
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 5;
      } else if (availableWidth > 700) {
        cardsPerRow = 5;
      } else if (availableWidth > 600) {
        cardsPerRow = 4;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('首页卡片计算 - Desktop端: 宽度=${availableWidth.toStringAsFixed(1)}px, 每行=$cardsPerRow张', tag: 'CardSize');
      return cardsPerRow;
    }
  }
  
  /// 计算卡片宽度
  static double calculateCardWidth(double availableWidth) {
    final cardsPerRow = calculateCardsPerRow(availableWidth);
    final totalSpacing = (cardsPerRow + 1) * spacing;
    return (availableWidth - totalSpacing) / cardsPerRow;
  }
  
  /// 计算卡片高度
  static double calculateCardHeight(double availableWidth) {
    return calculateCardWidth(availableWidth) / aspectRatio();
  }
  
  /// 获取GridView的crossAxisCount
  static int getGridCrossAxisCount(double availableWidth) {
    return calculateCardsPerRow(availableWidth);
  }
  
  /// 获取GridView的childAspectRatio
  static double getGridChildAspectRatio() {
    return aspectRatio();
  }
  
  /// 获取GridView的crossAxisSpacing
  static double getGridCrossAxisSpacing() {
    return spacing;
  }
  
  /// 获取GridView的mainAxisSpacing
  static double getGridMainAxisSpacing() {
    return spacing;
  }
}
