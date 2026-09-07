import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:online_cource_app/Model/lesson_model.dart';

/// Reads and writes `courses/{courseId}/lessons`.
class LessonRepository {
  LessonRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _lessons(String courseId) =>
      _firestore.collection('courses').doc(courseId).collection('lessons');

  /// Lessons in teaching order. A blank [courseId] yields an empty list rather
  /// than an error, so callers can render before the course id is known.
  Stream<List<LessonModel>> streamLessons(String courseId) {
    if (courseId.isEmpty) return Stream.value(const []);
    return _lessons(courseId).orderBy('order').snapshots().map(
          (snapshot) => snapshot.docs.map(LessonModel.fromDoc).toList(),
        );
  }

  Future<List<LessonModel>> getLessons(String courseId) async {
    if (courseId.isEmpty) return const [];
    final snapshot = await _lessons(courseId).orderBy('order').get();
    return snapshot.docs.map(LessonModel.fromDoc).toList();
  }

  Future<String> addLesson(String courseId, LessonModel lesson) async {
    final doc = await _lessons(courseId).add(lesson.toJson());
    return doc.id;
  }

  Future<void> updateLesson(
      String courseId, String lessonId, LessonModel lesson) {
    return _lessons(courseId).doc(lessonId).update(lesson.toJson());
  }

  Future<void> deleteLesson(String courseId, String lessonId) {
    return _lessons(courseId).doc(lessonId).delete();
  }

  Future<int> totalDurationSeconds(String courseId) async {
    final lessons = await getLessons(courseId);
    return lessons.fold<int>(0, (total, l) => total + l.durationSeconds);
  }
}
