import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/Utils/dialog_utils.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/data/user_repository.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rx<User?> firebaseUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> userData = RxMap<String, dynamic>({});

  /// True when the signed-in user's profile carries `role: 'admin'`.
  /// Admin-only UI is hidden unless this is set; Firestore rules enforce it
  /// server-side (see firestore.rules).
  bool get isAdmin => userData['role'] == 'admin';

  // Enrollment lives in one place; this controller only delegates to it.
  final EnrollmentRepository _enrollments = EnrollmentRepository();
  final UserRepository _users = UserRepository();

  @override
  void onInit() {
    super.onInit();
    firebaseUser.bindStream(_auth.userChanges());
    ever(firebaseUser, _setInitialScreen);
  }

  // Set initial screen based on user authentication state
  _setInitialScreen(User? user) async {
    if (user != null) {
      // User is logged in, fetch user data
      await fetchUserData();
      // Fold any pre-migration enrollment documents into the canonical
      // collection so existing users keep their courses.
      await migrateEnrollmentsIfNeeded();
      await _backfillCourseSearchFields();
    } else {
      // Clear user data when logged out
      userData.clear();
    }
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    try {
      if (currentUser != null) {
        final doc =
            await _firestore.collection('users').doc(currentUser!.uid).get();
        if (doc.exists) {
          userData.value = doc.data() ?? {};

          FirebaseAuth.instance.currentUser!
              .updateDisplayName(userData['name'] ?? "Student");
        } else {
          // Create the profile document if it is missing. `enrolledCourses` is
          // a subcollection, not an array field, so it is not seeded here.
          await _users.ensureUserDocument(
            uid: currentUser!.uid,
            email: currentUser!.email,
            name: currentUser!.displayName,
            photoUrl: currentUser!.photoURL,
          );
          userData.value = await _users.getUser(currentUser!.uid);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  // Method to update user profile
  Future<bool> updateUserProfile(
      {String? displayName,
      String? photoURL,
      Map<String, dynamic>? additionalData}) async {
    try {
      isLoading.value = true;

      if (currentUser != null) {
        // Update in Firebase Auth
        if (displayName != null) {
          await currentUser!.updateDisplayName(displayName);
        }

        if (photoURL != null) {
          await currentUser!.updatePhotoURL(photoURL);
        }

        // Prepare update data
        Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (displayName != null) {
          updateData['displayName'] = displayName;
        }

        if (photoURL != null) {
          updateData['photoURL'] = photoURL;
        }

        // Add any additional data
        if (additionalData != null) {
          updateData.addAll(additionalData);
        }

        // Update in Firestore
        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .update(updateData);

        // Refresh user data
        await fetchUserData();

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Enrolls the signed-in user in [course].
  ///
  /// Delegates to [EnrollmentRepository] so this and the enrollment dialog
  /// write to the same place; they used to use two incompatible schemas.
  Future<bool> enrollInCourse(CourseModel course) async {
    try {
      isLoading.value = true;
      if (currentUser == null) return false;

      await _enrollments.enroll(uid: currentUser!.uid, course: course);
      return true;
    } catch (e) {
      debugPrint('Error enrolling in course: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateCourseProgress(
    String courseId,
    double progress, {
    String? lastLessonId,
  }) async {
    try {
      if (currentUser == null) return false;
      await _enrollments.updateProgress(
        uid: currentUser!.uid,
        courseId: courseId,
        progress: progress,
        lastLessonId: lastLessonId,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating course progress: $e');
      return false;
    }
  }

  Future<bool> isEnrolledInCourse(String courseId) async {
    try {
      if (currentUser == null) return false;
      return await _enrollments.isEnrolled(
        uid: currentUser!.uid,
        courseId: courseId,
      );
    } catch (e) {
      debugPrint('Error checking course enrollment: $e');
      return false;
    }
  }

  /// Enrolled courses with progress, most recently opened first.
  Stream<List<Enrollment>> getEnrolledCoursesStream() {
    return _enrollments.streamEnrollments(currentUser?.uid ?? '');
  }

  /// Indexes any courses that predate search. Best-effort: a failure here
  /// must never block sign-in, and search still works via its fallback scan.
  Future<void> _backfillCourseSearchFields() async {
    try {
      final updated = await CourseRepository().backfillSearchFields();
      if (updated > 0) {
        debugPrint('Indexed $updated course(s) for search');
      }
    } catch (e) {
      debugPrint('Course search backfill skipped: $e');
    }
  }

  /// Folds any pre-migration `enrollment` documents into the canonical
  /// collection. Runs once per user; safe to call on every launch.
  Future<void> migrateEnrollmentsIfNeeded() async {
    if (currentUser == null) return;
    final migrated =
        await _enrollments.migrateLegacyEnrollments(currentUser!.uid);
    if (migrated > 0) {
      debugPrint('Migrated $migrated legacy enrollment(s)');
    }
  }

  Future<User?> signUpNewUsers(
      BuildContext context, String email, String password, String name) async {
    try {
      isLoading.value = true;

      // Create user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Auto sign in after sign up
      if (!context.mounted) return userCredential.user;
      await signInUsers(context, email, password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'An error occurred during registration: ${e.message}';
      }
      if (!context.mounted) return null;
      showErrorDialog(context, errorMessage);
    } catch (e) {
      if (!context.mounted) return null;
      showErrorDialog(context, 'An unexpected error occurred: $e');
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  Future<User?> signInUsers(
      BuildContext context, String email, String password) async {
    try {
      isLoading.value = true;

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // A merging set, not an update: an account created outside the app has
      // no `users/{uid}` document yet, and `update` fails it with `not-found`.
      await _users.touchLastLogin(userCredential.user!.uid);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        default:
          errorMessage = 'An error occurred during sign in: ${e.message}';
      }
      if (!context.mounted) return null;
      showErrorDialog(context, errorMessage);
    } catch (e) {
      if (!context.mounted) return null;
      showErrorDialog(context, 'An unexpected error occurred: $e');
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error resetting password: ${e.message}');
      return false;
    }
  }

  Future<void> signOutUsers() async {
    try {
      isLoading.value = true;
      await _auth.signOut();
    } catch (e) {
      showErrorDialog(Get.context!, 'Error signing out: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }
}
