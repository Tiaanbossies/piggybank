import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
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
  PlatformFile? _selectedFile;
  String? _selectedTemplate;
  String? _selectedAccountId;
  bool _uploading = false;
  String? _uploadError;
  ImportJob? _result;

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
    setState(() {
      _selectedFile = result.files.single;
      _uploadError = null;
      _result = null;
    });
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
      });
      ref.invalidate(importHistoryProvider);
    } on ApiError catch (e) {
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickReceiptSource() async {
    final source = await showModalBottomSheet<_ReceiptSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(_ReceiptSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(_ReceiptSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose PDF'),
              onTap: () => Navigator.of(ctx).pop(_ReceiptSource.pdf),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

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
            Text('Scan receipt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _ocrLoading ? null : _pickReceiptSource,
                  icon: _ocrLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(_ocrLoading ? 'Processing...' : 'Choose photo or PDF'),
                ),
                if (_ocrResult != null) ...[
                  const SizedBox(width: 12),
                  _ConfidenceBadge(score: _ocrResult!.confidenceScore),
                ],
              ],
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
            Text('Import CSV', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
            OutlinedButton.icon(
              onPressed: _pickCsvFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_selectedFile == null ? 'Choose CSV file' : _selectedFile!.name),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_selectedFile == null || _uploading) ? null : _upload,
              child: _uploading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Upload'),
            ),
            if (_uploadError != null) ...[
              const SizedBox(height: 8),
              Text(_uploadError!, style: TextStyle(color: semantic?.danger)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(job: _result!),
            ],
            const SizedBox(height: 32),
            Text('Past imports', style: Theme.of(context).textTheme.titleMedium),
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
                        leadingIcon: Icons.description_outlined,
                        trailing: _StatusBadge(status: job.status),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ImportStatus status;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final Color fg;
    final Color? bg;
    switch (status) {
      case ImportStatus.completed:
        fg = semantic?.success ?? Colors.green;
        bg = semantic?.accentChipBg;
      case ImportStatus.partial:
        fg = Theme.of(context).colorScheme.primary;
        bg = semantic?.accentChipBg;
      case ImportStatus.failed:
        fg = semantic?.danger ?? Colors.red;
        bg = semantic?.dangerChipBg;
      case ImportStatus.pending:
        fg = semantic?.textMuted ?? Colors.grey;
        bg = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
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
                Text('Upload result', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 12),
                _StatusBadge(status: job.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('Imported: ${job.importedRows} / ${job.totalRows}'),
            Text('Failed rows: ${job.failedRows}'),
            Text('Auto-categorized: ${job.autoCategorizedRows}'),
            if (job.duplicateRows > 0) Text('Duplicates skipped: ${job.duplicateRows}'),
            if (job.importedBalance != null) Text('Bank balance (last row): ${formatZAR(job.importedBalance)}'),
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
