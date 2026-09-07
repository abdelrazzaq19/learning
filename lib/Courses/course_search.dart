import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Courses/enhanced_course_details.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/bookmark_repository.dart';
import 'package:online_cource_app/data/course_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';
import 'package:online_cource_app/widgets/bookmark_button.dart';
import 'package:online_cource_app/widgets/course_card.dart';

/// Browse the catalogue: search by title, instructor or category, and filter
/// by category.
class CourseSearchPage extends StatefulWidget {
  const CourseSearchPage({
    super.key,
    this.courseRepository,
    this.bookmarkRepository,
    this.uid,
    this.autofocus = false,
  });

  final CourseRepository? courseRepository;
  final BookmarkRepository? bookmarkRepository;

  /// Overridable for tests; production reads the signed-in user.
  final String? uid;
  final bool autofocus;

  @override
  State<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends State<CourseSearchPage> {
  static const Duration _debounce = Duration(milliseconds: 300);

  late final CourseRepository _courses =
      widget.courseRepository ?? CourseRepository();
  late final BookmarkRepository _bookmarks =
      widget.bookmarkRepository ?? BookmarkRepository();

  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  String _query = '';
  String? _category;
  bool _searching = false;
  List<CourseModel>? _results;
  Object? _error;

  String get _uid =>
      widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounced so typing does not fire a query per keystroke.
  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final term = value.trim();

    if (term.isEmpty) {
      if (!mounted) return;
      setState(() {
        _query = '';
        _results = null;
        _error = null;
        _searching = false;
      });
      return;
    }

    setState(() {
      _query = term;
      _searching = true;
      _error = null;
    });

    try {
      final results = await _courses.searchCourses(term);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _searching = false;
      });
    }
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _results = null;
      _error = null;
      _searching = false;
    });
  }

  void _openCourse(CourseModel course) {
    Get.to(() => EnhancedCourseDetailsPage(course: course));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search courses')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, 0),
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search by title, instructor or category',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          _CategoryFilter(
            courses: _courses,
            selected: _category,
            // Tapping the selected category clears the filter.
            onSelected: (category) => setState(
              () => _category = _category == category ? null : category,
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return AppErrorState(
        title: 'Search failed',
        message: _error.toString(),
        onRetry: () => _runSearch(_query),
      );
    }

    if (_searching) {
      return const AppListSkeleton(itemHeight: 92);
    }

    // No query yet: browse the catalogue, filtered by category if one is set.
    if (_query.isEmpty) {
      return AsyncView<List<CourseModel>>(
        stream: _category == null
            ? _courses.streamCourses()
            : _courses.streamByCategory(_category!),
        errorTitle: 'Could not load courses',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 92),
        empty: AppEmptyState(
          icon: Icons.search,
          title: 'Search the catalogue',
          message: _category == null
              ? 'Type a course title, an instructor, or pick a category.'
              : 'No courses in this category yet.',
        ),
        builder: (context, courses) => _resultList(courses),
      );
    }

    final results = _filterByCategory(_results ?? const []);
    if (results.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: 'No results',
        message: 'No courses match "$_query".',
        actionLabel: 'Clear search',
        onAction: _clear,
      );
    }

    return _resultList(results);
  }

  List<CourseModel> _filterByCategory(List<CourseModel> courses) {
    if (_category == null) return courses;
    return courses.where((c) => c.category == _category).toList();
  }

  Widget _resultList(List<CourseModel> courses) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      itemCount: courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
      itemBuilder: (context, index) {
        final course = courses[index];
        return _SearchResultTile(
          course: course,
          onTap: () => _openCourse(course),
          trailing: BookmarkButton(
            course: course,
            uid: _uid,
            repository: _bookmarks,
          ),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.course,
    required this.onTap,
    required this.trailing,
  });

  final CourseModel course;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceSm + 2),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CourseCover(url: course.cover, height: 64, width: 64),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      course.instructors.isEmpty
                          ? course.category
                          : '${course.category} · ${course.instructors.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of category chips, built from the catalogue itself.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.courses,
    required this.selected,
    required this.onSelected,
  });

  final CourseRepository courses;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: courses.streamCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <String>[];
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spaceSm),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Center(
                child: FilterChip(
                  label: Text(category),
                  selected: selected == category,
                  onSelected: (_) => onSelected(category),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
