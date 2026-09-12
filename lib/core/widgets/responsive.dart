import 'package:flutter/widgets.dart';

/// Layout breakpoints (logical pixels / dp).
///
/// * `< 600`  – phone: bottom navigation, single column.
/// * `600–1024` – tablet: navigation rail, two columns.
/// * `≥ 1024` – large tablet / landscape: extended rail, wider content.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double large = 1024;

  /// Max width of centered content on big screens (forms, profile...).
  static const double contentMaxWidth = 960;
  static const double formMaxWidth = 460;
}

/// Screen-size helpers used for phone/tablet layouts.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isPhone => screenWidth < Breakpoints.tablet;
  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isLargeScreen => screenWidth >= Breakpoints.large;

  /// Horizontal page padding that grows with the screen.
  double get pagePadding => isLargeScreen ? 32 : (isTablet ? 24 : 16);

  /// Number of grid columns for card lists.
  int gridColumns({int phone = 1, int tablet = 2, int large = 3}) =>
      isLargeScreen ? large : (isTablet ? tablet : phone);
}

/// Centers [child] and limits its width on tablets.
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
