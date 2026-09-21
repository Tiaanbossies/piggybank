import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error.dart';
import '../../consent/consent_documents.dart';
import '../../consent/data/consents_api.dart';
import '../models/email_source.dart';
import '../models/gmail_connection_status.dart';
import '../models/notification_source.dart';
import '../providers/detection_provider.dart';
import 'pending_review_screen.dart';

/// Settings > Notification & email detection (plan §3/§5's "allowlist setup
/// screen"). Notifications (Phase D) and Gmail + the pending-review entry
/// point (Phase E) share this one screen rather than splitting into two —
/// both are the same "manage what Piggybank watches" concern, just two
/// different capture mechanisms feeding the same review queue.
class DetectionSettingsScreen extends ConsumerStatefulWidget {
  const DetectionSettingsScreen({super.key});

  @override
  ConsumerState<DetectionSettingsScreen> createState() => _DetectionSettingsScreenState();
}

class _DetectionSettingsScreenState extends ConsumerState<DetectionSettingsScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _consentAccepted = false;
  bool _listenerEnabled = false;
  List<NotificationSource> _sources = [];
  List<EmailSource> _emailSources = [];
  GmailConnectionStatus _gmailStatus = const GmailConnectionStatus(connected: false);
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notification-access grants happen in system settings, outside the
    // app — there's no callback for "just granted it," so re-check
    // whenever the user comes back (plan §3).
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final consents = ref.read(consentsApiProvider);
      final accepted = await consents.listAccepted();
      final consentAccepted = accepted.any(
        (c) =>
            c.documentType == notificationEmailDetectionConsentDocument.documentType &&
            c.documentVersion == notificationEmailDetectionConsentDocument.documentVersion,
      );

      final listenerEnabled = await ref.read(notificationListenerChannelProvider).isEnabled();

      List<NotificationSource> sources = [];
      List<EmailSource> emailSources = [];
      var gmailStatus = const GmailConnectionStatus(connected: false);
      if (consentAccepted) {
        final api = ref.read(detectionApiProvider);
        final results = await Future.wait([
          api.listNotificationSources(),
          api.listEmailSources(),
          api.getGmailStatus(),
        ]);
        sources = results[0] as List<NotificationSource>;
        emailSources = results[1] as List<EmailSource>;
        gmailStatus = results[2] as GmailConnectionStatus;
        // Re-sync on every load, not just after an add/remove — covers a
        // fresh install or reinstall where the native side's
        // SharedPreferences allowlist doesn't yet reflect what the
        // backend already has.
        await _syncAllowlistToDevice(sources);
      }

      if (!mounted) return;
      setState(() {
        _consentAccepted = consentAccepted;
        _listenerEnabled = listenerEnabled;
        _sources = sources;
        _emailSources = emailSources;
        _gmailStatus = gmailStatus;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptConsent() async {
    setState(() => _error = null);
    try {
      await ref.read(consentsApiProvider).accept(
            documentType: notificationEmailDetectionConsentDocument.documentType,
            documentVersion: notificationEmailDetectionConsentDocument.documentVersion,
          );
      await _load();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _syncAllowlistToDevice(List<NotificationSource> sources) async {
    final packages = sources.where((s) => s.isActive).map((s) => s.appPackageName).toList();
    await ref.read(notificationListenerChannelProvider).updateAllowlist(packages);
  }

  Future<void> _addSource() async {
    final result = await showDialog<({String package, String label})>(
      context: context,
      builder: (context) => const _AddSourceDialog(),
    );
    if (result == null) return;

    setState(() => _error = null);
    try {
      final added = await ref.read(detectionApiProvider).addNotificationSource(
            appPackageName: result.package,
            appLabel: result.label,
          );
      final next = [..._sources.where((s) => s.id != added.id), added];
      await _syncAllowlistToDevice(next);
      if (!mounted) return;
      setState(() => _sources = next);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _removeSource(NotificationSource source) async {
    setState(() => _error = null);
    try {
      await ref.read(detectionApiProvider).removeNotificationSource(source.id);
      final next = _sources.where((s) => s.id != source.id).toList();
      await _syncAllowlistToDevice(next);
      if (!mounted) return;
      setState(() => _sources = next);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _connectGmail() async {
    setState(() => _error = null);
    try {
      final url = await ref.read(detectionApiProvider).connectGmail();
      // Google's consent screen must run in the system browser, not an
      // in-app webview — this app never sees the resulting auth code, only
      // the backend's own /detection/email/callback does (plan §5).
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _disconnectGmail() async {
    setState(() => _error = null);
    try {
      await ref.read(detectionApiProvider).disconnectGmail();
      if (!mounted) return;
      setState(() => _gmailStatus = const GmailConnectionStatus(connected: false));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _addEmailSource() async {
    final result = await showDialog<({String email, String label})>(
      context: context,
      builder: (context) => const _AddEmailSourceDialog(),
    );
    if (result == null) return;

    setState(() => _error = null);
    try {
      final added =
          await ref.read(detectionApiProvider).addEmailSource(senderEmail: result.email, label: result.label);
      if (!mounted) return;
      setState(() => _emailSources = [..._emailSources.where((s) => s.id != added.id), added]);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _removeEmailSource(EmailSource source) async {
    setState(() => _error = null);
    try {
      await ref.read(detectionApiProvider).removeEmailSource(source.id);
      if (!mounted) return;
      setState(() => _emailSources = _emailSources.where((s) => s.id != source.id).toList());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification & email detection')),
      body: SafeArea(
        child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        const Text(
          'Piggybank can suggest transactions from notification banners posted by banking/investment '
          "apps you choose below. Nothing outside that list is ever read — and nothing is created "
          "automatically; every suggestion waits for your review.",
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(_consentAccepted ? Icons.check_circle_outline : Icons.privacy_tip_outlined),
            title: const Text('Feature consent'),
            subtitle: Text(_consentAccepted ? 'Accepted' : 'Not yet accepted'),
            trailing: _consentAccepted
                ? null
                : ElevatedButton(onPressed: _acceptConsent, child: const Text('Review & enable')),
          ),
        ),
        if (_consentAccepted) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(_listenerEnabled ? Icons.check_circle_outline : Icons.notifications_off_outlined),
              title: const Text('Notification access'),
              subtitle: Text(
                _listenerEnabled
                    ? 'Granted'
                    : 'Not granted — required so Piggybank can read allowlisted app notifications',
              ),
              trailing: _listenerEnabled
                  ? null
                  : ElevatedButton(
                      onPressed: () => ref.read(notificationListenerChannelProvider).openSystemSettings(),
                      child: const Text('Grant'),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Allowlisted apps', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(onPressed: _addSource, icon: const Icon(Icons.add), label: const Text('Add')),
            ],
          ),
          if (_sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No apps added yet. Add one to start getting transaction suggestions from it.'),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final source in _sources)
                    ListTile(
                      title: Text(source.appLabel),
                      subtitle: Text(source.appPackageName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove app',
                        onPressed: () => _removeSource(source),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text('Gmail', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(_gmailStatus.connected ? Icons.check_circle_outline : Icons.mail_outline),
              title: Text(_gmailStatus.connected ? 'Connected' : 'Not connected'),
              subtitle: Text(
                _gmailStatus.connected
                    ? 'Last checked: ${_gmailStatus.lastPolledAt?.toLocal() ?? 'not yet'}'
                    : 'Connect Gmail to detect transactions from senders you allowlist below.',
              ),
              trailing: _gmailStatus.connected
                  ? OutlinedButton(onPressed: _disconnectGmail, child: const Text('Disconnect'))
                  : ElevatedButton(onPressed: _connectGmail, child: const Text('Connect')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Allowlisted senders', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(onPressed: _addEmailSource, icon: const Icon(Icons.add), label: const Text('Add')),
            ],
          ),
          if (_emailSources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No senders added yet. Add one to start getting suggestions from their emails.'),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final source in _emailSources)
                    ListTile(
                      title: Text(source.label),
                      subtitle: Text(source.senderEmail),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove sender',
                        onPressed: () => _removeEmailSource(source),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PendingReviewScreen()),
            ),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Review detected items'),
          ),
        ],
      ],
    );
  }
}

class _AddEmailSourceDialog extends StatefulWidget {
  const _AddEmailSourceDialog();

  @override
  State<_AddEmailSourceDialog> createState() => _AddEmailSourceDialogState();
}

class _AddEmailSourceDialogState extends State<_AddEmailSourceDialog> {
  final _emailController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add sender to allowlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Sender email', hintText: 'e.g. alerts@easyequities.co.za'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label', hintText: 'e.g. EasyEquities alerts'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final email = _emailController.text.trim();
            final label = _labelController.text.trim();
            if (email.isEmpty || label.isEmpty) return;
            Navigator.of(context).pop((email: email, label: label));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog();

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  final _packageController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add app to allowlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _packageController,
            decoration: const InputDecoration(
              labelText: 'Package name',
              hintText: 'e.g. za.co.fnb.connect.itest',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label', hintText: 'e.g. FNB Banking App'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final package = _packageController.text.trim();
            final label = _labelController.text.trim();
            if (package.isEmpty || label.isEmpty) return;
            Navigator.of(context).pop((package: package, label: label));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
