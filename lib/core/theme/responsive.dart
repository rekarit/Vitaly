import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// RESPONSIVE BREAKPOINTS & TYPOLOGY
/// ──────────────────────────────────────────────────────────────────────────
enum DeviceScreenType { compact, medium, expanded, large, ultraWide }

class ResponsiveBreakpoints {
  static const double mobile = 680.0;     // compact < 680
  static const double tablet = 1024.0;    // medium 680 - 1024
  static const double desktop = 1440.0;   // expanded 1024 - 1440
  static const double ultraWide = 1600.0; // large 1440 - 1600, ultraWide > 1600
}

/// ──────────────────────────────────────────────────────────────────────────
/// BUILD CONTEXT EXTENSIONS
/// Quick, clean responsive getters available anywhere in the widget tree.
/// ──────────────────────────────────────────────────────────────────────────
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  DeviceScreenType get deviceScreenType {
    final w = screenWidth;
    if (w < ResponsiveBreakpoints.mobile) return DeviceScreenType.compact;
    if (w < ResponsiveBreakpoints.tablet) return DeviceScreenType.medium;
    if (w < ResponsiveBreakpoints.desktop) return DeviceScreenType.expanded;
    if (w < ResponsiveBreakpoints.ultraWide) return DeviceScreenType.large;
    return DeviceScreenType.ultraWide;
  }

  bool get isMobile => deviceScreenType == DeviceScreenType.compact;
  bool get isTablet => deviceScreenType == DeviceScreenType.medium;
  bool get isDesktop =>
      deviceScreenType == DeviceScreenType.expanded ||
      deviceScreenType == DeviceScreenType.large ||
      deviceScreenType == DeviceScreenType.ultraWide;
  bool get isUltraWide => deviceScreenType == DeviceScreenType.ultraWide;

  /// True for very small phones (< 360 px wide)
  bool get isCompactPhone => screenWidth < 360;

  /// Retrieves a value depending on the current screen size.
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultraWide,
  }) {
    if (isUltraWide && ultraWide != null) return ultraWide;
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Provides standardized horizontal padding based on screen size
  EdgeInsets get responsiveHorizontalPadding {
    return EdgeInsets.symmetric(
      horizontal: responsiveValue<double>(
        mobile: 12.0,
        tablet: 20.0,
        desktop: 28.0,
      ),
    );
  }

  /// Content padding suitable for list cards / tiles
  EdgeInsets get responsiveCardPadding {
    return EdgeInsets.symmetric(
      horizontal: responsiveValue<double>(mobile: 14.0, tablet: 18.0, desktop: 22.0),
      vertical: responsiveValue<double>(mobile: 12.0, tablet: 14.0, desktop: 16.0),
    );
  }

  /// Minimum touch target height (Material spec: 48 logical px)
  double get minTouchTarget => isMobile ? 48.0 : 40.0;

  /// Font scale factor — slightly smaller on tiny phones
  double get fontScale => isCompactPhone ? 0.9 : 1.0;

  /// Horizontal padding for screen-edge containers
  double get screenPadding => responsiveValue<double>(mobile: 12.0, tablet: 20.0, desktop: 28.0);
}

/// ──────────────────────────────────────────────────────────────────────────
/// RESPONSIVE LAYOUT WIDGET
/// Declarative widget to easily split UI rendering based on screen class.
/// ──────────────────────────────────────────────────────────────────────────
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      return desktop;
    } else if (context.isTablet) {
      return tablet ?? desktop;
    } else {
      return mobile;
    }
  }
}

/// ──────────────────────────────────────────────────────────────────────────
/// RESPONSIVE WRAPPER
/// Constrains extremely wide content on ultra-wide screens to maintain readability.
/// ──────────────────────────────────────────────────────────────────────────
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1600.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
/// ADAPTIVE DIALOGS
/// Helper class to render dialogs perfectly on mobile vs desktop.
/// ──────────────────────────────────────────────────────────────────────────
class AdaptiveDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final isMobile = mq.size.width < ResponsiveBreakpoints.mobile;
        // Remaining vertical height after keyboard opens and safe area
        final remainingHeight = mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (isMobile ? 16 : 48);
        final maxH = remainingHeight.clamp(260.0, 920.0);
        final maxW = isMobile ? (mq.size.width - 16).clamp(280.0, 600.0) : 600.0;

        return AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: mq.viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuad,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxH,
                maxWidth: maxW,
              ),
              child: builder(ctx),
            ),
          ),
        );
      },
    );
  }
}
