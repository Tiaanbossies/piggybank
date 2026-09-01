import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../models/import_job.dart';
import '../models/ocr_result.dart';
import '../providers/imports_provider.dart';

/// CSV import wizard + Scan Receipt, per DESIGN.md's "What's still not
/// covered" note: both are "resolved but undesigned" — built here in the
/// app's plain-screen style (matching the unmocked Portfolio Detail
/// precedent), not against a delivered mockup. Combines what the web app
/// splits across `ImportsPage` and `TransactionsPage`'s "Scan Receipt"
/// button into one screen, reached from Transactions' app bar.
class ImportsScreen extends ConsumerStatefulWidget {
  const ImportsScreen({super.key});

  @override
  ConsumerState<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends ConsumerState<ImportsScreen> {
  // CSV import state
  int _csvStep = 0; // 0 Configure, 1 Upload, 2 Review — per ui-ux-mockup-brief.md §13 item 3
  PlatformFile? _selectedFile;
  String? _selectedTemplate;
  String? _selectedAccountId;
  bool _uploading = false;
  String? _uploadError;
  ImportJob? _result;
  List<List<String>>? _csvPreviewRows;

  // Scan Receipt state
  bool _ocrLoading = false;
  String? _ocrError;
  OcrResult? _ocrResult;
  final _ocrAmountController = TextEditingController();
  final _ocrCategoryController = TextEditingController();
  final _ocrDescriptionController = TextEditingController();
  DateTime _ocrDate = DateTime.now();
  String _ocrTransactionType = 'expense';
  bool _ocrSaving = false;

  @override
  void dispose() {
    _ocrAmountController.dispose();
    _ocrCategoryController.dispose();
    _ocrDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    List<List<String>>? preview;
    if (file.path != null) {
      try {
        final lines = await File(file.path!).readAsLines();
        preview = lines
            .where((l) => l.trim().isNotEmpty)
            .take(6)
            .map((l) => l.split(',').map((c) => c.trim()).toList())
            .toList();
      } catch (_) {
        preview = null;
      }
    }
    setState(() {
      _selectedFile = file;
      _uploadError = null;
      _result = null;
      _csvPreviewRows = preview;
    });
  }

  Future<void> _onUploadPressed() async {
    if (_selectedAccountId == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No account selected'),
          content: const Text("Transactions won't be linked to any account. Continue?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _upload();
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file?.path == null) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
      _result = null;
    });
    try {
      final job = await ref.read(importsApiProvider).uploadCsv(
            filePath: file!.path!,
            filename: file.name,
            template: _selectedTemplate,
            accountId: _selectedAccountId,
          );
      setState(() {
        _result = job;
        _selectedFile = null;
        _csvPreviewRows = null;
        _csvStep = 2;
      });
      ref.invalidate(importHistoryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(recentTransactionsProvider);
    } on ApiError catch (e) {
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _csvStartNewImport() {
    setState(() {
      _csvStep = 0;
      _selectedFile = null;
      _csvPreviewRows = null;
      _result = null;
      _uploadError = null;
    });
  }

  Future<void> _runReceiptFlow(_ReceiptSource source) async {
    String? path;
    String? name;
    if (source == _ReceiptSource.pdf) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      path = result.files.single.path;
      name = result.files.single.name;
    } else {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source == _ReceiptSource.camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (xfile == null) return;
      path = xfile.path;
      name = xfile.name;
    }
    if (path == null) return;
    await _runOcr(path, name);
  }

  Future<void> _runOcr(String path, String filename) async {
    setState(() {
      _ocrLoading = true;
      _ocrError = null;
      _ocrResult = null;
    });
    try {
      final result = await ref.read(importsApiProvider).ocrReceipt(filePath: path, filename: filename);
      setState(() {
        _ocrResult = result;
        _ocrTransactionType = result.transactionType;
        _ocrCategoryController.text = result.category ?? '';
        _ocrAmountController.text = result.amount?.toString() ?? '';
        _ocrDescriptionController.text = result.merchantName ?? result.description ?? '';
        _ocrDate = result.date != null ? (DateTime.tryParse(result.date!) ?? DateTime.now()) : DateTime.now();
      });
    } on ApiError catch (e) {
      setState(() => _ocrError = e.message);
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  Future<void> _saveOcrTransaction() async {
    setState(() {
      _ocrSaving = true;
      _ocrError = null;
    });
    try {
      await ref.read(transactionsApiProvider).create(
            transactionType: _ocrTransactionType == 'income' ? TransactionType.income : TransactionType.expense,
            category: _ocrCategoryController.text.trim(),
            amount: _ocrAmountController.text.trim(),
            transactionDate: _ocrDate,
            description: _ocrDescriptionController.text.trim().isEmpty ? null : _ocrDescriptionController.text.trim(),
          );
      setState(() {
        _ocrResult = null;
        _ocrAmountController.clear();
        _ocrCategoryController.clear();
        _ocrDescriptionController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved!')));
      }
    } on ApiError catch (e) {
      setState(() => _ocrError = e.message);
    } finally {
      if (mounted) setState(() => _ocrSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(bankTemplatesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final historyAsync = ref.watch(importHistoryProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return Scaffold(
      appBar: AppBar(title: const Text('Imports')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const IconChip(icon: Icons.document_scanner_outlined, size: 36),
                const SizedBox(width: 10),
                Text('Scan receipt', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_ocrLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _runReceiptFlow(_ReceiptSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Take photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _runReceiptFlow(_ReceiptSource.gallery),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Pick image'),
                          ),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _ocrLoading ? null : () => _runReceiptFlow(_ReceiptSource.pdf),
                      child: const Text('or choose a PDF instead'),
                    ),
                  ),
                  if (_ocrResult != null) ...[
                    const SizedBox(height: 4),
                    _ConfidenceBadge(score: _ocrResult!.confidenceScore),
                  ],
                ],
              ),
            ),
            if (_ocrError != null) ...[
              const SizedBox(height: 8),
              Text(_ocrError!, style: TextStyle(color: semantic?.danger)),
            ],
            if (_ocrResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _ocrTransactionType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'expense', child: Text('Expense')),
                          DropdownMenuItem(value: 'income', child: Text('Income')),
                        ],
                        onChanged: (v) => setState(() => _ocrTransactionType = v ?? 'expense'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ocrCategoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ocrAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R '),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${_ocrDate.year}-${_ocrDate.month.toString().padLeft(2, '0')}-${_ocrDate.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _ocrDate,
                            firstDate: DateTime(2008),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _ocrDate = picked);
                        },
                      ),
                      TextField(
                        controller: _ocrDescriptionController,
                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _ocrSaving ? null : _saveOcrTransaction,
                              child: _ocrSaving
                                  ? const SizedBox(
                                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Save transaction'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _ocrResult = null),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                const IconChip(icon: Icons.upload_file_outlined, size: 36),
                const SizedBox(width: 10),
                Text('Import CSV', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _CsvStepIndicator(step: _csvStep),
            const SizedBox(height: 16),
            if (_csvStep == 0) ...[
              templatesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (templates) => DropdownButtonFormField<String?>(
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(labelText: 'Bank template'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (generic)')),
                    for (final t in templates) DropdownMenuItem(value: t.bankId, child: Text(t.displayName)),
                  ],
                  onChanged: (v) => setState(() => _selectedTemplate = v),
                ),
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (accounts) => DropdownButtonFormField<String?>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Account (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No account')),
                    for (final a in accounts.where((a) => a.isActive))
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => _csvStep = 1),
                child: const Text('Continue'),
              ),
            ] else if (_csvStep == 1) ...[
              OutlinedButton.icon(
                onPressed: _pickCsvFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_selectedFile == null ? 'Choose CSV file' : _selectedFile!.name),
              ),
              if (_csvPreviewRows != null && _csvPreviewRows!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Preview',
                  style: TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 36,
                      columnSpacing: 16,
                      columns: [
                        for (final header in _csvPreviewRows!.first)
                          DataColumn(
                              label: Text(header, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      ],
                      rows: [
                        for (final row in _csvPreviewRows!.skip(1))
                          DataRow(cells: [
                            for (var i = 0; i < _csvPreviewRows!.first.length; i++)
                              DataCell(Text(i < row.length ? row[i] : '', style: const TextStyle(fontSize: 11))),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _uploading ? null : () => setState(() => _csvStep = 0),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedFile == null || _uploading) ? null : _onUploadPressed,
                      child: _uploading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Upload'),
                    ),
                  ),
                ],
              ),
              if (_uploadError != null) ...[
                const SizedBox(height: 8),
                Text(_uploadError!, style: TextStyle(color: semantic?.danger)),
              ],
            ] else ...[
              if (_result != null) _ResultCard(job: _result!),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _csvStartNewImport,
                child: const Text('Start new import'),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                const IconChip(icon: Icons.history, size: 36),
                const SizedBox(width: 10),
                Text('Past imports', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load import history'),
              data: (jobs) {
                if (jobs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No imports yet — upload a CSV above.'),
                  );
                }
                return GroupCard(
                  children: [
                    for (final job in jobs)
                      GroupRow(
                        title: job.filename,
                        subtitle: '${job.importedRows} / ${job.totalRows} imported'
                            '${job.failedRows > 0 ? ' · ${job.failedRows} failed' : ''}',
                        leadingIcon: job.status == ImportStatus.failed
                            ? Icons.error_outline
                            : job.status == ImportStatus.completed
                                ? Icons.check_circle_outline
                                : Icons.description_outlined,
                        leadingDanger: job.status == ImportStatus.failed,
                        trailing: StatusBadge(status: job.status),
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

enum _ReceiptSource { camera, gallery, pdf }

/// Three labeled pill segments (Configure / Upload / Review) instead of a
/// generic progress-dots widget, per `stitch-design-brief.md` §8's ask for
/// something that fits the app's row-card/pill language.
class _CsvStepIndicator extends StatelessWidget {
  const _CsvStepIndicator({required this.step});
  final int step;

  static const _labels = ['Configure', 'Upload', 'Review'];

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i != 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: i <= step ? colorScheme.primary : semantic?.accentChipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${i + 1}  ${_labels[i]}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: i <= step ? colorScheme.onPrimary : semantic?.textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final Color fg;
    final Color? bg;
    final String label;
    if (score >= 0.8) {
      fg = semantic?.success ?? Colors.green;
      bg = semantic?.accentChipBg;
      label = 'HIGH';
    } else if (score >= 0.5) {
      fg = Theme.of(context).colorScheme.primary;
      bg = semantic?.accentChipBg;
      label = 'MEDIUM';
    } else {
      fg = semantic?.danger ?? Colors.red;
      bg = semantic?.dangerChipBg;
      label = 'LOW';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$label CONFIDENCE', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _ResultCard extends ConsumerStatefulWidget {
  const _ResultCard({required this.job});
  final ImportJob job;

  @override
  ConsumerState<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<_ResultCard> {
  bool _normalizing = false;
  String? _normalizeMsg;

  Future<void> _normalize() async {
    setState(() {
      _normalizing = true;
      _normalizeMsg = null;
    });
    try {
      final res = await ref.read(importsApiProvider).normalizeCategories(widget.job.id);
      setState(() =>
          _normalizeMsg = 'AI normalized ${res['normalized']} descriptions → ${res['rules_added']} rules added.');
    } on ApiError catch (e) {
      setState(() => _normalizeMsg = e.message);
    } finally {
      if (mounted) setState(() => _normalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconChip(icon: Icons.fact_check_outlined, size: 36),
                const SizedBox(width: 10),
                Expanded(child: Text('Upload result', style: Theme.of(context).textTheme.titleMedium)),
                StatusBadge(status: job.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('Imported: ${job.importedRows} / ${job.totalRows}'),
            Text('Failed rows: ${job.failedRows}'),
            Text('Auto-categorized: ${job.autoCategorizedRows}'),
            if (job.duplicateRows > 0) Text('Duplicates skipped: ${job.duplicateRows}'),
            if (job.errorMessage != null) ..._buildRowErrors(context, job.errorMessage!),
            if (job.importedBalance != null) ...[
              const SizedBox(height: 8),
              Text(
                'Bank balance (last row)',
                style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.textMuted, fontSize: 12),
              ),
              Text(formatZAR(job.importedBalance), style: moneyTextStyle(context, fontSize: 24)),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _normalizing ? null : _normalize,
              child: Text(_normalizing ? 'Normalizing...' : 'Normalize with AI'),
            ),
            if (_normalizeMsg != null) ...[
              const SizedBox(height: 8),
              Text(_normalizeMsg!),
            ],
          ],
        ),
      ),
    );
  }
}

/// [errorMessage] is a JSON-encoded list of `{"row": int, "error": string}`
/// (see `backend/app/imports/router.py`). Falls back to the raw string if it
/// doesn't decode as expected, rather than crashing the result screen.
List<Widget> _buildRowErrors(BuildContext context, String errorMessage) {
  final mutedStyle =
      TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.textMuted, fontSize: 12);
  List<String> lines;
  try {
    final decoded = jsonDecode(errorMessage) as List<dynamic>;
    lines = decoded
        .map((e) => e is Map ? 'Row ${e['row']}: ${e['error']}' : e.toString())
        .toList();
  } catch (_) {
    lines = [errorMessage];
  }
  return [
    const SizedBox(height: 8),
    Text('Row errors', style: mutedStyle),
    const SizedBox(height: 4),
    ...lines.map((line) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(line, style: const TextStyle(fontSize: 13)),
        )),
  ];
}
