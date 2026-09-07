import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Tests have no network; never try to fetch Poppins from the CDN.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppTheme', () {
    test('light theme builds with Material 3 and a light scheme', () {
      final theme = AppTheme.lightTheme();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('dark theme builds with Material 3 and a dark scheme', () {
      final theme = AppTheme.darkTheme();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('light and dark differ in surface but share the seed', () {
      final light = AppTheme.lightTheme();
      final dark = AppTheme.darkTheme();
      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
      expect(AppTheme.seedColor, isNotNull);
    });

    test('both themes define the typography used across screens', () {
      for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
        expect(theme.textTheme.titleMedium, isNotNull);
        expect(theme.textTheme.headlineSmall, isNotNull);
        expect(theme.textTheme.bodyMedium, isNotNull);
      }
    });
  });

  group('ThemeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to system mode', () async {
      final controller = ThemeController();
      await controller.load();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('persists the selected mode across instances', () async {
      final controller = ThemeController();
      await controller.load();
      await controller.setMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);

      final reloaded = ThemeController();
      await reloaded.load();
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    test('toggle flips between light and dark', () async {
      final controller = ThemeController();
      await controller.load();
      await controller.setMode(ThemeMode.light);
      await controller.toggle();
      expect(controller.themeMode, ThemeMode.dark);
      await controller.toggle();
      expect(controller.themeMode, ThemeMode.light);
    });
  });
}
