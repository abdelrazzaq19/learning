import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:online_cource_app/data/exam_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

/// Certificates the reader has earned.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key, this.repository, this.uid});

  final ExamRepository? repository;
  final String? uid;

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  late final ExamRepository _exams = widget.repository ?? ExamRepository();

  String get _uid => widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: AsyncView<List<Certificate>>(
        stream: _exams.streamCertificates(_uid),
        errorTitle: 'Could not load your certificates',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 92),
        empty: const AppEmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'No certificates yet',
          message: 'Pass an exam and your certificate will appear here.',
        ),
        builder: (context, certificates) => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: certificates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, index) {
            final certificate = certificates[index];

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppTheme.spaceMd),
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1F43A047),
                  child: Icon(Icons.workspace_premium,
                      color: AppTheme.successColor),
                ),
                title: Text(certificate.examName,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text('Awarded to ${certificate.candidateName}',
                        style: theme.textTheme.bodySmall),
                    Text(
                      certificate.issuedAt == null
                          ? 'Score ${certificate.score}'
                          : 'Score ${certificate.score} · '
                              '${DateFormat('d MMM yyyy').format(certificate.issuedAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
