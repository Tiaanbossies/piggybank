import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../imports/providers/imports_provider.dart';

/// Reuses the existing `ImportsApi`/`importHistoryProvider` (already wraps
/// `GET /api/imports/`) rather than a duplicate Settings-local API wrapper —
/// the blueprint's task list assumed no such wrapper existed yet, but
/// `imports_provider.dart` already provides exactly this. Row-card list
/// mirrors `ImportsScreen`'s own "Past imports" section (same `GroupCard`/
/// `GroupRow`/`StatusBadge` combination), per `stitch-design-brief.md` §8.
class ImportHistoryScreen extends ConsumerWidget {
  const ImportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(importHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import history')),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err is ApiError ? err.message : 'Something went wrong. Please try again.'),
            ),
          ),
          data: (jobs) {
            if (jobs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No imports yet — upload a CSV from the Imports tab.'),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GroupCard(
                  children: [
                    for (final job in jobs)
                      GroupRow(
                        title: job.filename,
                        subtitle: '${job.importedRows} / ${job.totalRows} imported'
                            '${job.failedRows > 0 ? ' · ${job.failedRows} failed' : ''}',
                        leadingIcon: Icons.description_outlined,
                        trailing: StatusBadge(status: job.status),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
