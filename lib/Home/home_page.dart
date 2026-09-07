import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Courses/alll_courses.dart';
import 'package:online_cource_app/Courses/bookmarks_screen.dart';
import 'package:online_cource_app/Courses/course_player.dart';
import 'package:online_cource_app/Courses/course_search.dart';
import 'package:online_cource_app/Courses/enhanced_course_details.dart';
import 'package:online_cource_app/Home/home_presentation.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/Utils/custom_drawer.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';
import 'package:online_cource_app/widgets/course_card.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.courseRepository,
    this.enrollmentRepository,
  });

  /// Injectable for tests; production uses the Firestore-backed defaults.
  final CourseRepository? courseRepository;
  final EnrollmentRepository? enrollmentRepository;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final CourseRepository _courses =
      widget.courseRepository ?? CourseRepository();
  late final EnrollmentRepository _enrollments =
      widget.enrollmentRepository ?? EnrollmentRepository();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _refresh() async {
    // The streams are live, so a refresh only needs to rebuild the subscriptions.
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  void _openCourse(CourseModel course) {
    Get.to(() => EnhancedCourseDetailsPage(course: course));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(greetingFor(DateTime.now()),
                        style: theme.textTheme.bodySmall),
                    Text(
                      firstNameOf(FirebaseAuth.instance.currentUser?.displayName),
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Search courses',
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceLg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _FeaturedBanner(),
                    const SizedBox(height: AppTheme.spaceLg),
                    _ContinueLearningSection(
                      enrollments: _enrollments,
                      uid: _uid,
                    ),
                    _SectionHeader(
                      title: 'Popular Courses',
                      onSeeAll: () => Get.to(() => const CourseListPage()),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    _PopularCoursesGrid(
                      courses: _courses,
                      onOpen: _openCourse,
                      onRetry: () => setState(() {}),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Keep learning',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Pick up where you left off, or explore something new.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reader's actual in-progress courses. Hidden entirely when there are
/// none, rather than showing fabricated placeholder cards.
class _ContinueLearningSection extends StatelessWidget {
  const _ContinueLearningSection({required this.enrollments, required this.uid});

  final EnrollmentRepository enrollments;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Enrollment>>(
      stream: enrollments.streamEnrollments(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spaceLg),
            child: AppSkeleton(height: 96, radius: AppTheme.borderRadius),
          );
        }

        final inProgress = (snapshot.data ?? const <Enrollment>[])
            .where((e) => !e.isComplete)
            .toList();
        if (inProgress.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Continue Learning'),
            const SizedBox(height: AppTheme.spaceSm),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: inProgress.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.spaceMd),
                itemBuilder: (context, index) {
                  final enrollment = inProgress[index];
                  return SizedBox(
                    width: 280,
                    child: ContinueLearningCard(
                      enrollment: enrollment,
                      onTap: () => Get.to(
                        () => CoursePlayerPage(course: enrollment.course),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        );
      },
    );
  }
}

class _PopularCoursesGrid extends StatelessWidget {
  const _PopularCoursesGrid({
    required this.courses,
    required this.onOpen,
    required this.onRetry,
  });

  final CourseRepository courses;
  final void Function(CourseModel course) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<CourseModel>>(
      stream: courses.streamPopularCourses(limit: 8),
      errorTitle: 'Could not load courses',
      onRetry: onRetry,
      loading: const _GridSkeleton(),
      empty: const AppEmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'No courses yet',
        message: 'Courses will show up here once they are published.',
      ),
      builder: (context, data) => AnimationLimiter(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppTheme.spaceMd,
            mainAxisSpacing: AppTheme.spaceMd,
            childAspectRatio: 0.78,
          ),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final course = data[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                scale: 0.95,
                child: FadeInAnimation(
                  child: CourseGridCard(
                    course: course,
                    onTap: () => onOpen(course),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spaceMd,
        mainAxisSpacing: AppTheme.spaceMd,
        childAspectRatio: 0.78,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const AppSkeleton(
        height: double.infinity,
        radius: AppTheme.borderRadius,
      ),
    );
  }
}
