# E-Learning Modernization — Task Checklist

Plan: [tasks/plan.md](plan.md)

## Phase 1 — Foundation
- [x] **T1** Unified theme + dark mode + shared widgets (`theme/`, `widgets/`, `main.dart`, delete `constants.dart`) — M
  - Also unblocked the build: `google_fonts` 6.2.1 -> 6.3.3, dropped incompatible `icons_plus`, bundled Poppins locally
  - Tests: `test/theme_test.dart` (7), `test/app_states_test.dart` (6)
  - Open: Android Gradle build blocked by Java 25 vs Gradle 8.5 (environment, not code)
- [x] **T2** Data layer: repositories, `CourseModel.fromDoc`, `course.id` fix — M — needs T1
  - `CourseRepository`, `LessonRepository`, `UserRepository`; `LessonModel` added
  - `CourseModel` parses defensively, carries the doc id, writes `titleLower` for search
  - Courses list + admin list rebuilt on `AsyncView` with skeleton/empty/error states
  - Tests: `test/course_repository_test.dart` (14), `test/repositories_test.dart` (10)
  - Remaining inline Firestore is in the enrollment path — T3
- [x] **T3** Unify enrollment on `users/{uid}/enrolledCourses/{courseId}` + legacy migration — M — needs T2
  - `EnrollmentRepository` + `Enrollment` model; both enroll paths now write one schema
  - Idempotent enroll, clamped progress, upsert-only legacy migration behind a flag
  - `signInUsers` no longer throws `not-found`; My Learning shows real progress
  - Tests: `test/enrollment_repository_test.dart` (19)
- [x] **T4a** Crash fixes: `_timer`/`_videoController` nullable, `getDownloadURL` try/catch, `signInUsers` merge-set — M — needs T1
  - Tests: `test/lifecycle_test.dart` (2) — reproduce the LateInitializationError, then prove it gone
- [x] **T4b** Deprecation sweep: `withOpacity`→`withValues`, `super.key`, `mounted` guards, `print`→`debugPrint`, SMTP to `--dart-define`, drop dead code + unused imports — M — needs T1
  - 178 analyzer issues -> 1 (the last one dies with `model.dart.dart` in T5)
- [ ] **Checkpoint A** — `flutter analyze` clean; login → browse → enroll → My Learning works, light and dark; review with user

## Phase 2 — Real data + core features
- [x] **T5** Home on real Firestore data; delete `Model/model.dart.dart` — M — needs T2, T3
  - `home_presentation.dart` (pure formatting) + `widgets/course_card.dart` (shared cards)
  - Legacy `Detail/` screens deleted with the demo data - nothing reached them once Home stopped linking there
  - Tests: `test/home_presentation_test.dart` (11)
  - Gap: no widget test of Home itself (needs a Firebase Auth mock); repositories and cards are covered
- [x] **T6** Search + categories + bookmarks (`bookmarks_screen.dart`, `bookmark_repository.dart`) — L — needs T5
  - `CourseSearchPage` (debounced search + category chips), `BookmarksScreen`, `BookmarkButton`
  - `backfillSearchFields` indexes pre-existing courses once at sign-in
  - Fake "Added to favorites!" button on the detail screen replaced with a real bookmark
  - Tests: `test/bookmark_repository_test.dart` (8), `test/course_search_test.dart` (7), +3 backfill
- [ ] **Checkpoint B** — all three round-trip through Firestore; `grep onlineCource` empty; review with user

## Phase 3 — Learning experience
- [x] **T8** Lessons subcollection + real player; both old player classes deleted — M — needs T2
  - `CoursePlayerPage` driven by `courses/{id}/lessons`; no hardcoded video URLs left
- [x] **T7** Real progress + resume from `lastLessonId` — M — needs T3, T8
  - `markLessonComplete` recomputes progress from completed lessons; resume works
  - Tests: `test/course_player_test.dart` (13, covering both T7 and T8)
- [x] **T9** Certificates with real identity + exam history — L — needs T3, T7
  - `ExamRepository` + `ExamHistoryScreen` + `CertificatesScreen`
  - Certificate identity from FirebaseAuth; email failure no longer loses the result
  - Profile stats (was hardcoded 5/24/3) now real
  - Tests: `test/exam_repository_test.dart` (11)
- [ ] **Checkpoint C** — enroll → watch → progress → exam → certificate on real data; review with user

## Phase 4 — Admin, profile, polish
- [ ] **T10** Admin role gate + lesson CRUD + `firestore.rules` — M — needs T8
- [ ] **T11** Profile: edit, real stats, forgot password, `Get.find` fix — M — needs T3, T9
- [ ] **T12** Retire legacy screens + rename misspelled files/functions — M — needs all
- [ ] **Checkpoint D** — analyze clean, Android build, full flow light + dark; user commits and pushes

## Notes
- Do not commit or push — user handles git.
- Seed script `tool/seed.dart` needed if Firestore has no real course data.
