import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:online_cource_app/Model/course_model.dart';

/// Saved courses, stored at `users/{uid}/bookmarks/{courseId}`.
///
/// Course fields are denormalised onto the bookmark so the list renders from
/// a single read, the same way enrollments do.
class BookmarkRepository {
  BookmarkRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _bookmarks(String uid) =>
      _firestore.collection('users').doc(uid).collection('bookmarks');

  Stream<List<CourseModel>> streamBookmarks(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _bookmarks(uid).snapshots().map(
          (snapshot) => snapshot.docs.map(CourseModel.fromDoc).toList(),
        );
  }

  Future<bool> isBookmarked({
    required String uid,
    required String courseId,
  }) async {
    if (uid.isEmpty || courseId.isEmpty) return false;
    final doc = await _bookmarks(uid).doc(courseId).get();
    return doc.exists;
  }

  Future<void> add({required String uid, required CourseModel course}) async {
    final courseId = course.id;
    if (courseId == null || courseId.isEmpty) {
      throw ArgumentError('Cannot bookmark a course without an id');
    }
    if (uid.isEmpty) return;

    // Keyed by course id, so adding twice keeps one entry.
    await _bookmarks(uid).doc(courseId).set({
      ...course.toJson(),
      'courseId': courseId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove({required String uid, required String courseId}) async {
    if (uid.isEmpty || courseId.isEmpty) return;
    await _bookmarks(uid).doc(courseId).delete();
  }

  /// Adds or removes the bookmark. Returns the resulting state.
  Future<bool> toggle({
    required String uid,
    required CourseModel course,
  }) async {
    final courseId = course.id;
    if (courseId == null || courseId.isEmpty) {
      throw ArgumentError('Cannot bookmark a course without an id');
    }

    if (await isBookmarked(uid: uid, courseId: courseId)) {
      await remove(uid: uid, courseId: courseId);
      return false;
    }
    await add(uid: uid, course: course);
    return true;
  }
}
