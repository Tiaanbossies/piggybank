/// Hardcoded consent-document copy, ported verbatim from
/// `finance-app.v3-main/frontend/src/pages/PrivacyPolicyPage.tsx` and
/// `TermsOfServicePage.tsx` — real, already-written product copy (both
/// "Draft — version 1.0"), not placeholder text.
///
/// TODO: keep in manual sync with `backend/app/consents/required.py`'s
/// `REQUIRED_DOCUMENTS` registry if either document's version is ever
/// bumped there — nothing wires these together automatically.
class ConsentDocument {
  const ConsentDocument({
    required this.documentType,
    required this.documentVersion,
    required this.label,
    required this.summary,
    required this.body,
  });

  /// Matches `RequiredDocument.type` / `ConsentRecord.document_type`.
  final String documentType;

  /// Matches `RequiredDocument.version` / `ConsentRecord.document_version`.
  final String documentVersion;

  /// Short title shown next to the checkbox.
  final String label;

  /// One-line description shown under [label] on the consent screen.
  final String summary;

  /// Full document text, shown in the "Read" dialog.
  final String body;
}

const privacyPolicyDocument = ConsentDocument(
  documentType: 'privacy_policy',
  documentVersion: '1.0',
  label: 'Privacy Policy',
  summary: 'How we collect, store, and use your personal and financial data.',
  body: '''
Draft — version 1.0. This document is being prepared in line with South Africa's Protection of Personal Information Act (POPIA) and has not yet had formal legal review. It describes what the app actually does today, honestly and specifically, rather than generic boilerplate.

WHAT WE COLLECT

Your account email and a hashed password (never the password itself — we use the argon2id hashing algorithm). Financial data you enter or import: bank/investment accounts, transactions, budgets, assets, liabilities, portfolio holdings, TFSA and retirement annuity contributions, and financial goals. If you set it, the day of the month your salary lands, used only to align budget periods to your pay cycle. Records of which version of this policy and the Terms of Service you accepted, and when.

WHY WE COLLECT IT

Solely to provide the app's core function: tracking and presenting your personal finances back to you — net worth, budgets, portfolio performance, and (where enabled) AI-generated insights about your own data. We do not sell your data or use it for advertising.

WHERE IT'S PROCESSED AND STORED

Your data is stored in a PostgreSQL database on infrastructure we operate directly, not a third-party cloud database service. Two features send limited data to external processors:

• AI chat and insights (only if enabled on your account): your questions and relevant account context are sent to a self-hosted language model running on our own infrastructure — not a third-party AI vendor.

• CSV import category cleanup: when you import a bank statement, transaction description text may be sent to Anthropic's Claude API (a US-based AI provider) to suggest consistent category names. This is the one point where data currently leaves South Africa. If you'd rather it didn't, you can categorize imported transactions manually instead.

HOW LONG WE KEEP IT

Transactions, assets, liabilities, and budgets are permanently deleted when you delete them — there is no recovery after that. Accounts are deactivated rather than deleted by default, so their transaction history stays intact unless you request full removal. If you delete your user account entirely, all associated data is permanently removed.

YOUR RIGHTS

Under POPIA, you can ask to see what personal information we hold about you, ask us to correct anything inaccurate, and ask us to delete your account and data. Formal channels for these requests (including an appointed Information Officer) are part of our pre-launch compliance work and not yet finalized — in the meantime, reach us through your account contact details.

SECURITY

Sessions use short-lived access tokens kept in memory (never in browser storage) and a longer-lived refresh token in an HttpOnly cookie that JavaScript can't read. All production traffic is served over HTTPS.
''',
);

const termsOfServiceDocument = ConsentDocument(
  documentType: 'terms_of_service',
  documentVersion: '1.0',
  label: 'Terms of Service',
  summary: 'The rules and conditions for using Finance App.',
  body: '''
Draft — version 1.0. Not yet reviewed by legal counsel. Describes the rules for using the app as it exists today.

WHAT THIS IS

A personal finance tracking tool for South African users: bank accounts, transactions, budgets, assets and liabilities, investment portfolios, TFSA and retirement annuity tracking, and net worth, all in one place. It is not a bank, does not move money on your behalf, and does not provide individualized financial advice.

YOUR ACCOUNT

You're responsible for the accuracy of the financial data you enter and for keeping your login credentials confidential. One account is for one person's finances — don't share your login.

PLANS

The app offers a Free tier and a paid Pro tier. Pro-tier features and pricing are shown on the Subscription page in the app and may change; you'll be notified of price changes before they apply to you.

NOT FINANCIAL ADVICE

Figures the app calculates or projects (loan amortisation, portfolio returns, retirement projections, AI-generated insights) are informational, based on the data you've provided, and are not a substitute for advice from a licensed financial adviser. Decisions you make based on them are your own.

ACCEPTABLE USE

Don't attempt to access another user's data, reverse-engineer the service to bypass security controls, or use it for any unlawful purpose.

CHANGES

If we materially change these terms or the Privacy Policy, we'll ask you to review and accept the new version before you can continue using the app — the same way you accepted this one.
''',
);

/// The two v1 consent documents, in the order they should be presented.
/// Matches `backend/app/consents/required.py`'s `REQUIRED_DOCUMENTS`.
const consentDocuments = [privacyPolicyDocument, termsOfServiceDocument];

/// Opt-in consent for the notification/email transaction-detection feature
/// (plan §1.4/§2.1 in `piggybank-backend/plans/notification-email-
/// transaction-detection.md`). Deliberately NOT in [consentDocuments] —
/// it's posted to the same `POST /consents/` endpoint, but only from the
/// detection setup screen, and gates only `require_detection_consent`
/// endpoints, not the whole app.
const notificationEmailDetectionConsentDocument = ConsentDocument(
  documentType: 'notification_email_detection',
  documentVersion: '1.0',
  label: 'Notification & email transaction detection',
  summary: 'Let Piggybank read notifications/emails from apps and senders you specifically choose, to suggest transactions.',
  body: '''
Draft — version 1.0. Describes an opt-in feature: nothing here happens until you also add at least one app or email sender to the allowlist on the setup screen.

WHAT THIS FEATURE DOES

When enabled and set up, Piggybank reads notification banners from the specific banking/investment apps you choose (never any other app) and, once you connect Gmail, emails from the specific sender addresses you choose (never your whole inbox). It uses a locally-hosted AI model to try to extract a transaction, dividend, or trade from that text.

Nothing is created automatically. Every extracted item lands in a review queue you must confirm or discard yourself before it becomes a real transaction, dividend, or trade in your data.

WHAT'S EXCLUDED BY DESIGN

Notifications from apps you haven't explicitly added are never read, parsed, captured, or sent anywhere — filtering happens on your device before anything leaves it. The same applies to email: only messages from senders you've explicitly added are ever looked at, and only your own account's Gmail, never anyone else's.

WHERE THE TEXT GOES

Notification/email text you've allowlisted is sent to Piggybank's backend and processed by the same self-hosted AI model used for other in-app AI features (see the main Privacy Policy) — never a third-party AI vendor, never leaves South Africa for this feature specifically.

TURNING IT OFF

Remove an app or sender from the allowlist at any time to stop it being read; disconnecting Gmail (Settings) revokes that access entirely. This consent itself has no separate withdrawal step today — removing every allowlisted source and disconnecting Gmail achieves the same practical effect.
''',
);
