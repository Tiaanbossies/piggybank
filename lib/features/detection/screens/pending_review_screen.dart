import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/spring_swipe.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/mascot_moment.dart';
import '../../../shared/widgets/swipe_background.dart';
import '../../accounts/models/account.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../portfolios/providers/portfolios_provider.dart';
import '../../transactions/providers/transactions_provider.dart' show commonCategories;
import '../data/detection_api.dart';
import '../models/detected_event.dart';
import '../providers/detection_provider.dart';

/// Reached from the Home banner, Transactions › Review, or Settings > Data
/// sources > Bank notifications & email > Review. Plan §5 Phase E's
/// "pending-items review screen (extracted fields shown, Confirm/Discard,
/// holding-selection prompt for investment events)". Every row here is a
/// [DetectedEvent] the backend already ran through Ollama extraction; this
/// screen is the one place a suggestion becomes (or doesn't become) a real
/// Transaction/Dividend/HoldingTrade — nothing here is written automatically.
///
/// One-tap review (daily-driver goal, 2026-10): a transaction that arrives
/// with a suggested category confirms straight from its card — or a swipe
/// right — with no sheet; swipe left discards. Both are held back behind an
/// Undo snackbar and only sent to the backend once it closes, so a mis-tap
/// costs nothing and no un-confirm endpoint is needed. The sheet is still
/// there behind Edit for anything the suggestion got wrong.
class PendingReviewScreen extends ConsumerStatefulWidget {
  const PendingReviewScreen({super.key});

