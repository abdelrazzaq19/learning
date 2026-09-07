import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/admin/add_new_course.dart';
import 'package:online_cource_app/admin/manage_lessons.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final CourseRepository _repository = CourseRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courses'),
        actions: [
          IconButton(
            tooltip: 'Add course',
            icon: const Icon(Icons.add),
            onPressed: () => Get.to(() => const AddCourseScreen()),
          ),
        ],
      ),
      body: AsyncView<List<CourseModel>>(
        stream: _repository.streamCourses(),
        errorTitle: 'Could not load courses',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 120),
        empty: AppEmptyState(
          icon: Icons.library_add_outlined,
          title: 'No courses yet',
          message: 'Add the first course to get the catalogue started.',
          actionLabel: 'Add course',
          onAction: () => Get.to(() => const AddCourseScreen()),
        ),
        builder: (context, courses) => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
          itemBuilder: (context, index) {
            final course = courses[index];
            return _AdminCourseTile(
              course: course,
              onManageLessons: () =>
                  Get.to(() => ManageLessonsScreen(course: course)),
            );
          },
        ),
      ),
    );
  }
}

class _AdminCourseTile extends StatelessWidget {
  const _AdminCourseTile({required this.course, required this.onManageLessons});

  final CourseModel course;
  final VoidCallback onManageLessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 96,
                child: course.cover.isEmpty
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: course.cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const AppSkeleton(height: 96, radius: 0),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    course.instructors.isEmpty
                        ? 'No instructor assigned'
                        : course.instructors.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceXs,
                    children: [
                      _MetaChip(icon: Icons.schedule, label: course.duration),
                      _MetaChip(icon: Icons.category_outlined, label: course.category),
                      _MetaChip(
                        icon: Icons.sell_outlined,
                        label: course.price == 0
                            ? 'Free'
                            : 'BDT ${course.price.toStringAsFixed(0)}',
                      ),
                      _MetaChip(
                        icon: Icons.ondemand_video_outlined,
                        label: course.lessonCount == 1
                            ? '1 lesson'
                            : '${course.lessonCount} lessons',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onManageLessons,
                      icon: const Icon(Icons.playlist_play, size: 18),
                      label: const Text('Manage lessons'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}
