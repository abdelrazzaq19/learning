# E-Learning App: UI/UX Modernization, Bug Fixes, Real Features

## Context

`C:\Users\ASUS\projects\E-Learning` is a Flutter + Firebase (Auth/Firestore/Storage) e-learning app. It looks finished but is largely a shell:

- **Fake data** — Home renders the hardcoded `onlineCourceOne` list, "Continue Learning" fabricates 3 courses at 25/50/75%, Profile hardcodes "5 courses / 24 hours / 3 certificates".
- **Broken enrollment** — two divergent Firestore schemas. `AuthController.enrollInCourse` writes `users/{uid}/enrolledCourses/{courseId}`; `showEnrollmentDialog` writes `users/{uid}/enrollment/{autoId}`; the "My Learning" tab reads only the second. Enrolling from `enhanced_course_details` never appears in My Learning.
- **`course.id` always null** — `alll_courses.dart:28` builds `CourseModel.fromJson(doc.data())` without `doc.id`, so every downstream enrollment/progress write targets `""` or is skipped.
- **Crashes** — `LateInitializationError` on `_timer` (`exam_screen.dart:44/260`) when leaving an exam before questions load; same pattern on `_videoController` (`course_play.dart`); unchecked casts in course lists; `signInUsers` throws `not-found` updating a missing user doc.
- **Two brand colors** — `AppTheme.primaryColor 0xFF3D5CFF` vs `constants.dart primary 0xFF6E8AFA`; no dark mode; deprecated APIs (54 × `withOpacity`, `MaterialStateProperty`, `CardTheme`, `VideoPlayerController.network`).
- **Dead UI** — search box does nothing, Categories section has no body, Bookmarks/Downloads/Edit Profile/Forgot Password/Notifications are empty `onTap`s, admin screens unreachable.

Outcome wanted: one coherent modern design system with dark mode, no crashes, and the dead stubs turned into working features backed by Firestore.

**Note:** I will not commit or push. User handles git.

## Architecture Decisions

1. **One data source.** Delete `Model/model.dart.dart` demo lists. Every screen reads Firestore through a repository layer (`lib/data/`), never `FirebaseFirestore.instance` inline.
2. **Canonical enrollment schema** = `users/{uid}/enrolledCourses/{courseId}` (course-id-keyed, supports idempotent enroll + progress). `enrollment/` subcollection is retired; a one-time in-app migration reads any legacy `enrollment` docs on first launch and upserts them, so existing users keep their courses.
3. **GetX stays** for DI + auth; screens keep `setState`. No state-management rewrite — out of scope and high risk.
4. **Theme = single source.** `constants.dart` deleted; `AppTheme` gains `darkTheme()` and both themes are generated from one `ColorScheme.fromSeed` seed so light/dark stay in sync. `ThemeController` (GetX) persists choice via `shared_preferences`.
5. **Legacy screens retired**, not restyled: `Detail/course_detail.dart`, `Detail/course_content.dart`, `Courses/course_details.dart`, `Courses/course_play.dart`'s unused `CoursePage`. `EnhancedCourseDetailsPage` becomes the single detail screen.
6. **New deps:** `shared_preferences` (theme + last-viewed), `flutter_dotenv` or `--dart-define` for SMTP creds (no secrets in source). No payment gateway — "Buy Now" stays a confirmation flow, now recording a `transactions` doc.

## Dependency Graph

```
Theme + shared widgets (T1)
    ├── Repositories + models + course.id fix (T2)
    │       ├── Enrollment unification + migration (T3)
    │       │       ├── My Learning / progress / resume (T7)
    │       │       └── Certificates + exam history (T9)
    │       ├── Home wired to real data (T5)
    │       │       └── Search + categories + bookmarks (T6)
    │       └── Lessons subcollection + player (T8)
    │               └── Admin role gate + lesson CRUD (T10)
    └── Crash + deprecation sweep (T4)  [independent, can run early]
Profile: edit + real stats + forgot password (T11)  → needs T3, T9
```

## Phase 1 — Foundation

### Task 1: Unified theme + dark mode + shared widgets
**Description:** Rebuild `AppTheme` around one seed color with `light()`/`dark()`, fix deprecated theme APIs, add a `ThemeController` with persisted mode and a toggle in Profile. Add shared widgets used by every later task.

**Acceptance criteria:**
- [ ] `AppTheme.lightTheme()` and `AppTheme.darkTheme()` both build; `main.dart` passes `theme`, `darkTheme`, `themeMode: themeController.mode`.
- [ ] `constants.dart` deleted; no file references it.
- [ ] `CardTheme`→`CardThemeData`, `TabBarTheme`→`TabBarThemeData`, `MaterialStateProperty`→`WidgetStateProperty`, `ColorScheme.background`→`surface`.
- [ ] New `lib/widgets/`: `AppEmptyState`, `AppErrorState`, `AppSkeleton` (shimmer), `AsyncView<T>` (wraps StreamBuilder/FutureBuilder into loading/error/empty/data).
- [ ] Theme toggle in Profile persists across restart.

