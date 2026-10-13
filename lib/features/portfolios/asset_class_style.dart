import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/chart_style.dart';
import 'models/holding.dart';

/// Chart/legend colour for [AssetClass], from the chart ramp (visual spec
/// §1.3) so it follows light and dark: the four ramp colours first, two
/// lighter steps of them for the rarer classes, and the neutral for
/// "other". Shared by `AllocationDonut` (Invest) and `AllocationBar`
/// (Portfolio Detail) so both allocation views read with one key. The
/// legend's labels carry the meaning; the colour only groups.
Color assetClassColor(AppTokens t, AssetClass assetClass) {
  final ramp = chartPalette(t);
  return switch (assetClass) {
    AssetClass.stock => ramp[0],
    AssetClass.etf => ramp[1],
    AssetClass.bond => ramp[2],
    AssetClass.cash => ramp[3],
    AssetClass.equity => chartTint(t, ramp[0]),
    AssetClass.crypto => chartTint(t, ramp[2]),
    AssetClass.other => ramp[4],
  };
}

/// A gain reads "+R 1 200,00" in green; a loss "−R 300,00" in ink. Red is
/// kept for over budget and destructive actions (J4), and a paper loss is
/// neither.
String signedPl(Decimal pl) {
  if (pl > Decimal.zero) return '+${formatZAR(pl)}';
  if (pl < Decimal.zero) return '\u2212${formatZAR(-pl)}';
  return formatZAR(pl);
}

Color plColor(AppTokens t, Decimal pl) => pl > Decimal.zero ? t.positive : t.ink;

const Map<AssetClass, IconData> assetClassIcons = {
  AssetClass.stock: Icons.show_chart,
  AssetClass.equity: Icons.pie_chart_outline,
  AssetClass.bond: Icons.account_balance_outlined,
  AssetClass.etf: Icons.dashboard_outlined,
  AssetClass.crypto: Icons.currency_bitcoin,
  AssetClass.cash: Icons.payments_outlined,
  AssetClass.other: Icons.more_horiz,
};

/// Heuristic mapping from yfinance's `quoteType` (surfaced as
/// `TickerSearchResult.instrumentType`) to our [AssetClass] enum — the
/// backend has no asset-class field of its own for a looked-up ticker, so
/// the Add/Edit Holding autocomplete infers one from the search result
/// instead of leaving it unset.
AssetClass inferAssetClassFromInstrumentType(String instrumentType) {
  switch (instrumentType.toUpperCase()) {
    case 'ETF':
    case 'MUTUALFUND':
      return AssetClass.etf;
    case 'EQUITY':
      return AssetClass.stock;
    case 'CRYPTOCURRENCY':
      return AssetClass.crypto;
    case 'BOND':
      return AssetClass.bond;
    case 'CURRENCY':
      return AssetClass.cash;
    default:
      return AssetClass.other;
  }
}
