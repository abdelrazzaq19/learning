import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/Exam/exam_screen.dart';
import 'package:online_cource_app/theme/app_theme.dart';

/// Regression tests for the `late` fields that used to throw
/// LateInitializationError when a screen was disposed before its async
/// initialisation finished.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: child,
      );

  testWidgets('leaving an exam before the questions load does not throw',
      (tester) async {
    await tester.pumpWidget(host(const ExamScreen(
      questionPath: 'images/never_resolves.json',
      userName: 'Ada',
      userEmail: 'ada@example.com',
      examName: 'Basics',
    )));

    // Dispose immediately: the questions future has not completed, so the
    // countdown timer was never started.
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an exam whose questions fail to load shows an error, not a spinner',
      (tester) async {
    await tester.pumpWidget(host(const ExamScreen(
      questionPath: 'images/does_not_exist.json',
      userName: 'Ada',
      userEmail: 'ada@example.com',
      examName: 'Missing',
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(const SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
