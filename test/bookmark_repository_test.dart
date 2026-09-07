import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/bookmark_repository.dart';

const _uid = 'user-1';

CourseModel _course({String id = 'c1', String title = 'Flutter Basics'}) =>
    CourseModel(
      id: id,
      title: title,
      cover: 'https://example.com/$id.png',
      duration: '4 weeks',
      instructors: const ['Ada'],
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late BookmarkRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = BookmarkRepository(firestore: firestore);
  });

  test('a course starts un-bookmarked', () async {
    expect(await repository.isBookmarked(uid: _uid, courseId: 'c1'), isFalse);
  });

  test('add then read back', () async {
    await repository.add(uid: _uid, course: _course());

    expect(await repository.isBookmarked(uid: _uid, courseId: 'c1'), isTrue);
    final saved = await repository.streamBookmarks(_uid).first;
    expect(saved.single.id, 'c1');
    expect(saved.single.title, 'Flutter Basics');
  });

  test('toggle flips both ways and reports the new state', () async {
    expect(await repository.toggle(uid: _uid, course: _course()), isTrue);
    expect(await repository.isBookmarked(uid: _uid, courseId: 'c1'), isTrue);

    expect(await repository.toggle(uid: _uid, course: _course()), isFalse);
    expect(await repository.isBookmarked(uid: _uid, courseId: 'c1'), isFalse);
  });

  test('adding the same course twice keeps one entry', () async {
    await repository.add(uid: _uid, course: _course());
    await repository.add(uid: _uid, course: _course());

    expect(await repository.streamBookmarks(_uid).first, hasLength(1));
  });

  test('remove is safe when nothing is bookmarked', () async {
    await repository.remove(uid: _uid, courseId: 'c1');
    expect(await repository.streamBookmarks(_uid).first, isEmpty);
  });

  test('bookmarks are per user', () async {
    await repository.add(uid: _uid, course: _course());

    expect(await repository.streamBookmarks('other-user').first, isEmpty);
  });

  test('a blank uid yields empty rather than an error', () async {
    expect(await repository.streamBookmarks('').first, isEmpty);
    expect(await repository.isBookmarked(uid: '', courseId: 'c1'), isFalse);
  });

  test('a course without an id cannot be bookmarked', () async {
    expect(
      () => repository.add(uid: _uid, course: _course().copyWith(id: '')),
      throwsArgumentError,
    );
  });
}
