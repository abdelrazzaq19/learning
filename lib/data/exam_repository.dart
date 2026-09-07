import 'package:cloud_firestore/cloud_firestore.dart';

/// One attempt at an exam.
class ExamResult {
  const ExamResult({
    required this.id,
    required this.examId,
    required this.examName,
    required this.score,
    required this.total,
    this.takenAt,
  });

  final String id;
  final String examId;
  final String examName;
  final int score;
  final int total;
  final DateTime? takenAt;

  /// Whole-percent score. A zero-question exam scores 0 rather than dividing
  /// by zero.
  int get percentage => total <= 0 ? 0 : ((score / total) * 100).round();

  static const int passMark = 50;

  bool get passed => total > 0 && percentage >= passMark;

  factory ExamResult.fromDoc(DocumentSnapshot<Object?> doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

    return ExamResult(
      id: doc.id,
      examId: (data['examId'] ?? '').toString(),
      examName: (data['examName'] ?? 'Exam').toString(),
      score: _asInt(data['score']),
      total: _asInt(data['total']),
      takenAt: _asDate(data['takenAt']),
    );
  }

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  static DateTime? _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// A certificate the reader has earned.
class Certificate {
  const Certificate({
    required this.id,
    required this.examId,
    required this.examName,
    required this.candidateName,
    required this.score,
    this.issuedAt,
  });

  final String id;
  final String examId;
  final String examName;
  final String candidateName;
  final String score;
  final DateTime? issuedAt;

  factory Certificate.fromDoc(DocumentSnapshot<Object?> doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

    return Certificate(
      id: doc.id,
      examId: (data['examId'] ?? '').toString(),
      examName: (data['examName'] ?? 'Exam').toString(),
      candidateName: (data['candidateName'] ?? '').toString(),
      score: (data['score'] ?? '').toString(),
      issuedAt: ExamResult._asDate(data['issuedAt']),
    );
  }
}

/// Exam attempts and earned certificates.
///
/// Results live at `users/{uid}/examResults/{autoId}` (every attempt is kept)
/// and certificates at `users/{uid}/certificates/{examId}` (one per exam).
class ExamRepository {
  ExamRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _results(String uid) =>
      _firestore.collection('users').doc(uid).collection('examResults');

  CollectionReference<Map<String, dynamic>> _certificates(String uid) =>
      _firestore.collection('users').doc(uid).collection('certificates');

  Future<void> recordResult({
    required String uid,
    required String examId,
    required String examName,
    required int score,
    required int total,
  }) async {
    if (uid.isEmpty) return;

    await _results(uid).add({
      'examId': examId,
      'examName': examName,
      'score': score,
      'total': total,
      'takenAt': FieldValue.serverTimestamp(),
    });
  }

  /// Every attempt, newest first.
  Stream<List<ExamResult>> streamResults(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _results(uid).snapshots().map((snapshot) {
      final results = snapshot.docs.map(ExamResult.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.takenAt;
          final bDate = b.takenAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
      return results;
    });
  }

  /// Highest score recorded for an exam, or null if never attempted.
  Future<int?> bestScoreFor({
    required String uid,
    required String examId,
  }) async {
    if (uid.isEmpty) return null;

    final snapshot = await _results(uid).where('examId', isEqualTo: examId).get();
    if (snapshot.docs.isEmpty) return null;

    return snapshot.docs
        .map(ExamResult.fromDoc)
        .map((r) => r.score)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Records a certificate. Keyed by exam, so re-taking replaces the old one.
  Future<void> issueCertificate({
    required String uid,
    required String examId,
    required String examName,
    required String candidateName,
    required String score,
  }) async {
    if (uid.isEmpty) return;

    await _certificates(uid).doc(_safeId(examId)).set({
      'examId': examId,
      'examName': examName,
      'candidateName': candidateName,
      'score': score,
      'issuedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Certificate>> streamCertificates(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _certificates(uid).snapshots().map(
          (snapshot) => snapshot.docs.map(Certificate.fromDoc).toList(),
        );
  }

  Future<int> certificateCount(String uid) async {
    if (uid.isEmpty) return 0;
    final snapshot = await _certificates(uid).get();
    return snapshot.docs.length;
  }

  /// Exam ids are asset paths like `images/question.json`; slashes are not
  /// allowed in a document id.
  static String _safeId(String examId) =>
      examId.replaceAll('/', '_').replaceAll('.', '_');
}
