import 'package:flutter/material.dart';

/// A widget that animates its children when the theme changes
class ThemeTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ThemeTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  State<ThemeTransition> createState() => _ThemeTransitionState();
}

class _ThemeTransitionState extends State<ThemeTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ThemeData _oldTheme;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    
    if (!_initialized) {
      _oldTheme = theme;
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
        value: 1.0, // Start fully visible
      );
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      );
      _initialized = true;
    } else if (_oldTheme.brightness != theme.brightness) {
      _oldTheme = theme;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always show the child initially, only animate during theme changes
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// Extension to check if the theme is dark
extension ThemeExtension on ThemeData {
  bool get isDark => brightness == Brightness.dark;
} 