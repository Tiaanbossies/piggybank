// Screenshot harness: the real shell and tab screens on sample data, with
// real fonts, so design reviews and golden tests see the app as a phone does
// without signing in to the live backend.
//
// The API is faked at the HTTP layer (a Dio interceptor answering from
// [sampleResponses]), so every repository, provider and model runs unchanged.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/core/auth/auth_state.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/core/router/app_shell.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/features/chatbot/screens/chatbot_screen.dart';
import 'package:piggybank/features/dashboard/screens/dashboard_screen.dart';
import 'package:piggybank/features/plan/screens/plan_screen.dart';
import 'package:piggybank/features/portfolios/screens/invest_screen.dart';
import 'package:piggybank/features/transactions/screens/transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mid-range Android phone (412 × 915 dp at 2.625×, like a Pixel 7).
const phoneSize = Size(412, 915);
const phonePixelRatio = 2.625;

/// The five tab roots, in tab order (UX rework spec §1.1).
const tabRoots = ['/', '/transactions', '/plan', '/invest', '/assistant'];

Future<void> loadRealFonts() async {
  const dir = 'test/goldens/fonts';
  Future<ByteData> bytes(String file) async => ByteData.sublistView(await File('$dir/$file').readAsBytes());

  // google_fonts names each weight as its own family ("NunitoSans_700", with
  // 400 as "_regular"). Only the weights the spec uses are on disk, so the
  // others borrow the nearest one.
  const families = {
    // Display, headline, title and money (visual spec §1.5).
    'PlusJakartaSans': {
      300: 'PlusJakartaSans-Regular.ttf',
      400: 'PlusJakartaSans-Regular.ttf',
      500: 'PlusJakartaSans-Regular.ttf',
      600: 'PlusJakartaSans-Bold.ttf',
      700: 'PlusJakartaSans-Bold.ttf',
      800: 'PlusJakartaSans-ExtraBold.ttf',
    },
    // Body, label and overline.
    'NunitoSans': {
      300: 'NunitoSans-Regular.ttf',
      400: 'NunitoSans-Regular.ttf',
      500: 'NunitoSans-Regular.ttf',
      600: 'NunitoSans-SemiBold.ttf',
      700: 'NunitoSans-Bold.ttf',
      800: 'NunitoSans-Bold.ttf',
    },
  };
  const apiNames = {300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold'};

  // google_fonts still tries to fetch each weight it's asked for. Serve the
  // same files as if the app bundled them (test only; the app is unchanged)
  // and turn fetching off, so nothing reaches the network.
  final bundled = <String, String>{};
  for (final MapEntry(key: family, value: weights) in families.entries) {
    for (final MapEntry(key: weight, value: file) in weights.entries) {
      final suffix = weight == 400 ? 'regular' : '$weight';
      await (FontLoader('${family}_$suffix')..addFont(bytes(file))).load();
      bundled['google_fonts/$family-${apiNames[weight]}.ttf'] = file;
    }
    await (FontLoader(family)..addFont(bytes(weights[400]!))).load();
  }
  await (FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'))).load();
  await (FontLoader('Roboto')..addFont(bytes('NunitoSans-Regular.ttf'))).load();
  const realAssets = 'build/unit_test_assets';
  const codec = StandardMessageCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
      (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
    if (bundled[key] case final file?) return bytes(file);
    if (key == 'AssetManifest.bin') {
      final manifest = (codec.decodeMessage(ByteData.sublistView(await File('$realAssets/$key').readAsBytes())) as Map)
          .cast<Object?, Object?>();
      for (final path in bundled.keys) {
        manifest[path] = [
          {'asset': path},
        ];
      }
      return codec.encodeMessage(manifest);
    }
    final f = File('$realAssets/$key');
    return f.existsSync() ? ByteData.sublistView(await f.readAsBytes()) : null;
  });
  GoogleFonts.config.allowRuntimeFetching = false;
}

String _d(DateTime d) => d.toIso8601String().substring(0, 10);

/// Sample data for one believable month: a few accounts, budgets with one
/// over, goals in progress and done, a savings target, recent spending and
/// a small portfolio. Keyed by request path.
Map<String, Object?> sampleResponses(DateTime now) {
  final month = DateTime(now.year, now.month);
  final m = _d(month);
  final ts = now.toIso8601String();
  Map<String, Object?> tx(String id, String type, String cat, String amount, int daysAgo, String merchant, {String account = 'Everyday'}) => {
        'id': id,
        'account_id': 'a1',
        'transaction_type': type,
        'category': cat,
        'description': merchant,
        'amount': amount,
        'transaction_date': _d(now.subtract(Duration(days: daysAgo))),
        'merchant_name': merchant,
        'notes': null,
        'account_name': account,
      };
  final transactions = [
    tx('t1', 'expense', 'Groceries', '642.35', 0, 'Woolworths'),
    tx('t2', 'expense', 'Transport', '850.00', 1, 'Engen'),
    tx('t3', 'expense', 'Dining Out', '312.50', 1, 'Mugg & Bean'),
    tx('t4', 'income', 'Salary', '38500.00', 8, 'Employer'),
    tx('t5', 'expense', 'Subscriptions', '199.00', 3, 'Netflix'),
    tx('t6', 'expense', 'Groceries', '1284.90', 4, 'Checkers'),
    tx('t7', 'expense', 'Utilities', '1150.00', 6, 'City of Tshwane'),
    tx('t8', 'expense', 'Health', '420.00', 7, 'Clicks'),
    tx('t9', 'transfer', 'Transfer', '3000.00', 8, 'To savings', account: 'Savings'),
    tx('t10', 'expense', 'Dining Out', '186.00', 9, 'Uber Eats'),
  ];
  // Newest first, as the server returns them.
  transactions.sort((a, b) => b['transaction_date'].toString().compareTo(a['transaction_date'].toString()));
  Map<String, Object?> bp(String id, String cat, String amount, String spent, {String? parent}) {
    final a = double.parse(amount), s = double.parse(spent);
    return {
      'id': id,
      'month': m,
      'category': cat,
      'parent_budget_id': parent,
      'budget_amount': amount,
      'spent': spent,
      'remaining': (a - s).toStringAsFixed(2),
      'pct_used': a == 0 ? 0 : s / a * 100,
      'over_budget': s > a,
      'children': <Object?>[],
    };
  }

  return {
    '/accounts/': {
      'items': [
        {'id': 'a1', 'name': 'Everyday', 'account_type': 'checking', 'currency': 'ZAR', 'balance': '14820.55', 'is_active': true, 'institution_name': 'Capitec'},
        {'id': 'a2', 'name': 'Savings', 'account_type': 'savings', 'currency': 'ZAR', 'balance': '86400.00', 'is_active': true, 'institution_name': 'TymeBank'},
        {'id': 'a3', 'name': 'Credit card', 'account_type': 'credit_card', 'currency': 'ZAR', 'balance': '-4210.00', 'is_active': true, 'institution_name': 'FNB'},
      ],
      'total': 3,
    },
    '/transactions/': {'items': transactions, 'total': transactions.length},
    '/budgets/progress': [
      bp('b1', 'Groceries', '5000.00', '3410.25'),
      bp('b2', 'Dining Out', '1500.00', '1720.50'),
      bp('b3', 'Transport', '2500.00', '1850.00'),
      bp('b4', 'Utilities', '1800.00', '1150.00'),
      bp('b5', 'Entertainment', '800.00', '199.00'),
    ],
    '/budgets/': {'items': <Object?>[], 'total': 0},
    '/goals/': {
      'items': [
        {'id': 'g1', 'name': 'Emergency fund', 'target_amount': '150000.00', 'current_amount': '86400.00', 'target_date': '2027-06-01', 'category': null, 'status': 'active', 'notes': null, 'progress_pct': 57.6},
        {'id': 'g2', 'name': 'Cape Town trip', 'target_amount': '18000.00', 'current_amount': '6200.00', 'target_date': '2027-03-01', 'category': null, 'status': 'active', 'notes': null, 'progress_pct': 34.4},
        {'id': 'g3', 'name': 'New laptop', 'target_amount': '22000.00', 'current_amount': '22000.00', 'target_date': '2026-08-01', 'category': null, 'status': 'completed', 'notes': null, 'progress_pct': 100},
      ],
      'total': 3,
    },
    '/summaries/net-worth': {'total_assets': '248620.55', 'liabilities_total': '96210.00', 'net_worth': '152410.55'},
    '/summaries/cashflow': {'income_total': '38500.00', 'expense_total': '21480.40', 'net_cashflow': '17019.60'},
    '/summaries/budget-usage': {'budget_total': '11600.00', 'actual_spend': '8329.75', 'remaining': '3270.25', 'percent_used': '71.8'},
    '/summaries/net-worth-history': [
      for (var i = 5; i >= 0; i--)
        {'snapshot_date': _d(DateTime(now.year, now.month - i)), 'net_worth': (128000 + (5 - i) * 4900).toString()},
    ],
    '/savings/overview': {
      'target': {'id': 's1', 'label': 'Monthly saving', 'monthly_amount': '5000.00', 'target_date': null, 'income_override': null},
      'basis': 'month_to_date',
      'months_of_data': 4,
      'income': '38500.00',
      'income_is_override': false,
      'fixed_costs': '12400.00',
      'everyday_spending': '9080.40',
      'left_over': '3760.00',
      'gap': '1240.00',
      'target_met': false,
      'savings_found': '349.00',
      'confirmed_count': 2,
      'suggested_count': 1,
    },
    '/savings/recurring': <Object?>[],
    '/detection/pending': {
      'items': [
        {'id': 'e1', 'source_type': 'notification', 'source_ref': 'za.co.capitec', 'raw_text': 'Purchase R89.90 at Vida e Caffe', 'captured_at': ts, 'status': 'pending', 'extracted_json': {'amount': '89.90', 'merchant': 'Vida e Caffe', 'transaction_type': 'expense', 'category': 'Dining Out'}, 'event_kind': 'transaction', 'error_reason': null},
      ],
      'total': 1,
    },
    '/investments/overview': {
      'total_value': '61840.00',
      'total_cost': '52300.00',
      'unrealized_pl': '9540.00',
      'ytd_dividends': '1284.60',
      'portfolio_count': 2,
      'holding_count': 5,
      'allocation': [
        {'asset_class': 'equity', 'value': '43288.00', 'percent': '70'},
        {'asset_class': 'etf', 'value': '12368.00', 'percent': '20'},
        {'asset_class': 'cash', 'value': '6184.00', 'percent': '10'},
      ],
      'top_holdings': [
        {'holding_id': 'h1', 'portfolio_id': 'p1', 'ticker': 'STX40', 'name': 'Satrix 40', 'value': '24800.00', 'unrealized_pl': '3920.00'},
        {'holding_id': 'h2', 'portfolio_id': 'p1', 'ticker': 'NPN', 'name': 'Naspers', 'value': '18488.00', 'unrealized_pl': '4210.00'},
      ],
    },
    '/portfolios/': {
      'items': [
        {'id': 'p1', 'name': 'EasyEquities', 'description': null, 'currency': 'ZAR', 'portfolio_type': 'general', 'created_at': '2025-02-01T00:00:00Z', 'updated_at': ts},
        {'id': 'p2', 'name': 'Tax-free savings', 'description': null, 'currency': 'ZAR', 'portfolio_type': 'tfsa', 'created_at': '2025-03-01T00:00:00Z', 'updated_at': ts},
      ],
      'total': 2,
    },
    '/assets/': {
      'items': [
        {'id': 'as1', 'asset_type': 'property', 'name': 'Home (Centurion)', 'current_value': '1450000.00', 'valuation_date': '2026-06-01', 'institution_name': null, 'notes': null},
        {'id': 'as2', 'asset_type': 'vehicle', 'name': 'Polo Vivo', 'current_value': '165000.00', 'valuation_date': '2026-06-01', 'institution_name': null, 'notes': null},
      ],
      'total': 2,
    },
    '/liabilities/': {
      'items': [
        {'id': 'l1', 'liability_type': 'mortgage', 'name': 'Home loan', 'outstanding_amount': '1385000.00', 'original_balance': '1500000.00', 'interest_rate': '11.25', 'term_months': 240, 'start_date': '2023-03-01'},
      ],
      'total': 1,
    },
    '/portfolios/p1/value': {'portfolio_id': 'p1', 'total_cost': '38100.00', 'total_value': '45288.00', 'unrealized_pl': '7188.00', 'realized_pl': '0', 'currency': 'ZAR'},
    '/portfolios/p2/value': {'portfolio_id': 'p2', 'total_cost': '14200.00', 'total_value': '16552.00', 'unrealized_pl': '2352.00', 'realized_pl': '0', 'currency': 'ZAR'},
  };
}

/// Answers every request from [responses]; anything unknown is a 404, so a
/// missing fixture shows up as the screen's own error state, not a crash.
class _FixtureInterceptor extends Interceptor {
  _FixtureInterceptor(this.responses);
  final Map<String, Object?> responses;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (responses.containsKey(path)) {
      // Round-trip through JSON so models parse exactly what a server sends.
      var data = jsonDecode(jsonEncode(responses[path]));
      if (path == '/transactions/') data = _filterTransactions(data as Map<String, dynamic>, options.queryParameters);
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: data));
    } else {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404, data: {'detail': 'No sample for $path'}),
        type: DioExceptionType.badResponse,
      ));
    }
  }
}