  @override
  ConsumerState<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends ConsumerState<PendingReviewScreen> {
  /// Events hidden from the list while their Undo window is open or their
  /// request is in flight. A committed id is never removed: the refetch that
  /// follows no longer contains it, and un-hiding it early would flash the
  /// card back while that refetch is still loading.
  final Set<String> _settling = {};

  /// Hides [events], shows one Undo snackbar for them all, and sends
  /// [commit] for each once it closes without Undo. A failure brings that
  /// event back with the error; the rest still go through.
  Future<void> _settle(
    List<DetectedEvent> events, {
    required String message,
    required Future<void> Function(DetectionApi api, DetectedEvent event) commit,
  }) async {
    // Captured up front: the snackbar outlives this screen if the user backs
    // out during the Undo window, and the commit must still happen then.
    final api = ref.read(detectionApiProvider);
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = {for (final e in events) e.id};

    setState(() => _settling.addAll(ids));
    // Closing the previous snackbar commits its action now rather than
    // queueing this one behind it, so a run of quick confirms stays quick.
    messenger.hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          // A SnackBar with an action persists by default (Flutter 3.29+),
          // which would hold the commit back until the next action — the
          // last item reviewed in a session would never be sent.
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ))
        .closed;

    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _settling.removeAll(ids));
      return;
    }

    String? failure;
    var sent = 0;
    for (final event in events) {
      try {
        await commit(api, event);
        sent++;
      } on ApiError catch (e) {
        failure = e.message;
        if (mounted) setState(() => _settling.remove(event.id));
      }
    }
    if (failure != null) messenger.showSnackBar(SnackBar(content: Text(failure)));
    if (sent > 0) container.invalidate(pendingEventsProvider);
  }

  Future<void> _sendConfirm(DetectionApi api, DetectedEvent event, _ConfirmResult result) => api.confirmEvent(
        event.id,
        accountId: result.accountId,
        category: result.category,
        subcategory: result.subcategory,
        holdingId: result.holdingId,
        quantity: result.quantity,
        pricePerUnit: result.pricePerUnit,
        tradeType: result.tradeType,
      );

  void _confirm(DetectedEvent event, _ConfirmResult result) {
    final description = event.extractedJson?['description'] as String?;
    _settle(
      [event],
      message: [
        'Confirmed',
        if (description != null && description.isNotEmpty) description,
        if (result.category != null) result.category!,
      ].join(' · '),
      commit: (api, e) => _sendConfirm(api, e, result),
    );
  }

  /// "Confirm all n" (visual spec §4.1): every card a single tap would
  /// confirm, each with its own suggestion, behind one Undo.
  void _confirmAll(List<(DetectedEvent, _ConfirmResult)> ready) {
    final results = {for (final (e, r) in ready) e.id: r};
    _settle(
      [for (final (e, _) in ready) e],
      message: 'Confirmed ${ready.length}',
      commit: (api, e) => _sendConfirm(api, e, results[e.id]!),
    );
  }

  void _discard(DetectedEvent event) {
    _settle([event], message: 'Ignored', commit: (api, e) => api.discardEvent(e.id));
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingEventsProvider);
    // Warmed here so a one-tap confirm can resolve the suggested account
    // without the user ever opening the sheet that used to load it.
    ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review detected items')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingEventsProvider),
          child: SkeletonSwitcher(child: pendingAsync.when(
            loading: () => const SkeletonPage(rows: 4),
            error: (err, _) =>
                Center(child: Text(err is ApiError ? err.message : 'Failed to load detected items')),
            data: (allEvents) {
              final events = allEvents.where((e) => !_settling.contains(e.id)).toList();
              if (events.isEmpty) {
                // Cleared, not just empty: something was confirmed or
                // discarded on this visit (spec §3.3, the daily loop's end).
                final cleared = _settling.isNotEmpty;
                return ListView(
                  children: [
                    if (cleared) ...[
                      const SizedBox(height: AppSpace.s32),
                      // M20: celebrating Penny pops, with one medium tap, at
                      // most once a day; after that she just stands there.
                      const Center(
                        child: MascotMoment(
                          asset: MascotMoment.celebrating,
                          size: 96,
                          motion: MascotMotion.pop,
                          kind: 'review-cleared',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All caught up',
                        key: const Key('review-all-caught-up'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s32),
                      child: Text(
                        'Nothing waiting for review. New suggestions from your allowlisted apps and '
                        'connected Gmail account will show up here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.muted),
                      ),
                    ),
                  ],
                );
              }
              final accounts = ref.watch(accountsProvider).valueOrNull;
              final ready = [
                for (final e in events)
                  if (_EventCard.oneTapResult(e, accounts) case final r?) (e, r),
              ];
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s16, AppSpace.gutter, AppSpace.s32),
                itemCount: events.length + (ready.length > 1 ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == events.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s8),
                      child: OutlinedButton.icon(
                        key: const Key('review-confirm-all'),
                        icon: const Icon(Icons.done_all),
                        label: Text('Confirm all ${ready.length}'),
                        onPressed: () => _confirmAll(ready),
                      ),
                    );
                  }
                  return _EventCard(
                    key: ValueKey(events[i].id),
                    event: events[i],
                    onConfirm: (result) => _confirm(events[i], result),
                    onDiscard: () => _discard(events[i]),
                  );
                },
              );
            },
          )),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.onConfirm, required this.onDiscard, super.key});
  final DetectedEvent event;
  final ValueChanged<_ConfirmResult> onConfirm;
  final VoidCallback onDiscard;

  /// The confirm a single tap sends: the backend's own suggestion, unedited.
  /// Null when there is nothing to send without asking — any non-transaction
  /// (those need a holding picked), or a transaction with no suggested
  /// category (the backend rejects a confirm without one).
  static _ConfirmResult? oneTapResult(DetectedEvent event, List<Account>? accounts) {
    if (event.status == DetectionStatus.skippedInvalid) return null;
    if (event.eventKind != 'transaction') return null;
    final extracted = event.extractedJson;
    final category = (extracted?['suggested_category'] as String?)?.trim();
    if (category == null || category.isEmpty) return null;
    final subcategory = (extracted?['suggested_subcategory'] as String?)?.trim();
    final accountId = extracted?['suggested_account_id'] as String?;
    return _ConfirmResult(
      category: category,
      subcategory: subcategory == null || subcategory.isEmpty ? null : subcategory,
      // Same rule as the sheet's `_validAccountId`: a suggested account
      // deleted since ingest would 404, so it is dropped, not sent.
      accountId: accounts != null && accounts.any((a) => a.id == accountId) ? accountId : null,
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_ConfirmResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(event: event),
    );
    if (result != null) onConfirm(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extracted = event.extractedJson;
    final isSkippedInvalid = event.status == DetectionStatus.skippedInvalid;
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final oneTap = oneTapResult(event, accounts);
    final accountName = oneTap?.accountId == null
        ? null
        : accounts!.firstWhere((a) => a.id == oneTap!.accountId).name;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: SpringSwipe(
        key: ValueKey('dismiss-${event.id}'),
        // Swipe right only where a tap would confirm without asking anything.
        direction: oneTap != null ? DismissDirection.horizontal : DismissDirection.endToStart,
        background: SwipeBackground(
          color: t.primaryContainer,
          foreground: t.onPrimaryContainer,
          icon: Icons.check,
          label: 'Confirm',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: SwipeBackground(
          // Neutral, not red: ignoring isn't a mistake (spec §3.2), and red
          // stays reserved for over budget.
          color: t.sunk,
          foreground: t.muted,
          icon: Icons.visibility_off_outlined,
          label: 'Ignore',
          alignment: Alignment.centerRight,
        ),
        onSwiped: (direction) => direction == DismissDirection.startToEnd ? onConfirm(oneTap!) : onDiscard(),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    event.sourceType == DetectionSourceType.email ? Icons.email_outlined : Icons.notifications_outlined,
                    size: 20,
                    color: t.muted,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(event.sourceRef, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                  ),
                  if (extracted?['amount'] != null)
                    Text(
                      formatZAR(extracted!['amount']),
                      style: text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                event.rawText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: AppSpace.s8),
              if (isSkippedInvalid)
                Text(
                  event.errorReason ?? 'Could not extract a financial event from this item.',
                  style: text.bodySmall?.copyWith(color: t.muted),
                )
              else if (extracted != null)
                Wrap(
                  spacing: AppSpace.s16,
                  runSpacing: AppSpace.s4,
                  children: [
                    _Field('Kind', event.eventKind ?? '—'),
                    if (extracted['date'] != null) _Field('Date', extracted['date'].toString()),
                    if (extracted['ticker'] != null) _Field('Ticker', extracted['ticker'].toString()),
                    if (extracted['description'] != null) _Field('Description', extracted['description'].toString()),
                  ],
                ),
              if (oneTap != null) ...[
                const SizedBox(height: AppSpace.s12),
                // What a tap on Confirm will file it as, as a category pill:
                // shown in full, since there is no sheet in between to check
                // it on any more.
                _CategoryPill(
                  [
                    [oneTap.category!, if (oneTap.subcategory != null) oneTap.subcategory!].join(' › '),
                    ?accountName,
                  ].join(' · '),
                ),
              ],
              const SizedBox(height: AppSpace.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onDiscard, child: const Text('Ignore')),
                  if (oneTap != null) ...[
                    const SizedBox(width: AppSpace.s4),
                    TextButton(onPressed: () => _openSheet(context), child: const Text('Edit')),
                  ],
                  const SizedBox(width: AppSpace.s8),
                  if (!isSkippedInvalid)
                    ElevatedButton(
                      onPressed: oneTap != null ? () => onConfirm(oneTap) : () => _openSheet(context),
                      child: const Text('Confirm'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The category a one-tap confirm will use, as a primaryContainer pill.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      key: const Key('review-category-pill'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 6),
      decoration: BoxDecoration(color: t.primaryContainer, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, size: 16, color: t.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, color: context.tokens.muted)),
        Text(value),
      ],
    );
  }
}

/// What `_ConfirmSheet` hands back to `_EventCard._confirm` — only the
/// fields relevant to the event's own `event_kind` are ever non-null; the
/// rest pass straight through as null to `DetectionApi.confirmEvent`.
class _ConfirmResult {
  const _ConfirmResult({
    this.accountId,
    this.category,
    this.subcategory,
    this.holdingId,
    this.quantity,
    this.pricePerUnit,
    this.tradeType,
  });

  final String? accountId;
  final String? category;
  final String? subcategory;
  final String? holdingId;
  final String? quantity;
  final String? pricePerUnit;
  final String? tradeType;
}

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.event});
  final DetectedEvent event;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  final _categoryController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  String? _accountId;
  String? _holdingId;
  String _tradeType = 'buy';
  String? _error;

  /// The backend's suggestion, from a learned rule or the AI categoriser
  /// (`category_suggester.py`). Null for investment events, and for a
  /// merchant seen for the first time while the categoriser was down.
  String? get _suggestedCategory => widget.event.extractedJson?['suggested_category'] as String?;
  String? get _suggestedSubcategory =>
      widget.event.extractedJson?['suggested_subcategory'] as String?;

  /// Only a learned rule ever suggests an account — the AI categoriser sees
  /// the description text, which says nothing about which account was charged.
  String? get _suggestedAccountId =>
      widget.event.extractedJson?['suggested_account_id'] as String?;

  /// `_accountId` can hold a suggested account that has since been deleted,
  /// because the suggestion was written into the event at ingest time. A
  /// DropdownButtonFormField asserts when its value isn't among its items,
  /// and the backend 404s on an account the user no longer owns — so both
  /// the dropdown and the submit go through this, not through `_accountId`.
  String? get _validAccountId {
    final accounts = ref.read(accountsProvider).valueOrNull;
    if (accounts == null) return null;
    return accounts.any((a) => a.id == _accountId) ? _accountId : null;
  }

  @override
  void initState() {
    super.initState();
    _categoryController.text = _suggestedCategory ?? '';
    _subcategoryController.text = _suggestedSubcategory ?? '';
    _accountId = _suggestedAccountId;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _subcategoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final kind = widget.event.eventKind;
    if (kind == 'transaction') {
      if (_categoryController.text.trim().isEmpty) {
        setState(() => _error = 'Choose a category — the extraction never proposes one.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(
        accountId: _validAccountId,
        category: _categoryController.text.trim(),
        subcategory: _subcategoryController.text.trim().isEmpty ? null : _subcategoryController.text.trim(),
      ));
    } else if (kind == 'dividend') {
      if (_holdingId == null) {
        setState(() => _error = 'Select which holding this dividend belongs to.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(holdingId: _holdingId));
    } else if (kind == 'trade') {
      final qty = _quantityController.text.trim();
      final price = _priceController.text.trim();
      if (_holdingId == null || qty.isEmpty || price.isEmpty) {
        setState(() => _error = 'Select a holding and enter quantity + price to confirm this trade.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(
        holdingId: _holdingId,
        quantity: qty,
        pricePerUnit: price,
        tradeType: _tradeType,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.event.eventKind;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confirm ${kind ?? 'item'}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (kind == 'transaction') ..._transactionFields(),
            if (kind == 'dividend') ..._holdingField(),
            if (kind == 'trade') ..._tradeFields(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.tokens.danger)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text('Confirm')),
          ],
        ),
      ),
    );
  }

  List<Widget> _transactionFields() {
    final accountsAsync = ref.watch(accountsProvider);
    return [
      Autocomplete<String>(
        initialValue: TextEditingValue(text: _suggestedCategory ?? ''),
        optionsBuilder: (value) {
          if (value.text.isEmpty) return commonCategories;
          return commonCategories.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
        },
        onSelected: (selection) => _categoryController.text = selection,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          controller.addListener(() => _categoryController.text = controller.text);
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: 'Category'),
          );
        },
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _subcategoryController,
        decoration: const InputDecoration(labelText: 'Subcategory (optional)'),
      ),
      const SizedBox(height: 16),
      accountsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox.shrink(),
        data: (accounts) => DropdownButtonFormField<String>(
          initialValue: _validAccountId,
          decoration: const InputDecoration(labelText: 'Account (optional)'),
          items: [
            const DropdownMenuItem(child: Text('None')),
            for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
      ),
    ];
  }

  List<Widget> _holdingField() {
    final holdingsAsync = ref.watch(allHoldingsProvider);
    return [
      holdingsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Could not load holdings.'),
        data: (entries) => DropdownButtonFormField<String>(
          initialValue: _holdingId,
          decoration: const InputDecoration(labelText: 'Holding'),
          items: [
            for (final (portfolio, holding) in entries)
              DropdownMenuItem(value: holding.id, child: Text('${holding.ticker} — ${portfolio.name}')),
          ],
          onChanged: (value) => setState(() => _holdingId = value),
        ),
      ),
    ];
  }

  List<Widget> _tradeFields() {
    return [
      ..._holdingField(),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'buy', label: Text('Buy')),
          ButtonSegment(value: 'sell', label: Text('Sell')),
        ],
        selected: {_tradeType},
        onSelectionChanged: (selection) => setState(() => _tradeType = selection.first),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _quantityController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Price per unit (ZAR)'),
      ),
    ];
  }
}
