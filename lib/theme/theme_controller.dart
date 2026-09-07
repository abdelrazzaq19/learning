import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the app's light/dark preference and persists it across launches.
///
/// Registered in `main()` and read by `GetMaterialApp.themeMode`.
class ThemeController extends GetxController {
  static const String _prefsKey = 'theme_mode';

  final Rx<ThemeMode> _mode = ThemeMode.system.obs;

  ThemeMode get themeMode => _mode.value;

  /// Reactive accessor for widgets that rebuild inside an [Obx].
  Rx<ThemeMode> get mode => _mode;

  bool isDark(BuildContext context) {
    if (_mode.value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode.value == ThemeMode.dark;
  }

  /// Reads the stored preference. Safe to call before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode.value = _decode(prefs.getString(_prefsKey));
    } catch (e) {
      debugPrint('ThemeController.load failed, using system theme: $e');
      _mode.value = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode.value = mode;
    Get.changeThemeMode(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (e) {
      debugPrint('ThemeController.setMode failed to persist: $e');
    }
  }

  /// Flips light <-> dark. From system, resolves against the platform first.
  Future<void> toggle() async {
    switch (_mode.value) {
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.light);
      case ThemeMode.system:
        final platformIsDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
        await setMode(platformIsDark ? ThemeMode.light : ThemeMode.dark);
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
