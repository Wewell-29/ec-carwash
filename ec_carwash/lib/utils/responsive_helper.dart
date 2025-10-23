import 'package:flutter/material.dart';

/// Professional responsive helper class for adaptive layouts
/// Based on Material Design breakpoints and iOS Human Interface Guidelines
class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  // Get screen dimensions
  Size get screenSize => MediaQuery.of(context).size;
  double get width => screenSize.width;
  double get height => screenSize.height;
  Orientation get orientation => MediaQuery.of(context).orientation;

  // Breakpoint definitions (Material Design 3 + iOS guidelines)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 905;
  static const double desktopBreakpoint = 1240;
  static const double largeDesktopBreakpoint = 1440;

  // Device type checks
  bool get isMobile => width < mobileBreakpoint;
  bool get isTablet => width >= mobileBreakpoint && width < desktopBreakpoint;
  bool get isDesktop => width >= desktopBreakpoint;
  bool get isLargeDesktop => width >= largeDesktopBreakpoint;

  // iPad specific checks
  bool get isIPadMini => width >= 744 && width <= 768; // iPad mini
  bool get isIPadStandard => width >= 810 && width <= 834; // iPad 10.2", iPad Air
  bool get isIPadPro11 => width >= 834 && width <= 850; // iPad Pro 11"
  bool get isIPadPro129 => width >= 1024 && width <= 1050; // iPad Pro 12.9"
  bool get isAnyIPad => isIPadMini || isIPadStandard || isIPadPro11 || isIPadPro129;

  // Orientation checks
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;

  // Grid columns calculation (intelligent)
  int get gridColumns {
    if (isMobile) {
      return isPortrait ? 2 : 3; // Mobile: 2 portrait, 3 landscape
    } else if (isTablet) {
      if (isIPadMini) {
        return isPortrait ? 4 : 6; // iPad mini: 4 portrait, 6 landscape
      } else if (isIPadStandard || isIPadPro11) {
        return isPortrait ? 5 : 7; // iPad standard: 5 portrait, 7 landscape
      } else if (isIPadPro129) {
        return isPortrait ? 6 : 8; // iPad Pro 12.9: 6 portrait, 8 landscape
      }
      // Fallback for other tablets
      return isPortrait ? 4 : 6;
    } else if (isDesktop) {
      return isLargeDesktop ? 8 : 6; // Desktop: 6-8 columns
    }
    return 4; // Default fallback
  }

  // Responsive spacing
  double get spacing {
    if (isMobile) return 8.0;
    if (isTablet) return 12.0;
    return 16.0;
  }

  double get paddingHorizontal {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  double get paddingVertical {
    if (isMobile) return 12.0;
    if (isTablet) return 16.0;
    return 20.0;
  }

  // Responsive font sizes
  double fontSize({
    double mobile = 14.0,
    double tablet = 15.0,
    double desktop = 16.0,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }

  // Card aspect ratio
  double get cardAspectRatio {
    if (isMobile) return 1.0; // Square on mobile
    if (isTablet) return 0.95; // Slightly taller on tablet
    return 0.90; // Nearly square on desktop
  }

  // Max cross axis extent for responsive grids (better than fixed columns)
  double get gridItemMaxWidth {
    if (isMobile) return 180.0;
    if (isTablet) return 160.0;
    return 200.0;
  }

  // Safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  // Bottom navigation bar height
  double get bottomNavHeight {
    if (isMobile) return 56.0;
    if (isTablet) return 64.0;
    return 72.0;
  }

  // Should use 2-pane layout (side-by-side)
  bool get shouldUse2PaneLayout => isTablet && isLandscape || isDesktop;

  // App bar height
  double get appBarHeight {
    if (isMobile) return 56.0;
    if (isTablet) return 64.0;
    return 72.0;
  }

  // Icon sizes
  double get iconSize {
    if (isMobile) return 20.0;
    if (isTablet) return 22.0;
    return 24.0;
  }

  double get iconSizeLarge {
    if (isMobile) return 32.0;
    if (isTablet) return 36.0;
    return 40.0;
  }

  // Button heights
  double get buttonHeight {
    if (isMobile) return 44.0;
    if (isTablet) return 48.0;
    return 52.0;
  }

  // Card elevation
  double get cardElevation {
    if (isMobile) return 2.0;
    if (isTablet) return 3.0;
    return 4.0;
  }

  // Border radius
  double get borderRadius {
    if (isMobile) return 8.0;
    if (isTablet) return 10.0;
    return 12.0;
  }

  // Dialog width
  double get dialogWidth {
    if (isMobile) return width * 0.9;
    if (isTablet) return 600.0;
    return 700.0;
  }

  // Max content width (for centering content on large screens)
  double get maxContentWidth {
    if (isLargeDesktop) return 1440.0;
    if (isDesktop) return 1200.0;
    return double.infinity;
  }

  // Responsive value helper
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile;
    return desktop ?? tablet ?? mobile;
  }
}

/// Extension for easy access
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