**Verification:** `flutter analyze` clean for `theme/` and `widgets/`; launch app, toggle dark mode, restart, mode retained.
**Dependencies:** None. **Files:** `theme/app_theme.dart`, `theme/theme_controller.dart`, `widgets/*.dart`, `main.dart`, delete `constants.dart`. **Scope:** M

### Task 2: Data layer — repositories, models, `course.id` fix
**Description:** Introduce `lib/data/` repositories so no screen touches Firestore directly. Fix `CourseModel` to always carry the document id and to parse defensively.

**Acceptance criteria:**
- [ ] `CourseRepository` (streamCourses, getCourse, searchCourses, streamByCategory), `EnrollmentRepository`, `LessonRepository`, `UserRepository`.
- [ ] `CourseModel.fromDoc(DocumentSnapshot)` sets `id` from `doc.id`; `fromJson` uses null-safe reads with defaults — a malformed document yields a placeholder card, never a crash.
- [ ] `price` default consistent (`0.0`) in both constructor and parser; `category`, `rating`, `enrollmentCount`, `lessonCount` fields added.
- [ ] Every existing `FirebaseFirestore.instance` call in screen files replaced by a repository call.

**Verification:** Grep shows zero `FirebaseFirestore.instance` outside `lib/data/` and `controllers/`; open Courses tab, ids non-null (debug assert).
**Dependencies:** T1. **Files:** `data/*_repository.dart`, `Model/course_model.dart`, `Courses/alll_courses.dart`. **Scope:** M

### Task 3: Unify enrollment + migrate legacy docs
**Description:** Make `users/{uid}/enrolledCourses/{courseId}` the only enrollment path, route both entry points through it, and migrate old `enrollment/` docs once per user.

**Acceptance criteria:**
- [ ] `showEnrollmentDialog` and `EnhancedCourseDetailsPage` both call `EnrollmentRepository.enroll(courseId)`; the write is `await`ed and errors surface as a toast (today it is fire-and-forget with an unconditional success message).
- [ ] Enroll is idempotent — enrolling twice does not duplicate or double-count `enrollmentCount`.
- [ ] On first launch after update, legacy `enrollment/*` docs are upserted into `enrolledCourses/` and a `migratedV2: true` flag set on the user doc.
- [ ] Enrolling from the detail screen appears in My Learning immediately.

**Verification:** With a test account holding a legacy `enrollment` doc, launch → course appears in My Learning; enroll a new course from detail screen → appears without restart; enroll again → no duplicate.
**Dependencies:** T2. **Files:** `data/enrollment_repository.dart`, `Utils/enroll_dioulouge.dart`, `Courses/enhanced_course_details.dart`, `Courses/enrolled_course.dart`, `controllers/auth_controller.dart`. **Scope:** M

### Task 4: Crash + deprecation sweep
**Description:** Fix every reading-visible crash path and clear deprecated API warnings.

**Acceptance criteria:**
- [ ] `exam_screen.dart` `_timer` → `Timer?` with `_timer?.cancel()`; leaving an exam during load no longer throws.
- [ ] `course_play.dart` `_videoController`/`_chewieController` nullable + guarded `dispose()`; `getDownloadURL()` wrapped in try/catch with a retry error state; `VideoPlayerController.networkUrl(Uri.parse(...))`.
- [ ] `signInUsers` uses `set(..., SetOptions(merge: true))` instead of `update` for `lastLogin`.
- [ ] All `withOpacity(x)` → `withValues(alpha: x)` (54 sites); `super.key` constructors; `mounted` guards on every post-await `BuildContext` use (`login_page`, `sign_up_scree`, `add_new_course`, `profile_screen`).
- [ ] `print()` in `email_helper.dart` → `debugPrint`; SMTP credentials moved to `--dart-define` (no literals in source); dead `Utils/helper.dart` and `AuthController.instance` removed.
- [ ] Unused imports in `home_page.dart` (6) removed.

**Verification:** `flutter analyze` reports zero errors and zero deprecation warnings. Manual: start exam → back out immediately (no crash); open a course with a missing video (error state, not infinite spinner).
**Dependencies:** T1 (theme APIs). **Files:** ~14 files, mechanical edits. **Scope:** L — split into 4a (crashes) and 4b (deprecations) if it runs long.

