import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/portfolios/models/ticker_search_result.dart';
import '../../features/portfolios/providers/ticker_provider.dart';

/// Search-as-you-type ticker field, reused identically everywhere the app
/// needs ticker lookup (currently: Add/Edit Holding) — per
/// `ui-ux-mockup-brief.md` §9's instruction to treat this as "one canonical,
/// reusable interaction, not three separate ones." Debounces keystrokes
/// 350ms before querying `tickerSearchProvider`, shows an inline suggestions
/// list, and calls [onSelected] with the tapped result. Autofill/conflict
/// handling is the caller's responsibility — this field only searches.
class TickerAutocompleteField extends ConsumerStatefulWidget {
  const TickerAutocompleteField({
    required this.controller,
    required this.onSelected,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<TickerSearchResult> onSelected;

  @override
  ConsumerState<TickerAutocompleteField> createState() => _TickerAutocompleteFieldState();
}

class _TickerAutocompleteFieldState extends ConsumerState<TickerAutocompleteField> {
  Timer? _debounce;
  String _debouncedQuery = '';
  bool _suppressSuggestions = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _suppressSuggestions = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debouncedQuery = value.trim());
    });
  }

  void _select(TickerSearchResult result) {
    _debounce?.cancel();
    widget.controller.text = result.ticker;
    widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
    setState(() {
      _suppressSuggestions = true;
      _debouncedQuery = '';
    });
    widget.onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final query = _debouncedQuery;
    final showSuggestions = !_suppressSuggestions && query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Ticker', prefixIcon: Icon(Icons.search)),
          onChanged: _onChanged,
        ),
        if (showSuggestions) _Suggestions(query: query, onSelected: _select),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.query, required this.onSelected});
  final String query;
  final ValueChanged<TickerSearchResult> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(tickerSearchProvider(query));
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(top: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final result in results.take(8))
                  ListTile(
                    dense: true,
                    title: Text(result.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(result.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      result.exchange,
                      style: TextStyle(color: semantic?.textMuted, fontSize: 12),
                    ),
                    onTap: () => onSelected(result),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
