import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:online_cource_app/Model/course_model.dart';

/// One enrolled course, with the reader's progress through it.
class Enrollment {
  const Enrollment({
    required this.course,
    required this.progress,
    this.lastLessonId,
    this.enrolledAt,
    this.lastAccessed,
    this.completedAt,
    this.completedLessons = const [],
  });

  final CourseModel course;
  final double progress;
  final String? lastLessonId;
  final DateTime? enrolledAt;
  final DateTime? lastAccessed;
  final DateTime? completedAt;

  /// Ids of the lessons the reader has finished.
  final List<String> completedLessons;

  bool hasCompleted(String? lessonId) =>
      lessonId != null && completedLessons.contains(lessonId);

  bool get isComplete => progress >= 1.0;

  /// Progress as a whole percentage, for display.
  int get percent => (progress.clamp(0.0, 1.0) * 100).round();

  factory Enrollment.fromDoc(DocumentSnapshot<Object?> doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

    return Enrollment(
      course: CourseModel.fromJson(data, id: doc.id),
      progress: _asDouble(data['progress']),
      lastLessonId: data['lastLessonId'] as String?,
      enrolledAt: _asDate(data['enrolledAt']),
      lastAccessed: _asDate(data['lastAccessed']),
      completedAt: _asDate(data['completedAt']),
      completedLessons: data['completedLessons'] is Iterable
          ? (data['completedLessons'] as Iterable)
              .map((e) => e.toString())
              .toList()
          : const <String>[],
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    return 0.0;
  }

  static DateTime? _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// The single source of truth for enrollment.
///
/// Canonical location is `users/{uid}/enrolledCourses/{courseId}` — keyed by
/// course id so enrolling is idempotent and progress has somewhere to live.
///
/// An earlier version of the app wrote to `users/{uid}/enrollment/{autoId}`
/// instead, and the two paths never saw each other's data.
/// [migrateLegacyEnrollments] folds the old documents into the canonical
/// collection; it never deletes them, so the old data stays recoverable.
class EnrollmentRepository {
  EnrollmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String canonicalCollection = 'enrolledCourses';
  static const String legacyCollection = 'enrollment';
  static const String migrationFlag = 'enrollmentMigratedV2';

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _enrollments(String uid) =>
      _user(uid).collection(canonicalCollection);

  /// Enrolls [uid] in [course]. Safe to call repeatedly: an existing
  /// enrollment keeps its progress and the course count is not incremented
  /// again.
  Future<void> enroll({required String uid, required CourseModel course}) async {
    final courseId = course.id;
    if (courseId == null || courseId.isEmpty) {
      throw ArgumentError('Cannot enroll in a course without an id');
    }
    if (uid.isEmpty) {
      throw ArgumentError('Cannot enroll without a signed-in user');
    }

    final ref = _enrollments(uid).doc(courseId);
    final existing = await ref.get();

    // Course fields are denormalised so "My Learning" renders from one read.
    await ref.set({
      ...course.toJson(),
      'courseId': courseId,
      'price': course.price,
      'lastAccessed': FieldValue.serverTimestamp(),
      if (!existing.exists) ...{
        'enrolledAt': FieldValue.serverTimestamp(),
        'progress': 0.0,
      },
    }, SetOptions(merge: true));

    if (!existing.exists) {
      await _incrementEnrollmentCount(courseId, 1);
    }
  }

  Future<void> unenroll({required String uid, required String courseId}) async {
    if (uid.isEmpty || courseId.isEmpty) return;

    final ref = _enrollments(uid).doc(courseId);
    if (!(await ref.get()).exists) return;

    await ref.delete();
    await _incrementEnrollmentCount(courseId, -1);
  }

  Future<bool> isEnrolled({
    required String uid,
    required String courseId,
  }) async {
    if (uid.isEmpty || courseId.isEmpty) return false;
    final doc = await _enrollments(uid).doc(courseId).get();
    return doc.exists;
  }

  /// Enrollments with progress, most recently opened first.
  Stream<List<Enrollment>> streamEnrollments(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _enrollments(uid).snapshots().map((snapshot) {
      final enrollments = snapshot.docs.map(Enrollment.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.lastAccessed ?? a.enrolledAt;
          final bDate = b.lastAccessed ?? b.enrolledAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
      return enrollments;
    });
  }

  Stream<List<CourseModel>> streamEnrolledCourses(String uid) {
    return streamEnrollments(uid).map(
      (enrollments) => enrollments.map((e) => e.course).toList(),
    );
  }

  Stream<Enrollment?> streamEnrollment({
    required String uid,
    required String courseId,
  }) {
    if (uid.isEmpty || courseId.isEmpty) return Stream.value(null);
    return _enrollments(uid).doc(courseId).snapshots().map(
          (doc) => doc.exists ? Enrollment.fromDoc(doc) : null,
        );
  }

  Future<Enrollment?> getEnrollment({
    required String uid,
    required String courseId,
  }) async {
    if (uid.isEmpty || courseId.isEmpty) return null;
    final doc = await _enrollments(uid).doc(courseId).get();
    return doc.exists ? Enrollment.fromDoc(doc) : null;
  }

  /// Records how far through a course the reader is. [progress] is clamped to
  /// 0..1. Does nothing if the user is not enrolled.
  Future<void> updateProgress({
    required String uid,
    required String courseId,
    required double progress,
    String? lastLessonId,
  }) async {
    if (uid.isEmpty || courseId.isEmpty) return;

    final ref = _enrollments(uid).doc(courseId);
    if (!(await ref.get()).exists) return;

    final clamped = progress.clamp(0.0, 1.0).toDouble();

    await ref.set({
      'progress': clamped,
      'lastAccessed': FieldValue.serverTimestamp(),
      if (lastLessonId != null) 'lastLessonId': lastLessonId,
      if (clamped >= 1.0) 'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records that [lessonId] has been finished and recomputes course
  /// progress as completed lessons / [totalLessons].
  ///
  /// Completing the same lesson twice is a no-op. Does nothing if the user is
  /// not enrolled.
  Future<void> markLessonComplete({
    required String uid,
    required String courseId,
    required String lessonId,
    required int totalLessons,
  }) async {
    if (uid.isEmpty || courseId.isEmpty || lessonId.isEmpty) return;

    final ref = _enrollments(uid).doc(courseId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final enrollment = Enrollment.fromDoc(snapshot);
    if (enrollment.completedLessons.contains(lessonId)) return;

    final completed = [...enrollment.completedLessons, lessonId];
    final progress =
        totalLessons <= 0 ? 0.0 : (completed.length / totalLessons).clamp(0.0, 1.0);

    await ref.set({
      'completedLessons': completed,
      'progress': progress,
      'lastLessonId': lessonId,
      'lastAccessed': FieldValue.serverTimestamp(),
      if (progress >= 1.0) 'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Folds any `users/{uid}/enrollment` documents written by the previous
  /// version into the canonical collection. Returns how many were migrated.
  ///
  /// Upsert-only and guarded by a flag on the user document, so it runs once
  /// and never clobbers progress recorded canonically.
  Future<int> migrateLegacyEnrollments(String uid) async {
    if (uid.isEmpty) return 0;

    try {
      final user = await _user(uid).get();
      if (user.data()?[migrationFlag] == true) return 0;

      final legacy = await _user(uid).collection(legacyCollection).get();

      var migrated = 0;
      for (final doc in legacy.docs) {
        final data = doc.data();
        final courseId = (data['id'] ?? data['courseId']) as String?;
        if (courseId == null || courseId.isEmpty) continue;

        final target = _enrollments(uid).doc(courseId);
        if ((await target.get()).exists) continue;

        await target.set({
          ...data,
          'courseId': courseId,
          'progress': 0.0,
          'enrolledAt': data['enrolledAt'] ?? FieldValue.serverTimestamp(),
          'lastAccessed': FieldValue.serverTimestamp(),
          'migratedFromLegacy': true,
        }, SetOptions(merge: true));
        migrated++;
      }

      // The legacy documents are deliberately left in place.
      await _user(uid).set(
        {migrationFlag: true},
        SetOptions(merge: true),
      );

      return migrated;
    } catch (e) {
      debugPrint('Enrollment migration failed for $uid: $e');
      return 0;
    }
  }

  Future<void> _incrementEnrollmentCount(String courseId, int delta) async {
    try {
      await _firestore.collection('courses').doc(courseId).set(
        {'enrollmentCount': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
    } catch (e) {
      // A missing course must not fail the enrollment itself.
      debugPrint('Could not update enrollmentCount for $courseId: $e');
    }
  }
}