### Checkpoint A
- [ ] `flutter analyze` clean
- [ ] App builds and runs; login → browse → enroll → My Learning works end to end in both light and dark
- [ ] Review with user before Phase 2

## Phase 2 — Real data + core features

### Task 5: Home wired to real data
**Description:** Replace every hardcoded list on Home with repository streams and real skeleton/empty/error states.

**Acceptance criteria:**
- [ ] Popular Courses grid streams from Firestore (ordered by `enrollmentCount`); Continue Learning streams the user's actual in-progress enrollments (hidden when none).
- [ ] Fake `Future.delayed` loading removed; `RefreshIndicator` re-triggers a real fetch.
- [ ] Currency rendered once (no `৳$50`), lesson counts from real data (no "null lessons"), covers via `CachedNetworkImage` with placeholder + error widget — no `Image.network` on an asset path.
- [ ] `Model/model.dart.dart` deleted.

**Verification:** Empty Firestore → empty states, no crash; seeded Firestore → real titles/prices; pull-to-refresh updates after an admin edit.
**Dependencies:** T2, T3. **Files:** `Home/home_page.dart`, `data/course_repository.dart`. **Scope:** M

### Task 6: Search, categories, bookmarks
**Description:** Turn the three dead stubs into working features.

**Acceptance criteria:**
- [ ] Search on Home and Courses tab filters by title/instructor/category, debounced, with a no-results state. (Firestore prefix query on a lowercased `titleLower` field; repository writes/backfills it.)
- [ ] Categories row renders real categories from Firestore and filters the grid on tap; the currently empty section is gone.
- [ ] Bookmark toggle on course cards + detail screen, stored at `users/{uid}/bookmarks/{courseId}`; the Quick Actions "Bookmarks" tile opens a working list.

**Verification:** Search "flut" → matching courses; tap a category → filtered grid; bookmark a course → appears in Bookmarks, survives restart, un-bookmark removes it.
**Dependencies:** T5. **Files:** `Home/home_page.dart`, `Courses/alll_courses.dart`, `screens/bookmarks_screen.dart`, `data/course_repository.dart`, `data/bookmark_repository.dart`, `navigation/main_navigation.dart`. **Scope:** L

### Checkpoint B
- [ ] Search / category / bookmark all round-trip through Firestore
- [ ] No hardcoded course data remains (`grep onlineCource` empty)
- [ ] Review with user

## Phase 3 — Learning experience

### Task 7: Real progress + resume
**Description:** Persist per-lesson progress and make Continue Learning actually resume.

**Acceptance criteria:**
- [ ] Completing/watching a lesson writes `progress` (0..1), `lastLessonId`, `lastAccessed` to the enrollment doc.
- [ ] Home's Continue Learning shows real percentages, sorted by `lastAccessed`; tapping opens the course at `lastLessonId`.
- [ ] Hardcoded `_currentProgress = 0.25` removed.
- [ ] Course marked complete at 100%, which unlocks the certificate (T9).

**Verification:** Watch a lesson → progress bar moves on Home; kill and relaunch → same value; tap Continue → correct lesson opens.
**Dependencies:** T3, T8. **Files:** `Courses/course_play.dart`, `Home/home_page.dart`, `data/enrollment_repository.dart`. **Scope:** M

### Task 8: Lessons in Firestore + real player
**Description:** Add a `courses/{id}/lessons/{lessonId}` subcollection and drive the player from it instead of two fixed URLs.

**Acceptance criteria:**
- [ ] `LessonModel { id, title, videoUrl, durationSeconds, order, resources[] }`; player builds its list from the subcollection, ordered by `order`.
- [ ] Big Buck Bunny and `demo/demo.mp4` fallbacks removed; a course with no lessons shows an empty state.
- [ ] Lesson list shows watched/unwatched from real progress; unused `CoursePage` class deleted.

**Verification:** Seed 3 lessons for a course → all listed, each plays its own URL; delete lessons → empty state, no crash.
**Dependencies:** T2. **Files:** `Model/lesson_model.dart`, `data/lesson_repository.dart`, `Courses/course_play.dart`. **Scope:** M

### Task 9: Certificates + exam history
**Description:** Make the existing PDF certificate generator reach real users, and persist quiz results.

**Acceptance criteria:**
- [ ] Certificate uses `FirebaseAuth.currentUser` name/email — the `"User Name" / "user@example.com"` literals in `exam_tile.dart:42-43` are gone.
- [ ] Exam results written to `users/{uid}/examResults/{autoId}` (`examId`, `score`, `total`, `takenAt`); an Exam History list shows past attempts with best score.
- [ ] Certificates recorded at `users/{uid}/certificates/{id}` and listed in Profile; PDF re-downloadable from there.
- [ ] Email send is optional and failure-tolerant — a blank SMTP config must not break the flow; the PDF always saves locally and can be shared.

