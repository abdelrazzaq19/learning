import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:online_cource_app/data/exam_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

/// Past exam attempts, newest first.
class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key, this.repository, this.uid});

  final ExamRepository? repository;
  final String? uid;

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  late final ExamRepository _exams = widget.repository ?? ExamRepository();

  String get _uid => widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Exam History')),
      body: AsyncView<List<ExamResult>>(
        stream: _exams.streamResults(_uid),
        errorTitle: 'Could not load your results',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 76),
        empty: const AppEmptyState(
          icon: Icons.history_edu_outlined,
          title: 'No attempts yet',
          message: 'Take an exam and your results will be listed here.',
        ),
        builder: (context, results) {
          final best = <String, int>{};
          for (final result in results) {
            final current = best[result.examId];
            if (current == null || result.score > current) {
              best[result.examId] = result.score;
            }
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
            itemBuilder: (context, index) {
              final result = results[index];
              final isBest = best[result.examId] == result.score;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (result.passed
                            ? AppTheme.successColor
                            : AppTheme.errorColor)
                        .withValues(alpha: 0.12),
                    child: Text(
                      '${result.percentage}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: result.passed
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(result.examName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    result.takenAt == null
                        ? '${result.score} / ${result.total}'
                        : '${result.score} / ${result.total} · '
                            '${DateFormat('d MMM yyyy, h:mm a').format(result.takenAt!)}',
                  ),
                  trailing: isBest
                      ? Chip(
                          label: const Text('Best'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.primary
                              .withValues(alpha: 0.12),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
