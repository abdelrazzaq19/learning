import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:online_cource_app/auth_gate.dart';
import 'package:online_cource_app/controllers/auth_controller.dart';
import 'package:online_cource_app/firebase_options.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register controllers
  Get.lazyPut(() => AuthController(), fenix: true);

  // Theme preference must be known before the first frame to avoid a flash.
  final themeController = Get.put(ThemeController(), permanent: true);
  await themeController.load();

  // Configure EasyLoading
  configureEasyLoading(themeController.themeMode);

  runApp(const MyApp());
}

void configureEasyLoading(ThemeMode mode) {
  final isDark = mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  final surface = isDark ? AppTheme.darkCardColor : Colors.white;
  final onSurface = isDark ? AppTheme.darkTextColor : AppTheme.textColor;

  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 16.0
    ..progressColor = AppTheme.primaryColor
    ..backgroundColor = surface
    ..indicatorColor = AppTheme.primaryColor
    ..textColor = onSurface
    ..maskColor = Colors.black.withValues(alpha: 0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'E-Learning App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: Get.find<ThemeController>().themeMode,
      home: const AuthGate(),
      builder: EasyLoading.init(),
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