**Verification:** Finish a quiz → result stored, appears in history; certificate PDF opens with the real name; with SMTP unset, no crash and a clear "saved locally" message.
**Dependencies:** T3, T7. **Files:** `Exam/exam_screen.dart`, `Utils/exam_tile.dart`, `Utils/email_helper.dart`, `screens/certificates_screen.dart`, `data/exam_repository.dart`. **Scope:** L

### Checkpoint C
- [ ] Enroll → watch lessons → progress persists → finish exam → certificate issued, all on real data
- [ ] Review with user

## Phase 4 — Admin, profile, polish

### Task 10: Admin role gate + lesson management
**Description:** Make the orphaned admin screens reachable behind a role check and let admins manage lessons.

**Acceptance criteria:**
- [ ] `users/{uid}.role` read at login; an Admin entry appears in the drawer only for `role == 'admin'`.
- [ ] `add_new_course` form writes `description`, `price`, `category` (currently missing, which is why every admin course silently costs 1400).
- [ ] Admins can add/edit/delete lessons on a course.
- [ ] Firestore security rules drafted so non-admins cannot write `courses/`.

**Verification:** Non-admin account → no Admin entry, direct write rejected by rules; admin → create a course with price/category, add a lesson, see it in the player.
**Dependencies:** T8. **Files:** `admin/*.dart`, `Utils/custom_drawer.dart`, `data/course_repository.dart`, `firestore.rules`. **Scope:** M

### Task 11: Profile — edit, real stats, forgot password
**Description:** Wire the remaining dead buttons.

**Acceptance criteria:**
- [ ] Edit Profile updates display name and photo (Firebase Storage upload).
- [ ] Learning Statistics computed from Firestore (enrolled count, watched hours, certificate count) — no literals.
- [ ] Forgot Password calls `AuthController.resetPassword` with a confirmation state.
- [ ] `custom_drawer.dart:78` uses `Get.find<AuthController>()` instead of constructing a new one.

**Verification:** Change name → reflected on Home greeting and Profile after restart; stats match Firestore; reset email received.
**Dependencies:** T3, T9. **Files:** `About/profile_screen.dart`, `Login/login_page.dart`, `Utils/custom_drawer.dart`, `controllers/auth_controller.dart`. **Scope:** M

### Task 12: Screen retirement + naming cleanup
**Description:** Delete superseded screens and fix misspellings now that nothing depends on them.

**Acceptance criteria:**
- [ ] `Detail/course_detail.dart`, `Detail/course_content.dart`, `Courses/course_details.dart` deleted; all navigation points at `EnhancedCourseDetailsPage`.
- [ ] Renames: `alll_courses.dart`→`all_courses.dart`, `sign_up_scree.dart`→`sign_up_screen.dart`, `dialouge_utils.dart`→`dialog_utils.dart`, `enroll_dioulouge.dart`→`enroll_dialog.dart`, `showErrorDialouge`→`showErrorDialog`, `timne`→`time`.
- [ ] `flutter analyze` clean; app builds.

**Verification:** Full smoke test of every tab in light and dark after the renames.
**Dependencies:** all prior. **Files:** deletes + renames. **Scope:** M

### Checkpoint D — Complete
- [ ] `flutter analyze` clean, app builds for Android
- [ ] Full flow works in light and dark: signup → browse/search → bookmark → enroll → watch → progress → exam → certificate → profile
- [ ] User reviews, then commits and pushes themselves

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Enrollment migration loses a user's courses | High | Migration is upsert-only, never deletes legacy `enrollment` docs; verify on a test account before shipping |
| Firestore is empty, so "real data" screens look broken | Med | Ship a seed script (`tool/seed.dart`) with sample courses + lessons; every screen gets an explicit empty state |
| Firestore prefix search is limited (no full-text) | Med | Scope search to title/instructor prefix via `titleLower`; note Algolia as a later upgrade |
| 54-site `withOpacity` sweep introduces visual regressions | Low | Mechanical 1:1 substitution, screenshot-compare key screens |
| Deleting `Detail/` screens breaks a navigation path | Low | Do it last (T12), after all callers repointed |

## Open Questions

- Is there an existing Firestore project with real course data, or should I write a seed script? (Assuming: seed script needed.)
- Any payment gateway wanted later? (Assuming: no — enroll stays free-with-confirmation, but a `transactions` record is written so a gateway can drop in.)

## Files: plan + tasks

On approval, first action is writing `tasks/plan.md` (this document) and `tasks/todo.md` (the checklist) into the project, per the planning skill convention.
