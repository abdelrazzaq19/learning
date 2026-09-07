import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';

const _uid = 'user-1';

CourseModel _course({String id = 'c1', String title = 'Flutter Basics'}) =>
    CourseModel(
      id: id,
      title: title,
      cover: 'https://example.com/$id.png',
      duration: '4 weeks',
      instructors: const ['Ada'],
      price: 1400,
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late EnrollmentRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = EnrollmentRepository(firestore: firestore);

    await firestore.collection('courses').doc('c1').set(_course().toJson());
    await firestore
        .collection('courses')
        .doc('c2')
        .set(_course(id: 'c2', title: 'Web Design').toJson());
  });

  Future<Map<String, dynamic>?> enrollmentDoc(String courseId) async {
    final doc = await firestore
        .collection('users')
        .doc(_uid)
        .collection('enrolledCourses')
        .doc(courseId)
        .get();
    return doc.data();
  }

  group('enroll', () {
    test('writes one document keyed by course id', () async {
      await repository.enroll(uid: _uid, course: _course());

      final data = await enrollmentDoc('c1');
      expect(data, isNotNull);
      expect(data!['courseId'], 'c1');
      expect(data['progress'], 0.0);
      expect(data['price'], 1400);
      expect(data['title'], 'Flutter Basics',
          reason: 'denormalised so My Learning renders without a second read');
    });

    test('increments the course enrollmentCount', () async {
      await repository.enroll(uid: _uid, course: _course());

      final course = await firestore.collection('courses').doc('c1').get();
      expect(course.data()!['enrollmentCount'], 1);
    });

    test('is idempotent: enrolling twice does not double-count', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.enroll(uid: _uid, course: _course());

      final course = await firestore.collection('courses').doc('c1').get();
      expect(course.data()!['enrollmentCount'], 1);

      final all = await repository.streamEnrolledCourses(_uid).first;
      expect(all, hasLength(1));
    });

    test('re-enrolling does not reset existing progress', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.updateProgress(
          uid: _uid, courseId: 'c1', progress: 0.5, lastLessonId: 'l2');

      await repository.enroll(uid: _uid, course: _course());

      final data = await enrollmentDoc('c1');
      expect(data!['progress'], 0.5);
      expect(data['lastLessonId'], 'l2');
    });

    test('throws when the course has no id', () async {
      expect(
        () => repository.enroll(uid: _uid, course: _course().copyWith(id: '')),
        throwsArgumentError,
      );
    });
  });

  group('reads', () {
    test('isEnrolled reflects state', () async {
      expect(await repository.isEnrolled(uid: _uid, courseId: 'c1'), isFalse);
      await repository.enroll(uid: _uid, course: _course());
      expect(await repository.isEnrolled(uid: _uid, courseId: 'c1'), isTrue);
    });

    test('isEnrolled is false for a blank course id', () async {
      expect(await repository.isEnrolled(uid: _uid, courseId: ''), isFalse);
    });

    test('streamEnrolledCourses returns courses with their ids', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.enroll(uid: _uid, course: _course(id: 'c2'));

      final courses = await repository.streamEnrolledCourses(_uid).first;

      expect(courses.map((c) => c.id), containsAll(['c1', 'c2']));
    });

    test('streamEnrollments exposes progress', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.updateProgress(
          uid: _uid, courseId: 'c1', progress: 0.75);

      final enrollments = await repository.streamEnrollments(_uid).first;

      expect(enrollments.single.progress, 0.75);
      expect(enrollments.single.course.title, 'Flutter Basics');
      expect(enrollments.single.isComplete, isFalse);
    });

    test('an empty uid yields an empty stream, not an error', () async {
      expect(await repository.streamEnrolledCourses('').first, isEmpty);
    });
  });

  group('progress', () {
    test('clamps to the 0..1 range', () async {
      await repository.enroll(uid: _uid, course: _course());

      await repository.updateProgress(uid: _uid, courseId: 'c1', progress: 5);
      expect((await enrollmentDoc('c1'))!['progress'], 1.0);

      await repository.updateProgress(uid: _uid, courseId: 'c1', progress: -2);
      expect((await enrollmentDoc('c1'))!['progress'], 0.0);
    });

    test('marks completion at 100%', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.updateProgress(uid: _uid, courseId: 'c1', progress: 1.0);

      final enrollments = await repository.streamEnrollments(_uid).first;
      expect(enrollments.single.isComplete, isTrue);
      expect((await enrollmentDoc('c1'))!['completedAt'], isNotNull);
    });

    test('is a no-op when the user is not enrolled', () async {
      await repository.updateProgress(
          uid: _uid, courseId: 'ghost', progress: 0.5);

      expect(await enrollmentDoc('ghost'), isNull);
    });
  });

  group('legacy migration', () {
    Future<void> seedLegacy() async {
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('enrollment')
          .add(_course().toJson()..['id'] = 'c1');
    }

    test('upserts legacy enrollment docs into the canonical collection',
        () async {
      await seedLegacy();

      final migrated = await repository.migrateLegacyEnrollments(_uid);

      expect(migrated, 1);
      expect(await repository.isEnrolled(uid: _uid, courseId: 'c1'), isTrue);
    });

    test('never deletes the legacy documents', () async {
      await seedLegacy();
      await repository.migrateLegacyEnrollments(_uid);

      final legacy = await firestore
          .collection('users')
          .doc(_uid)
          .collection('enrollment')
          .get();
      expect(legacy.docs, hasLength(1));
    });

    test('runs once: the flag stops a second pass', () async {
      await seedLegacy();
      expect(await repository.migrateLegacyEnrollments(_uid), 1);
      expect(await repository.migrateLegacyEnrollments(_uid), 0);
    });

    test('does not overwrite progress already recorded canonically', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.updateProgress(
          uid: _uid, courseId: 'c1', progress: 0.9);
      await seedLegacy();

      await repository.migrateLegacyEnrollments(_uid);

      expect((await enrollmentDoc('c1'))!['progress'], 0.9);
    });

    test('is a no-op for a user with no legacy docs', () async {
      expect(await repository.migrateLegacyEnrollments(_uid), 0);
    });
  });

  group('unenroll', () {
    test('removes the enrollment and decrements the count', () async {
      await repository.enroll(uid: _uid, course: _course());
      await repository.unenroll(uid: _uid, courseId: 'c1');

      expect(await repository.isEnrolled(uid: _uid, courseId: 'c1'), isFalse);
      final course = await firestore.collection('courses').doc('c1').get();
      expect(course.data()!['enrollmentCount'], 0);
    });
  });
}
