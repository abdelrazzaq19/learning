import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads and writes the `users/{uid}` profile document.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Creates the profile document if it is missing, and fills in any blanks
  /// otherwise. Always a merge: an existing `role` or `name` is never clobbered.
  Future<void> ensureUserDocument({
    required String uid,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    final snapshot = await _user(uid).get();
    final existing = snapshot.data() ?? const <String, dynamic>{};

    await _user(uid).set({
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoURL': photoUrl,
      'role': existing['role'] ?? 'student',
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records a sign-in. Uses a merging set so an account created outside the
  /// app (which has no `users/{uid}` doc) does not fail with `not-found`.
  Future<void> touchLastLogin(String uid) {
    return _user(uid).set(
      {'lastLogin': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Stream<Map<String, dynamic>> streamUser(String uid) {
    return _user(uid).snapshots().map((doc) => doc.data() ?? const {});
  }

  Future<Map<String, dynamic>> getUser(String uid) async {
    final doc = await _user(uid).get();
    return doc.data() ?? const {};
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) {
    return _user(uid).set(
      {...fields, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<bool> isAdmin(String uid) async {
    final data = await getUser(uid);
    return data['role'] == 'admin';
  }
}
