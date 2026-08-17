import 'package:flutter/material.dart';

import '../../../core/calc/loan_calc.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';

/// Ports `CalculatorsPage.tsx`'s two forms (Loan Calculator + Loan
/// Accelerator), grouped with Liabilities per the Phase 0 scoping note.
/// Pure client-side math (`loan_calc.dart`), no backend calls.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculators'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Loan Calculator'), Tab(text: 'Loan Accelerator')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_LoanCalculatorTab(), _LoanAcceleratorTab()],
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

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_principalController.text.trim()) ?? 0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0;
    final term = int.tryParse(_termController.text.trim()) ?? 0;
    setState(() => _pmt = calcPmt(principal, rate, term));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (_pmt != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly payment', style: Theme.of(context).textTheme.labelMedium),
                    Text(formatZAR(_pmt), style: moneyTextStyle(context, fontSize: 28)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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

  @override
  void dispose() {
    _outstandingController.dispose();
    _rateController.dispose();
    _remainingController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _calculate() {
    final outstanding = double.tryParse(_outstandingController.text.trim()) ?? 0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0;
    final remaining = int.tryParse(_remainingController.text.trim()) ?? 0;
    final extra = double.tryParse(_extraController.text.trim()) ?? 0;
    setState(() => _result = calcAcceleratedPayoff(outstanding, rate, remaining, extra));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Months saved', style: Theme.of(context).textTheme.labelMedium),
                    Text('${result.monthsSaved.round()}', style: moneyTextStyle(context, fontSize: 22)),
                    const SizedBox(height: 12),
                    Text('Interest saved', style: Theme.of(context).textTheme.labelMedium),
                    Text(formatZAR(result.interestSaved), style: moneyTextStyle(context, fontSize: 22)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
