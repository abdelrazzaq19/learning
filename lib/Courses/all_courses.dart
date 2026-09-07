import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Courses/bookmarks_screen.dart';
import 'package:online_cource_app/Courses/enhanced_course_details.dart';
import 'package:online_cource_app/Courses/course_search.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final CourseRepository _repository = CourseRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () =>
                Get.to(() => const CourseSearchPage(autofocus: true)),
          ),
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => Get.to(() => const BookmarksScreen()),
          ),
        ],
      ),
      body: AsyncView<List<CourseModel>>(
        stream: _repository.streamCourses(),
        errorTitle: 'Could not load courses',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 200),
        empty: const AppEmptyState(
          icon: Icons.school_outlined,
          title: 'No courses yet',
          message: 'New courses will appear here as soon as they are published.',
        ),
        builder: (context, courses) => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
          itemBuilder: (context, index) => CourseCard(course: courses[index]),
        ),
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => EnhancedCourseDetailsPage(course: course)),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: course.cover,
                fit: BoxFit.cover,
                placeholder: (_, __) => const AppSkeleton(height: 200, radius: 0),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 40, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.4, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            if (course.category.isNotEmpty)
              Positioned(
                top: AppTheme.spaceMd,
                left: AppTheme.spaceMd,
                child: _Pill(label: course.category),
              ),
            Positioned(
              left: AppTheme.spaceMd,
              right: AppTheme.spaceMd,
              bottom: AppTheme.spaceMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        course.duration,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                      if (course.instructors.isNotEmpty) ...[
                        const SizedBox(width: AppTheme.spaceMd),
                        const Icon(Icons.person_outline,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.instructors.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
