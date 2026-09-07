import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_cource_app/data/exam_repository.dart';

const _uid = 'user-1';

void main() {
  late FakeFirebaseFirestore firestore;
  late ExamRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ExamRepository(firestore: firestore);
  });

  group('exam results', () {
    test('recording a result stores the score', () async {
      await repository.recordResult(
        uid: _uid,
        examId: 'images/question.json',
        examName: 'Basic Knowledge',
        score: 7,
        total: 10,
      );

      final results = await repository.streamResults(_uid).first;
      expect(results, hasLength(1));
      expect(results.single.score, 7);
      expect(results.single.total, 10);
      expect(results.single.examName, 'Basic Knowledge');
    });

    test('percentage and pass are derived from the score', () async {
      await repository.recordResult(
        uid: _uid,
        examId: 'e1',
        examName: 'Exam',
        score: 8,
        total: 10,
      );

      final result = (await repository.streamResults(_uid).first).single;
      expect(result.percentage, 80);
      expect(result.passed, isTrue);
    });

    test('below the pass mark does not pass', () async {
      await repository.recordResult(
        uid: _uid,
        examId: 'e1',
        examName: 'Exam',
        score: 3,
        total: 10,
      );

      final result = (await repository.streamResults(_uid).first).single;
      expect(result.passed, isFalse);
    });

    test('a zero-question exam does not divide by zero', () async {
      await repository.recordResult(
        uid: _uid,
        examId: 'e1',
        examName: 'Exam',
        score: 0,
        total: 0,
      );

      final result = (await repository.streamResults(_uid).first).single;
      expect(result.percentage, 0);
      expect(result.passed, isFalse);
    });

    test('every attempt is kept, not overwritten', () async {
      await repository.recordResult(
          uid: _uid, examId: 'e1', examName: 'Exam', score: 4, total: 10);
      await repository.recordResult(
          uid: _uid, examId: 'e1', examName: 'Exam', score: 9, total: 10);

      expect(await repository.streamResults(_uid).first, hasLength(2));
    });

    test('bestScoreFor returns the highest attempt', () async {
      await repository.recordResult(
          uid: _uid, examId: 'e1', examName: 'Exam', score: 4, total: 10);
      await repository.recordResult(
          uid: _uid, examId: 'e1', examName: 'Exam', score: 9, total: 10);
      await repository.recordResult(
          uid: _uid, examId: 'e2', examName: 'Other', score: 10, total: 10);

      expect(await repository.bestScoreFor(uid: _uid, examId: 'e1'), 9);
      expect(await repository.bestScoreFor(uid: _uid, examId: 'missing'), isNull);
    });

    test('results are returned newest first', () async {
      // Explicit timestamps: the fake resolves serverTimestamp() to the same
      // instant for writes made in the same test.
      final results = firestore.collection('users').doc(_uid).collection('examResults');
      await results.add({
        'examId': 'e1',
        'examName': 'First',
        'score': 1,
        'total': 10,
        'takenAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await results.add({
        'examId': 'e2',
        'examName': 'Second',
        'score': 2,
        'total': 10,
        'takenAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });

      final ordered = await repository.streamResults(_uid).first;
      expect(ordered.map((r) => r.examName).toList(), ['Second', 'First']);
    });

    test('a blank uid is a no-op, not an error', () async {
      await repository.recordResult(
          uid: '', examId: 'e1', examName: 'Exam', score: 1, total: 10);

      expect(await repository.streamResults('').first, isEmpty);
    });
  });

  group('certificates', () {
    test('issuing a certificate stores it', () async {
      await repository.issueCertificate(
        uid: _uid,
        examId: 'e1',
        examName: 'Basic Knowledge',
        candidateName: 'Ada Lovelace',
        score: '9 / 10',
      );

      final certificates = await repository.streamCertificates(_uid).first;
      expect(certificates, hasLength(1));
      expect(certificates.single.candidateName, 'Ada Lovelace');
      expect(certificates.single.examName, 'Basic Knowledge');
    });

    test('re-issuing the same exam certificate replaces it', () async {
      await repository.issueCertificate(
        uid: _uid,
        examId: 'e1',
        examName: 'Basic Knowledge',
        candidateName: 'Ada',
        score: '7 / 10',
      );
      await repository.issueCertificate(
        uid: _uid,
        examId: 'e1',
        examName: 'Basic Knowledge',
        candidateName: 'Ada',
        score: '10 / 10',
      );

      final certificates = await repository.streamCertificates(_uid).first;
      expect(certificates, hasLength(1));
      expect(certificates.single.score, '10 / 10');
    });

    test('certificateCount reflects what was issued', () async {
      expect(await repository.certificateCount(_uid), 0);

      await repository.issueCertificate(
        uid: _uid,
        examId: 'e1',
        examName: 'Exam',
        candidateName: 'Ada',
        score: '10 / 10',
      );

      expect(await repository.certificateCount(_uid), 1);
    });
  });
}