/// Applies the list endpoint's filters, so "spent today" and filtered views
/// see what the server would return.
Map<String, dynamic> _filterTransactions(Map<String, dynamic> page, Map<String, dynamic> q) {
  bool keep(Map<String, dynamic> t) {
    final date = t['transaction_date'] as String;
    if (q['date_from'] case final String from when date.compareTo(from) < 0) return false;
    if (q['date_to'] case final String to when date.compareTo(to) > 0) return false;
    if (q['transaction_type'] case final String type when t['transaction_type'] != type) return false;
    if (q['category'] case final String cat when t['category'] != cat) return false;
    if (q['account_id'] case final String id when t['account_id'] != id) return false;
    return true;
  }

  final items = (page['items'] as List).cast<Map<String, dynamic>>().where(keep).toList();
  return {'items': items, 'total': items.length};
}

ApiClient sampleApiClient(DateTime now) {
  final dio = Dio(BaseOptions(baseUrl: 'https://sample.invalid'));
  dio.interceptors.add(_FixtureInterceptor(sampleResponses(now)));
  return ApiClient(
    baseUrl: 'https://sample.invalid',
    getAccessToken: () => 'sample',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
    dio: dio,
  );
}

/// A signed-in sample user, so screens that read the session render as they
/// would on a device. Anything beyond reading [state] is unimplemented: the
/// harness never logs in, out or unlocks.
class _SampleAuth extends StateNotifier<AuthState> implements AuthController {
  _SampleAuth()
      : super(const AuthState(
          status: AuthStatus.authenticated,
          accessToken: 'sample',
          user: User(id: 'u1', email: 'thandi@example.com', fullName: 'Thandi Mokoena', role: 'user', isActive: true),
        ));

