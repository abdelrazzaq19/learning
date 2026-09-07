import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/course_repository.dart';

void main() {
  group('CourseModel', () {
    test('fromDoc carries the document id', () {
      final firestore = FakeFirebaseFirestore();
      firestore.collection('courses').doc('abc123').set({
        'title': 'Flutter Basics',
        'cover': 'https://example.com/c.png',
        'duration': '4 weeks',
        'instructor': ['Ada'],
      });

      return firestore.collection('courses').doc('abc123').get().then((doc) {
        final course = CourseModel.fromDoc(doc);
        expect(course.id, 'abc123');
        expect(course.title, 'Flutter Basics');
        expect(course.instructors, ['Ada']);
      });
    });

    test('parses a malformed document without throwing', () {
      final course = CourseModel.fromJson({
        'title': 42, // wrong type
        'cover': null,
        'instructor': 'not-a-list',
        'price': 'free',
      });

      expect(course.title, isNotEmpty);
      expect(course.cover, isA<String>());
      expect(course.duration, isA<String>());
      expect(course.instructors, isEmpty);
      expect(course.price, 0.0);
    });

    test('price defaults to 0.0 in both the constructor and the parser', () {
      expect(
        const CourseModel(cover: '', duration: '', instructors: [], title: 't').price,
        0.0,
      );
      expect(CourseModel.fromJson(const {'title': 't'}).price, 0.0);
    });

    test('exposes the new catalogue fields', () {
      final course = CourseModel.fromJson(const {
        'title': 'Dart',
        'category': 'Programming',
        'rating': 4.5,
        'enrollmentCount': 12,
        'lessonCount': 8,
      });

      expect(course.category, 'Programming');
      expect(course.rating, 4.5);
      expect(course.enrollmentCount, 12);
      expect(course.lessonCount, 8);
    });

    test('toJson writes a lowercased title for prefix search', () {
      final json = const CourseModel(
        cover: '',
        duration: '',
        instructors: [],
        title: 'Flutter Basics',
      ).toJson();

      expect(json['titleLower'], 'flutter basics');
      expect(json.containsKey('id'), isFalse,
          reason: 'the document id must not be duplicated into the document');
    });
  });

  group('CourseRepository', () {
    late FakeFirebaseFirestore firestore;
    late CourseRepository repository;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = CourseRepository(firestore: firestore);

      await firestore.collection('courses').doc('c1').set({
        'title': 'Flutter Basics',
        'titleLower': 'flutter basics',
        'cover': 'https://example.com/1.png',
        'duration': '4 weeks',
        'instructor': ['Ada'],
        'category': 'Mobile',
        'enrollmentCount': 10,
      });
      await firestore.collection('courses').doc('c2').set({
        'title': 'Web Design',
        'titleLower': 'web design',
        'cover': 'https://example.com/2.png',
        'duration': '2 weeks',
        'instructor': ['Grace'],
        'category': 'Design',
        'enrollmentCount': 30,
      });
    });

    test('streamCourses returns every course with a non-null id', () async {
      final courses = await repository.streamCourses().first;

      expect(courses, hasLength(2));
      expect(courses.every((c) => c.id != null && c.id!.isNotEmpty), isTrue);
    });

    test('getCourse returns one course, null when missing', () async {
      expect((await repository.getCourse('c1'))?.title, 'Flutter Basics');
      expect(await repository.getCourse('nope'), isNull);
    });

    test('searchCourses matches a title prefix, case-insensitively', () async {
      final results = await repository.searchCourses('FLUT');

      expect(results, hasLength(1));
      expect(results.single.title, 'Flutter Basics');
    });

    test('searchCourses returns nothing for a blank query', () async {
      expect(await repository.searchCourses('   '), isEmpty);
    });

    test('streamByCategory filters on category', () async {
      final design = await repository.streamByCategory('Design').first;

      expect(design, hasLength(1));
      expect(design.single.id, 'c2');
    });

    test('streamCategories lists distinct categories', () async {
      final categories = await repository.streamCategories().first;

      expect(categories, containsAll(['Design', 'Mobile']));
      expect(categories, hasLength(2));
    });

    test('streamPopularCourses orders by enrollmentCount, descending',
        () async {
      final popular = await repository.streamPopularCourses(limit: 2).first;

      expect(popular.first.id, 'c2');
    });

    test('a malformed document does not break the stream', () async {
      await firestore.collection('courses').doc('bad').set({'oops': true});

      final courses = await repository.streamCourses().first;

      expect(courses, hasLength(3));
      final bad = courses.firstWhere((c) => c.id == 'bad');
      expect(bad.title, isNotEmpty);
    });

    test('backfillSearchFields adds titleLower to legacy documents', () async {
      // Courses created before the search feature have no titleLower.
      await firestore.collection('courses').doc('old').set({
        'title': 'Legacy Course',
        'cover': '',
        'duration': '1 week',
        'instructor': ['Ada'],
      });

      final updated = await courses_backfill(repository);

      expect(updated, 1);
      final doc = await firestore.collection('courses').doc('old').get();
      expect(doc.data()!['titleLower'], 'legacy course');
    });

    test('backfillSearchFields is a no-op when everything is indexed',
        () async {
      expect(await courses_backfill(repository), 0);
    });

    test('search finds a backfilled course by prefix', () async {
      await firestore.collection('courses').doc('old').set({
        'title': 'Legacy Course',
        'cover': '',
        'duration': '1 week',
        'instructor': ['Ada'],
      });
      await courses_backfill(repository);

      final results = await repository.searchCourses('legacy');
      expect(results.single.title, 'Legacy Course');
    });

    test('createCourse stores the search field and returns the new id',
        () async {
      final id = await repository.createCourse(const CourseModel(
        cover: 'https://example.com/3.png',
        duration: '1 week',
        instructors: ['Linus'],
        title: 'Git Deep Dive',
        category: 'Tools',
        price: 500,
      ));

      final doc = await firestore.collection('courses').doc(id).get();
      expect(doc.data()!['titleLower'], 'git deep dive');
      expect(doc.data()!['price'], 500);
      expect(doc.data()!['category'], 'Tools');
    });
  });
}

/// Small indirection so the test reads clearly.
Future<int> courses_backfill(CourseRepository repository) =>
    repository.backfillSearchFields();
