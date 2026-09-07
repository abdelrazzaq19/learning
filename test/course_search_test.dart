import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/Courses/course_search.dart';
import 'package:online_cource_app/data/bookmark_repository.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeFirebaseFirestore firestore;
  late CourseRepository courses;
  late BookmarkRepository bookmarks;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    courses = CourseRepository(firestore: firestore);
    bookmarks = BookmarkRepository(firestore: firestore);

    await firestore.collection('courses').doc('c1').set({
      'title': 'Flutter Basics',
      'titleLower': 'flutter basics',
      'cover': '',
      'duration': '4 weeks',
      'instructor': ['Ada'],
      'category': 'Mobile',
    });
    await firestore.collection('courses').doc('c2').set({
      'title': 'Web Design',
      'titleLower': 'web design',
      'cover': '',
      'duration': '2 weeks',
      'instructor': ['Grace'],
      'category': 'Design',
    });
  });

  Widget host() => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: CourseSearchPage(
          courseRepository: courses,
          bookmarkRepository: bookmarks,
          uid: 'user-1',
        ),
      );

  testWidgets('opens with a prompt, not an empty list', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('Search'), findsWidgets);
  });

  testWidgets('typing a query shows the matching course only', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField), 'flut');

    // Debounced: nothing runs immediately.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Flutter Basics'), findsOneWidget);
    expect(find.text('Web Design'), findsNothing);
  });

  testWidgets('a query with no matches shows the no-results state',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('No courses match'), findsOneWidget);
  });

  testWidgets('search matches an instructor name too', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField), 'grace');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Web Design'), findsOneWidget);
  });

  testWidgets('tapping a category filters the list', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Design'));
    await tester.pumpAndSettle();

    expect(find.text('Web Design'), findsOneWidget);
    expect(find.text('Flutter Basics'), findsNothing);
  });

  testWidgets('tapping the selected category again clears the filter',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Design'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Design'));
    await tester.pumpAndSettle();

    expect(find.text('Web Design'), findsOneWidget);
    expect(find.text('Flutter Basics'), findsOneWidget);
  });

  testWidgets('bookmarking from the results persists', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border).first);
    await tester.pumpAndSettle();

    expect(await bookmarks.streamBookmarks('user-1').first, hasLength(1));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
