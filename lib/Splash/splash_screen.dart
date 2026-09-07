import 'dart:async';

import 'package:flutter/material.dart';
import 'package:online_cource_app/auth_gate.dart';
import 'package:online_cource_app/theme/app_theme.dart';

/// In-app splash shown after the native splash hands over.
///
/// The native splash (flutter_native_splash) covers engine startup; this one
/// covers the moment between the first Flutter frame and Firebase reporting an
/// auth state, so the app never flashes an empty scaffold.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minimumDuration = const Duration(milliseconds: 1600),
    this.nextScreenBuilder,
  });

  /// How long to hold the splash before moving on. Kept short: this is a
  /// hand-off, not a brand advert.
  final Duration minimumDuration;

  /// Overridable for tests; production continues to [AuthGate].
  final Widget Function()? nextScreenBuilder;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.85,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();

    // Nullable timer + mounted check: the screen can be torn down before it
    // fires (the same pattern that used to crash the exam screen).
    _timer = Timer(widget.minimumDuration, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;

    final next = widget.nextScreenBuilder?.call() ?? const AuthGate();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF161A22), Color(0xFF121418)]
                : const [Color(0xFFFFFFFF), Color(0xFFF5F9FC)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            key: const Key('splash_fade'),
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor
                              .withValues(alpha: isDark ? 0.25 : 0.15),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        size: 96,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  Text('E-Learning', style: theme.textTheme.displayMedium),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Learn at your own pace',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
