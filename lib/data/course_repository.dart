import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:online_cource_app/Model/course_model.dart';

/// Every read and write of the `courses` collection goes through here.
///
/// Screens must not touch [FirebaseFirestore] directly: keeping the queries in
/// one place is what makes the id, search and category behaviour consistent.
class CourseRepository {
  CourseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionPath = 'courses';

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection(collectionPath);

  Stream<List<CourseModel>> streamCourses() {
    return _courses.snapshots().map(_toCourses);
  }

  /// Courses ordered by how many people enrolled, most popular first.
  Stream<List<CourseModel>> streamPopularCourses({int limit = 10}) {
    return _courses
        .orderBy('enrollmentCount', descending: true)
        .limit(limit)
        .snapshots()
        .map(_toCourses);
  }

  Stream<List<CourseModel>> streamByCategory(String category) {
    return _courses
        .where('category', isEqualTo: category)
        .snapshots()
        .map(_toCourses);
  }

  /// Distinct category names present in the catalogue.
  ///
  /// Firestore cannot do a DISTINCT query, so this derives the set client-side.
  /// The catalogue is small enough that this is cheaper than a second
  /// collection to keep in sync.
  Stream<List<String>> streamCategories() {
    return _courses.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => CourseModel.fromDoc(doc).category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return categories;
    });
  }

  Future<CourseModel?> getCourse(String id) async {
    if (id.isEmpty) return null;
    final doc = await _courses.doc(id).get();
    if (!doc.exists) return null;
    return CourseModel.fromDoc(doc);
  }

  Stream<CourseModel?> streamCourse(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _courses
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? CourseModel.fromDoc(doc) : null);
  }

  /// Case-insensitive prefix search over the course title.
  ///
  /// Firestore has no full-text search; this matches on the `titleLower`
  /// field written by [CourseModel.toJson]. Instructor and category matches are
  /// filtered client-side from the same result window.
  Future<List<CourseModel>> searchCourses(String query, {int limit = 30}) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];

    final byTitle = await _courses
        .orderBy('titleLower')
        .startAt([term])
        .endAt(['$term'])
        .limit(limit)
        .get();

    final results = _toCourses(byTitle);
    if (results.isNotEmpty) return results;

    // Fall back to a client-side scan so instructor and category still match.
    final all = _toCourses(await _courses.limit(200).get());
    return all
        .where((c) =>
            c.title.toLowerCase().contains(term) ||
            c.category.toLowerCase().contains(term) ||
            c.instructors.any((i) => i.toLowerCase().contains(term)))
        .take(limit)
        .toList();
  }

  /// Adds the `titleLower` search field to courses created before search
  /// existed. Returns how many documents were updated.
  ///
  /// Without this, prefix search misses legacy courses and falls back to a
  /// client-side scan. Safe to call repeatedly.
  Future<int> backfillSearchFields({int limit = 500}) async {
    final snapshot = await _courses.limit(limit).get();

    var updated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title'];
      if (title is! String || title.isEmpty) continue;

      final expected = title.toLowerCase();
      if (data['titleLower'] == expected) continue;

      await doc.reference.set({'titleLower': expected}, SetOptions(merge: true));
      updated++;
    }
    return updated;
  }

  /// Creates a course and returns its new document id.
  Future<String> createCourse(CourseModel course) async {
    final doc = await _courses.add(course.toJson());
    return doc.id;
  }

  Future<void> updateCourse(String id, CourseModel course) {
    return _courses.doc(id).update(course.toJson());
  }

  Future<void> deleteCourse(String id) => _courses.doc(id).delete();

  List<CourseModel> _toCourses(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map(CourseModel.fromDoc).toList();
  }
}
