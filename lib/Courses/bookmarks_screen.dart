import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Courses/course_search.dart';
import 'package:online_cource_app/Courses/enhanced_course_details.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/bookmark_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';
import 'package:online_cource_app/widgets/bookmark_button.dart';
import 'package:online_cource_app/widgets/course_card.dart';

/// Courses the reader saved for later.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key, this.repository, this.uid});

  final BookmarkRepository? repository;
  final String? uid;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late final BookmarkRepository _repository =
      widget.repository ?? BookmarkRepository();

  String get _uid => widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: AsyncView<List<CourseModel>>(
        stream: _repository.streamBookmarks(_uid),
        errorTitle: 'Could not load your bookmarks',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 92),
        empty: AppEmptyState(
          icon: Icons.bookmark_border,
          title: 'Nothing saved yet',
          message: 'Tap the bookmark icon on any course to save it here.',
          actionLabel: 'Find courses',
          onAction: () => Get.to(() => const CourseSearchPage()),
        ),
        builder: (context, courses) => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, index) {
            final course = courses[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm + 2, vertical: AppTheme.spaceSm),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CourseCover(url: course.cover, height: 56, width: 56),
                ),
                title: Text(course.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  course.instructors.isEmpty
                      ? course.category
                      : course.instructors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: BookmarkButton(
                  course: course,
                  uid: _uid,
                  repository: _repository,
                ),
                onTap: () =>
                    Get.to(() => EnhancedCourseDetailsPage(course: course)),
              ),
            );
          },
        ),
      ),
    );
  }
}
