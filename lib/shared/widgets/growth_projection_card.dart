import 'package:flutter/material.dart';

import '../../core/calc/growth_projection.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_theme.dart';

const _horizonYears = [5, 10, 15, 20, 25, 30];

/// A hypothetical constant-rate growth projection for a given starting
/// balance — used identically on the TFSA and RA ledger screens (both
/// structurally identical per [RaLedgerScreen]'s doc comment). Ports
/// `frontend/src/pages/TfsaPage.tsx`'s "Growth projection" section: a
/// user-adjustable rate input and a fixed-horizon table, never a real
/// backtest.
class GrowthProjectionCard extends StatefulWidget {
  const GrowthProjectionCard({required this.startingBalance, required this.label, super.key});

  final double startingBalance;
  final String label;

  @override
  State<GrowthProjectionCard> createState() => _GrowthProjectionCardState();
}

class _GrowthProjectionCardState extends State<GrowthProjectionCard> {
  final _rateController = TextEditingController(text: '8');

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final rate = double.tryParse(_rateController.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Growth projection', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Assumed annual return', suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                for (final years in _horizonYears) ...[
                  _ProjectionRow(
                    years: years,
                    projected: growthProjection(widget.startingBalance, rate, years),
                    startingBalance: widget.startingBalance,
                  ),
                  if (years != _horizonYears.last) const Divider(height: 16),
                ],
                const SizedBox(height: 12),
                Text(
                  'Hypothetical projection at a constant assumed return — not a forecast. '
                  'Not financial advice.',
                  style: TextStyle(color: semantic?.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  const _ProjectionRow({required this.years, required this.projected, required this.startingBalance});

  final int years;
  final double projected;
  final double startingBalance;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final growth = projected - startingBalance;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$years years', style: TextStyle(color: semantic?.textMuted, fontSize: 13)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatZAR(projected), style: moneyTextStyle(context, fontSize: 15)),
            Text('+${formatZAR(growth)}', style: TextStyle(color: semantic?.success, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
