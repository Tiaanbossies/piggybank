import 'package:flutter/material.dart';

import '../../../core/calc/loan_calc.dart';
import '../../../core/format/money.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/icon_chip.dart';

/// Ports `CalculatorsPage.tsx`'s two forms (Loan Calculator + Loan
/// Accelerator), grouped with Liabilities per the Phase 0 scoping note.
/// Pure client-side math (`loan_calc.dart`), no backend calls. Uses the same
/// `SegmentedButton` toggle pattern as `BudgetsHomeScreen`'s Budgets/Goals
/// switch, in place of a plain `TabBar`. Results use [HeroMetricCard] — the
/// same card language as Portfolio/Assets/Liabilities/Expenses — per
/// `stitch-design-brief.md` §8's "Calculators" instruction not to give these
/// screens a separate "tool" visual identity.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculators')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Loan Calculator')),
                  ButtonSegment(value: 1, label: Text('Loan Accelerator')),
                ],
                selected: {_segment},
                onSelectionChanged: (selection) => setState(() => _segment = selection.first),
              ),
            ),
            Expanded(child: _segment == 0 ? const _LoanCalculatorTab() : const _LoanAcceleratorTab()),
          ],
        ),
      ),
    );
  }
}

class _LoanCalculatorTab extends StatefulWidget {
  const _LoanCalculatorTab();

  @override
  State<_LoanCalculatorTab> createState() => _LoanCalculatorTabState();
}

class _LoanCalculatorTabState extends State<_LoanCalculatorTab> {
  final _principalController = TextEditingController();
  final _rateController = TextEditingController();
  final _termController = TextEditingController();
  double? _pmt;
  String? _error;

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  /// Guards against the silent-zero result the raw `?? 0` parsing used to
  /// produce for empty/invalid/negative input (e.g. a blank loan amount
  /// used to render a confident-looking "Monthly payment R0,00" card
  /// instead of telling the user their input was invalid). `calcPmt` itself
  /// intentionally treats non-positive principal/term as "no payment" (0)
  /// so it can be reused by other callers without throwing — validation
  /// belongs at this screen-wiring layer, not in the pure math function.
  void _calculate() {
    final principalText = _principalController.text.trim();
    final rateText = _rateController.text.trim();
    final termText = _termController.text.trim();

    final principal = double.tryParse(principalText);
    final rate = double.tryParse(rateText);
    final term = int.tryParse(termText);

    if (principal == null || principal <= 0) {
      setState(() {
        _error = 'Enter a loan amount greater than zero.';
        _pmt = null;
      });
      return;
    }
    if (rate == null || rate < 0) {
      setState(() {
        _error = 'Enter a valid interest rate (0 or more).';
        _pmt = null;
      });
      return;
    }
    if (term == null || term <= 0) {
      setState(() {
        _error = 'Enter a term greater than zero.';
        _pmt = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _pmt = calcPmt(principal, rate, term);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconChip(icon: Icons.calculate_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Work out the monthly payment for a loan',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _principalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Loan amount (ZAR)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Annual interest rate (%)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _termController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Term (months)'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _calculate, child: const Text('Calculate')),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_pmt != null) ...[
                  const SizedBox(height: 24),
                  HeroMetricCard(label: 'Monthly payment', value: formatZAR(_pmt)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoanAcceleratorTab extends StatefulWidget {
  const _LoanAcceleratorTab();

  @override
  State<_LoanAcceleratorTab> createState() => _LoanAcceleratorTabState();
}

class _LoanAcceleratorTabState extends State<_LoanAcceleratorTab> {
  final _outstandingController = TextEditingController();
  final _rateController = TextEditingController();
  final _remainingController = TextEditingController();
  final _extraController = TextEditingController();
  AcceleratedPayoffResult? _result;
  String? _error;

  @override
  void dispose() {
    _outstandingController.dispose();
    _rateController.dispose();
    _remainingController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  /// Same rationale as `_LoanCalculatorTabState._calculate`: without this,
  /// an empty/negative outstanding balance silently rendered a "0 months
  /// saved / R0,00 interest saved" card rather than flagging invalid input.
  void _calculate() {
    final outstanding = double.tryParse(_outstandingController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    final remaining = int.tryParse(_remainingController.text.trim());
    final extra = double.tryParse(_extraController.text.trim());

    if (outstanding == null || outstanding <= 0) {
      setState(() {
        _error = 'Enter an outstanding balance greater than zero.';
        _result = null;
      });
      return;
    }
    if (rate == null || rate < 0) {
      setState(() {
        _error = 'Enter a valid interest rate (0 or more).';
        _result = null;
      });
      return;
    }
    if (remaining == null || remaining <= 0) {
      setState(() {
        _error = 'Enter a remaining term greater than zero.';
        _result = null;
      });
      return;
    }
    if (extra == null || extra < 0) {
      setState(() {
        _error = 'Enter a valid extra payment (0 or more).';
        _result = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _result = calcAcceleratedPayoff(outstanding, rate, remaining, extra);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconChip(icon: Icons.speed_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'See how much extra monthly payments save',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _outstandingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Outstanding balance (ZAR)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Annual interest rate (%)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _remainingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Remaining term (months)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _extraController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Extra monthly payment (ZAR)'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _calculate, child: const Text('Calculate')),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (result != null) ...[
                  const SizedBox(height: 24),
                  HeroMetricCard(
                    label: 'Interest saved',
                    value: formatZAR(result.interestSaved),
                    deltaText: '${result.monthsSaved.round()} months saved',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
