import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_cource_app/Model/lesson_model.dart';
import 'package:online_cource_app/data/lesson_repository.dart';
import 'package:online_cource_app/data/user_repository.dart';

void main() {
  group('LessonRepository', () {
    late FakeFirebaseFirestore firestore;
    late LessonRepository repository;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = LessonRepository(firestore: firestore);

      final lessons = firestore.collection('courses').doc('c1').collection('lessons');
      await lessons.doc('l2').set({
        'title': 'Widgets',
        'videoUrl': 'https://example.com/2.mp4',
        'order': 2,
        'durationSeconds': 600,
      });
      await lessons.doc('l1').set({
        'title': 'Setup',
        'videoUrl': 'https://example.com/1.mp4',
        'order': 1,
        'durationSeconds': 300,
      });
    });

    test('streamLessons returns lessons ordered by order, with ids', () async {
      final lessons = await repository.streamLessons('c1').first;

      expect(lessons.map((l) => l.id).toList(), ['l1', 'l2']);
      expect(lessons.first.title, 'Setup');
    });

    test('streamLessons is empty for a course with none', () async {
      expect(await repository.streamLessons('nope').first, isEmpty);
    });

    test('streamLessons for a blank course id yields empty, not an error',
        () async {
      expect(await repository.streamLessons('').first, isEmpty);
    });

    test('addLesson stores the lesson and returns its id', () async {
      final id = await repository.addLesson(
        'c1',
        const LessonModel(
          title: 'Testing',
          videoUrl: 'https://example.com/3.mp4',
          order: 3,
          durationSeconds: 900,
        ),
      );

      final lessons = await repository.streamLessons('c1').first;
      expect(lessons, hasLength(3));
      expect(lessons.last.id, id);
      expect(lessons.last.title, 'Testing');
    });

    test('totalDuration sums lesson durations', () async {
      expect(await repository.totalDurationSeconds('c1'), 900);
    });

    test('updateLesson changes the stored fields', () async {
      await repository.updateLesson(
        'c1',
        'l1',
        const LessonModel(
          title: 'Setup (revised)',
          videoUrl: 'https://example.com/1b.mp4',
          order: 1,
          durationSeconds: 420,
        ),
      );

      final lessons = await repository.streamLessons('c1').first;
      expect(lessons.first.title, 'Setup (revised)');
      expect(lessons.first.durationSeconds, 420);
    });

    test('deleteLesson removes it', () async {
      await repository.deleteLesson('c1', 'l1');

      final lessons = await repository.streamLessons('c1').first;
      expect(lessons.map((l) => l.id), isNot(contains('l1')));
      expect(lessons, hasLength(1));
    });

    test('nextOrder follows the highest existing order', () async {
      expect(await repository.nextOrder('c1'), 3);
    });

    test('nextOrder starts at 1 for a course with no lessons', () async {
      expect(await repository.nextOrder('empty'), 1);
    });

    test('syncLessonCount writes the count onto the course', () async {
      await firestore.collection('courses').doc('c1').set({'title': 'C'});

      await repository.syncLessonCount('c1');

      final course = await firestore.collection('courses').doc('c1').get();
      expect(course.data()!['lessonCount'], 2);
    });

    test('a malformed lesson document degrades instead of throwing', () async {
      await firestore
          .collection('courses')
          .doc('c1')
          .collection('lessons')
          .doc('bad')
          // Missing title/videoUrl: the parser must supply fallbacks.
          .set({'order': 99});

      final lessons = await repository.streamLessons('c1').first;
      expect(lessons, hasLength(3));
      expect(lessons.firstWhere((l) => l.id == 'bad').title, isNotEmpty);
    });
  });

  group('UserRepository', () {
    late FakeFirebaseFirestore firestore;
    late UserRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = UserRepository(firestore: firestore);
    });

    test('ensureUserDocument creates the doc when it is missing', () async {
      await repository.ensureUserDocument(
        uid: 'u1',
        email: 'a@b.com',
        name: 'Ada',
      );

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['email'], 'a@b.com');
      expect(doc.data()!['role'], 'student');
    });

    test('ensureUserDocument merges instead of overwriting', () async {
      await firestore.collection('users').doc('u1').set({
        'name': 'Ada',
        'role': 'admin',
      });

      await repository.ensureUserDocument(
        uid: 'u1',
        email: 'a@b.com',
        name: 'Ada Lovelace',
      );

      final data = (await firestore.collection('users').doc('u1').get()).data()!;
      expect(data['role'], 'admin', reason: 'an existing role must survive');
      expect(data['name'], 'Ada Lovelace');
    });

    test('touchLastLogin does not throw when the doc does not exist yet',
        () async {
      await repository.touchLastLogin('ghost');

      final doc = await firestore.collection('users').doc('ghost').get();
      expect(doc.exists, isTrue);
    });

    test('updateProfile merges fields and stamps updatedAt', () async {
      await repository.ensureUserDocument(uid: 'u1', email: 'a@b.com', name: 'Ada');

      await repository.updateProfile('u1', {'name': 'Ada Lovelace'});

      final data = await repository.getUser('u1');
      expect(data['name'], 'Ada Lovelace');
      expect(data['email'], 'a@b.com', reason: 'other fields must survive');
      expect(data['updatedAt'], isNotNull);
    });

    test('updateProfile does not resurrect a deleted role', () async {
      await repository.ensureUserDocument(uid: 'u1', email: 'a@b.com');
      await repository.updateProfile('u1', {'name': 'Ada'});

      expect((await repository.getUser('u1'))['role'], 'student');
    });

    test('streamUser emits the profile', () async {
      await repository.ensureUserDocument(uid: 'u1', email: 'a@b.com', name: 'Ada');

      final data = await repository.streamUser('u1').first;
      expect(data['name'], 'Ada');
    });

    test('isAdmin reflects the stored role', () async {
      await repository.ensureUserDocument(uid: 'u1', email: 'a@b.com');
      expect(await repository.isAdmin('u1'), isFalse);

      await firestore.collection('users').doc('u2').set({'role': 'admin'});
      expect(await repository.isAdmin('u2'), isTrue);
    });
  });
}
