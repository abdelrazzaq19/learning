import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark
        ? AppTheme.darkTheme()
        : AppTheme.lightTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('AppEmptyState shows message and fires its action',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(AppEmptyState(
      title: 'No courses',
      message: 'Enroll to get started.',
      actionLabel: 'Browse',
      onAction: () => tapped = true,
    )));

    expect(find.text('No courses'), findsOneWidget);
    expect(find.text('Enroll to get started.'), findsOneWidget);
    await tester.tap(find.text('Browse'));
    expect(tapped, isTrue);
  });

  testWidgets('AppErrorState offers retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_host(AppErrorState(
      message: 'boom',
      onRetry: () => retried = true,
    )));

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('AsyncView renders loading, then data', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(_host(AsyncView<List<String>>(
      stream: controller.stream,
      builder: (_, data) => Text(data.first),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add(['Flutter Basics']);
    await tester.pump();
    expect(find.text('Flutter Basics'), findsOneWidget);
  });

  testWidgets('AsyncView renders the empty state for an empty list',
      (tester) async {
    await tester.pumpWidget(_host(AsyncView<List<String>>(
      future: Future.value(const <String>[]),
      empty: const AppEmptyState(message: 'No results'),
      builder: (_, data) => Text(data.first),
    )));
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('AsyncView renders the error state and retries', (tester) async {
    var retried = false;
    final completer = Completer<List<String>>();
    await tester.pumpWidget(_host(AsyncView<List<String>>(
      future: completer.future,
      onRetry: () => retried = true,
      builder: (_, data) => Text(data.first),
    )));
    completer.completeError(Exception('nope'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('states render in dark theme without overflow', (tester) async {
    await tester.pumpWidget(_host(
      const AppEmptyState(message: 'Dark empty'),
      brightness: Brightness.dark,
    ));
    expect(find.text('Dark empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
