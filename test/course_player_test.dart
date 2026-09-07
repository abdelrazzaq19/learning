import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_cource_app/Courses/course_player.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/data/lesson_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';

const _uid = 'user-1';

const _course = CourseModel(
  id: 'c1',
  title: 'Flutter Basics',
  cover: '',
  duration: '4 weeks',
  instructors: ['Ada'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeFirebaseFirestore firestore;
  late LessonRepository lessons;
  late EnrollmentRepository enrollments;

  Future<void> seedLessons() async {
    final collection =
        firestore.collection('courses').doc('c1').collection('lessons');
    await collection.doc('l3').set({
      'title': 'State Management',
      'videoUrl': 'https://example.com/3.mp4',
      'order': 3,
      'durationSeconds': 900,
    });
    await collection.doc('l1').set({
      'title': 'Setup',
      'videoUrl': 'https://example.com/1.mp4',
      'order': 1,
      'durationSeconds': 300,
    });
    await collection.doc('l2').set({
      'title': 'Widgets',
      'videoUrl': 'https://example.com/2.mp4',
      'order': 2,
      'durationSeconds': 600,
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    lessons = LessonRepository(firestore: firestore);
    enrollments = EnrollmentRepository(firestore: firestore);
    await firestore.collection('courses').doc('c1').set(_course.toJson());
  });

  Widget host() => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: CoursePlayerPage(
          course: _course,
          lessonRepository: lessons,
          enrollmentRepository: enrollments,
          uid: _uid,
        ),
      );

  testWidgets('lists the course lessons in teaching order', (tester) async {
    await seedLessons();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.byKey(const Key('lesson_title')))
        .map((t) => t.data)
        .toList();
    expect(titles, ['Setup', 'Widgets', 'State Management']);
  });

  testWidgets('shows each lesson runtime', (tester) async {
    await seedLessons();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('a course with no lessons shows an empty state, not a player',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('No lessons'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a lesson selects it', (tester) async {
    await seedLessons();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Widgets'));
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    expect(state.selectedLesson?.title, 'Widgets');
  });

  testWidgets('the first lesson is selected on open', (tester) async {
    await seedLessons();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    expect(state.selectedLesson?.title, 'Setup');
  });

  testWidgets('resumes at the last watched lesson', (tester) async {
    await seedLessons();
    await enrollments.enroll(uid: _uid, course: _course);
    await enrollments.updateProgress(
        uid: _uid, courseId: 'c1', progress: 0.33, lastLessonId: 'l2');

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    expect(state.selectedLesson?.id, 'l2');
  });

  testWidgets('a lesson without a video URL is reported, not silently blank',
      (tester) async {
    await firestore
        .collection('courses')
        .doc('c1')
        .collection('lessons')
        .doc('l1')
        .set({'title': 'Reading only', 'order': 1});

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('no video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marking a lesson complete writes progress and the resume point',
      (tester) async {
    await seedLessons();
    await enrollments.enroll(uid: _uid, course: _course);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    await state.markLessonComplete(state.selectedLesson!);
    await tester.pumpAndSettle();

    final enrollment =
        await enrollments.getEnrollment(uid: _uid, courseId: 'c1');
    // One of three lessons done.
    expect(enrollment!.progress, closeTo(1 / 3, 0.001));
    expect(enrollment.lastLessonId, 'l1');
  });

  testWidgets('completing every lesson marks the course complete',
      (tester) async {
    await seedLessons();
    await enrollments.enroll(uid: _uid, course: _course);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    for (final lesson in state.lessons) {
      await state.markLessonComplete(lesson);
    }
    await tester.pumpAndSettle();

    final enrollment =
        await enrollments.getEnrollment(uid: _uid, courseId: 'c1');
    expect(enrollment!.isComplete, isTrue);
  });

  testWidgets('completing the same lesson twice does not inflate progress',
      (tester) async {
    await seedLessons();
    await enrollments.enroll(uid: _uid, course: _course);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    await state.markLessonComplete(state.selectedLesson!);
    await state.markLessonComplete(state.selectedLesson!);
    await tester.pumpAndSettle();

    final enrollment =
        await enrollments.getEnrollment(uid: _uid, courseId: 'c1');
    expect(enrollment!.progress, closeTo(1 / 3, 0.001));
  });

  testWidgets('a completed lesson is shown as done in the list', (tester) async {
    await seedLessons();
    await enrollments.enroll(uid: _uid, course: _course);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    await state.markLessonComplete(state.selectedLesson!);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('progress is not written for a user who is not enrolled',
      (tester) async {
    await seedLessons();

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = tester.state<CoursePlayerPageState>(
      find.byType(CoursePlayerPage),
    );
    await state.markLessonComplete(state.selectedLesson!);
    await tester.pumpAndSettle();

    expect(await enrollments.getEnrollment(uid: _uid, courseId: 'c1'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark theme without throwing', (tester) async {
    await seedLessons();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: CoursePlayerPage(
        course: _course,
        lessonRepository: lessons,
        enrollmentRepository: enrollments,
        uid: _uid,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
