import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../models/insight.dart';
import '../providers/insights_provider.dart';

/// Blueprint Step 7. Originally replaced the `/insights` `PlaceholderScreen`
/// and lived at the bottom nav's 4th tab slot. That slot now routes to
/// `ChatbotScreen` (the AI Assistant) instead — this screen is currently
/// unrouted (no `GoRoute` references it) but left in place, tests and all,
/// in case the product decides to bring a distinct Q&A-history surface
/// back later.
///
/// Deliberately does **not** reuse [HeroMetricCard]/[ProgressCard] despite
/// `docs/stitch-design-brief.md` §8 suggesting that vocabulary — both widgets'
/// own doc comments restrict them to a single net-worth-style metric or a
/// percentage-of-budget value respectively, neither of which this feature has
/// (an AI answer is prose, not a number). Instead: a question box, then the
/// just-asked answer with its own small "stat strip" of the data it was
/// computed from (mirrors `_CashflowStatStrip` on the Dashboard), then a
/// `GroupCard` history list (mirrors `ImportHistoryScreen`) — reusing this
/// app's actual established vocabulary rather than forcing single-metric
/// components onto multi-line prose.
///
/// No proactive `/insights/health` check before showing the question box,
/// same reasoning as `ChatbotScreen`: the paywall/rate-limit is tested at the
/// moment of asking, not pre-emptively.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _questionController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text;
    if (question.trim().isEmpty) return;
    setState(() => _error = null);
    try {
      await ref.read(insightsAskControllerProvider.notifier).ask(question);
      _questionController.clear();
    } on ApiError catch (e) {
      if (e.isPaywall) {
        if (mounted) {
          Navigator.of(context).pop();
          unawaited(showPaywallPrompt(context, message: e.message));
        }
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final askState = ref.watch(insightsAskControllerProvider);
    final historyAsync = ref.watch(insightHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: CircleAvatar(child: Icon(Icons.person_outline, size: 18)),
        ),
        title: const Text('Insights'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _questionController,
              enabled: !askState.asking,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: 'Ask about your spending, budgets, or net worth…',
                suffixIcon: IconButton(
                  onPressed: askState.asking ? null : _ask,
                  tooltip: 'Ask',
                  icon: askState.asking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (askState.lastResult case final lastResult?) ...[
              const SizedBox(height: 16),
              _AnswerCard(result: lastResult),
            ],
            const SizedBox(height: 20),
            Text('Past insights', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load past insights'),
              data: (insights) {
                if (insights.isEmpty) {
                  return const Text('No insights yet — ask a question above to get started.');
                }
                return GroupCard(
                  children: [
                    for (final insight in insights)
                      GroupRow(
                        leadingIcon: Icons.auto_awesome_outlined,
                        title: insight.summaryText,
                        subtitle: '${insight.generatedAt.toLocal()}'.split('.').first,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.result});
  final InsightAskResult result;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                IconChip(icon: Icons.auto_awesome_outlined, size: 36),
                SizedBox(width: 12),
                Expanded(child: Text('Answer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
            const SizedBox(height: 12),
            Text(result.answer, style: Theme.of(context).textTheme.bodyLarge),
            if (result.counts.isNotEmpty || result.dateScopeDays != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (result.dateScopeDays != null)
                    Text('Last ${result.dateScopeDays} days', style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
                  for (final entry in result.counts.entries)
                    Text('${entry.value} ${entry.key}', style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
