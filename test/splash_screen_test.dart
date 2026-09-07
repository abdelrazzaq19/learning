import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/Splash/splash_screen.dart';
import 'package:online_cource_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget host({
    required Widget next,
    Brightness brightness = Brightness.light,
    Duration minimumDuration = const Duration(milliseconds: 100),
  }) =>
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme()
            : AppTheme.lightTheme(),
        home: SplashScreen(
          minimumDuration: minimumDuration,
          nextScreenBuilder: () => next,
        ),
      );

  testWidgets('shows the app name while starting up', (tester) async {
    await tester.pumpWidget(host(next: const Text('HOME')));
    await tester.pump();

    expect(find.text('E-Learning'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('hands over to the next screen once the delay elapses',
      (tester) async {
    await tester.pumpWidget(host(next: const Text('HOME')));

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('HOME'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('animates the logo in rather than popping it', (tester) async {
    await tester.pumpWidget(host(next: const Text('HOME')));
    await tester.pump(const Duration(milliseconds: 16));

    final opacity = tester.widget<FadeTransition>(
      find.byKey(const Key('splash_fade')),
    );
    expect(opacity.opacity.value, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 700));
    expect(opacity.opacity.value, 1.0);
  });

  testWidgets('does not navigate after being disposed', (tester) async {
    await tester.pumpWidget(host(next: const Text('HOME')));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark theme without throwing', (tester) async {
    await tester.pumpWidget(
      host(next: const Text('HOME'), brightness: Brightness.dark),
    );
    await tester.pump();

    expect(find.text('E-Learning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