  /// The lock screen offers biometrics on open; the sample device has none.
  @override
  Future<bool> unlockWithBiometrics() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides(SharedPreferences prefs, DateTime now) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(sampleApiClient(now)),
      authControllerProvider.overrideWith((ref) => _SampleAuth()),
    ];

GoRouter _shellRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/transactions', builder: (_, _) => const TransactionsScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/plan', builder: (_, _) => const PlanScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/invest', builder: (_, _) => const InvestScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/assistant', builder: (_, _) => const ChatbotScreen())]),
          ],
        ),
        GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: SizedBox())),
      ],
    );

/// Pumps the shell at [location] on a phone-sized surface, settled.
Future<void> pumpShell(WidgetTester tester, String location, {required ThemeMode mode}) =>
    _pump(tester, mode, (theme, dark) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: dark,
          themeMode: mode,
          routerConfig: _shellRouter(location),
        ));

/// Pumps a single [screen] (a pushed screen or a pre-shell one like Login)
/// on the same surface, data and session as [pumpShell].
Future<void> pumpScreen(WidgetTester tester, Widget screen, {required ThemeMode mode}) =>
    _pump(tester, mode, (theme, dark) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: dark,
          themeMode: mode,
          home: screen,
        ));

Future<void> _pump(WidgetTester tester, ThemeMode mode, Widget Function(ThemeData, ThemeData) app) async {
  tester.view.physicalSize = phoneSize * phonePixelRatio;
  tester.view.devicePixelRatio = phonePixelRatio;
  addTearDown(tester.view.reset);
  // flutter_test draws elevation as a hard black outline by default; render
  // real shadows so screenshots match the device. Callers reset it with
  // [endShot] before the test ends (flutter_test checks it's unset).
  debugDisableShadows = false;

  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'Piggybank',
    packageName: 'za.co.fynboscreative.piggybank',
    version: '1.0.8',
    buildNumber: '9',
    buildSignature: '',
  );
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, DateTime.now()),
      child: app(AppTheme.light(), AppTheme.dark()),
    ),
  );
  await settle(tester);
}

/// Lets fixtures resolve and entrance motion finish, without waiting forever
/// on looping animations (Penny's thinking bob).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Restores the painting flag [pumpShell] changed; call last in each test.
void endShot() => debugDisableShadows = true;
