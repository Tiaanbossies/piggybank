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
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<TickerSearchResult> onSelected;

  /// Fired when the user presses Enter/Done on a manually typed ticker
  /// (i.e. not chosen from the suggestions dropdown). Optional and unused
  /// by existing callers (Add/Edit Holding) — added for Instrument
  /// Comparison, which lost this keyboard-submit path when this field
  /// replaced its plain `TextField` (commit `dba7b14`).
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<TickerAutocompleteField> createState() => _TickerAutocompleteFieldState();
}

class _TickerAutocompleteFieldState extends ConsumerState<TickerAutocompleteField> {
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _debouncedQuery = '';
  bool _suppressSuggestions = false;
  OverlayEntry? _overlayEntry;
  double? _fieldWidth;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _removeOverlay();
  }

  void _onChanged(String value) {
    _suppressSuggestions = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
      _syncOverlay();
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
    _removeOverlay();
    widget.onSelected(result);
  }

  // Renders suggestions via an Overlay (CompositedTransformFollower) rather
  // than inline in the parent Column — this field is reused inside layouts
  // (Instrument Comparison's tabs, Add/Edit Holding's sheet) that aren't all
  // keyboard-safe-scroll-aware around it, and an inline fixed-height list
  // pushed the surrounding content into a debug overflow (M4). An overlay
  // floats above the layout instead of participating in it, so it can never
  // overflow the parent's constraints.
  void _syncOverlay() {
    final show = _focusNode.hasFocus && !_suppressSuggestions && _debouncedQuery.isNotEmpty;
    _removeOverlay();
    if (!show) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _fieldWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: _Suggestions(query: _debouncedQuery, onSelected: _select),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;
        return CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Ticker', prefixIcon: Icon(Icons.search)),
            onChanged: _onChanged,
            onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
          ),
        );
      },
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
