import 'package:flutter/material.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

/// Shown when a query succeeds but returns nothing.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 44, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            if (title != null) ...[
              Text(title!,
                  style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a query fails. Always offers a retry when one is possible.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.error,
    this.onRetry,
  });

  final String title;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.errorColor.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.error_outline,
                  size: 44, color: AppTheme.errorColor),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              message ?? 'Please check your connection and try again.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering placeholder block. Compose these into list/grid skeletons.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  const AppSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = size / 2;

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF262B34) : const Color(0xFFE8ECF2),
      highlightColor: isDark ? const Color(0xFF323845) : const Color(0xFFF7F9FC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Vertical list of card-shaped skeletons, for loading list screens.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.itemCount = 4, this.itemHeight = 96});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
      itemBuilder: (_, __) => AppSkeleton(
        height: itemHeight,
        radius: AppTheme.borderRadius,
      ),
    );
  }
}

/// Renders a [Stream] or [Future] as exactly one of loading / error / empty /
/// data, so no screen has to hand-roll those four branches again.
///
/// Pass [isEmpty] to decide what counts as empty for `T` (defaults to an
/// empty [Iterable] or a null value).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    this.stream,
    this.future,
    this.initialData,
    required this.builder,
    this.loading,
    this.empty,
    this.isEmpty,
    this.onRetry,
    this.errorTitle = 'Could not load',
  }) : assert(stream != null || future != null,
            'AsyncView needs either a stream or a future');

  final Stream<T>? stream;
  final Future<T>? future;
  final T? initialData;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final Widget? empty;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;
  final String errorTitle;

  bool _defaultIsEmpty(T data) {
    if (data == null) return true;
    if (data is Iterable) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    return false;
  }

  Widget _render(BuildContext context, AsyncSnapshot<T> snapshot) {
    if (snapshot.hasError) {
      return AppErrorState(
        title: errorTitle,
        message: snapshot.error.toString(),
        error: snapshot.error,
        onRetry: onRetry,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return loading ?? const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData) {
      return empty ?? const AppEmptyState(message: 'Nothing here yet.');
    }
    final data = snapshot.data as T;
    final checkEmpty = isEmpty ?? _defaultIsEmpty;
    if (checkEmpty(data)) {
      return empty ?? const AppEmptyState(message: 'Nothing here yet.');
    }
    return builder(context, data);
  }

  @override
  Widget build(BuildContext context) {
    if (stream != null) {
      return StreamBuilder<T>(
        stream: stream,
        initialData: initialData,
        builder: _render,
      );
    }
    return FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: _render,
    );
  }
}
