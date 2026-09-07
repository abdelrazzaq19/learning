import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/Home/home_presentation.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/course_card.dart';

CourseModel _course({
  String id = 'c1',
  String title = 'Flutter Basics',
  double price = 50,
  int lessonCount = 8,
}) =>
    CourseModel(
      id: id,
      title: title,
      cover: 'https://example.com/$id.png',
      duration: '4 weeks',
      instructors: const ['Ada'],
      price: price,
      lessonCount: lessonCount,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('greetingFor', () {
    test('changes with the hour', () {
      expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good Morning');
      expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good Afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 20)), 'Good Evening');
    });
  });

  group('firstNameOf', () {
    test('takes the first word of a display name', () {
      expect(firstNameOf('Ada Lovelace'), 'Ada');
    });

    test('falls back to Student for blank or null names', () {
      expect(firstNameOf(null), 'Student');
      expect(firstNameOf(''), 'Student');
      expect(firstNameOf('   '), 'Student');
    });
  });

  group('formatPrice', () {
    test('renders one currency symbol, not two', () {
      // The old Home interpolated "৳${price}" over a price that was already
      // the string "$50", printing "৳$50".
      expect(formatPrice(50), '৳50');
      expect(formatPrice(1400.5), '৳1,400.50');
    });

    test('shows Free rather than a zero price', () {
      expect(formatPrice(0), 'Free');
    });
  });

  group('formatLessonCount', () {
    test('never renders "null lessons"', () {
      expect(formatLessonCount(0), isNot(contains('null')));
      expect(formatLessonCount(0), 'Self-paced');
      expect(formatLessonCount(1), '1 lesson');
      expect(formatLessonCount(8), '8 lessons');
    });
  });

  group('CourseGridCard', () {
    Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme()
              : AppTheme.lightTheme(),
          home: Scaffold(body: child),
        );

    testWidgets('renders title, price and lesson count', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(width: 200, height: 260, child: CourseGridCard(course: _course())),
      ));

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('৳50'), findsOneWidget);
      expect(find.text('8 lessons'), findsOneWidget);
    });

    testWidgets('a course with no lessons shows no "null"', (tester) async {
      await tester.pumpWidget(host(SizedBox(
        width: 200,
        height: 260,
        child: CourseGridCard(course: _course(lessonCount: 0, price: 0)),
      )));

      expect(find.text('Self-paced'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(SizedBox(
        width: 200,
        height: 260,
        child: CourseGridCard(course: _course(), onTap: () => tapped = true),
      )));

      await tester.tap(find.byType(CourseGridCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders in dark theme without overflowing', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(width: 200, height: 260, child: CourseGridCard(course: _course())),
        brightness: Brightness.dark,
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('ContinueLearningCard', () {
    testWidgets('shows real progress, not a fabricated percentage',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 160,
            child: ContinueLearningCard(
              enrollment: Enrollment(course: _course(), progress: 0.42),
            ),
          ),
        ),
      ));

      expect(find.text('42% complete'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsOneWidget);
    });
  });
}
