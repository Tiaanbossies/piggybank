import 'package:flutter/material.dart';

import 'models/holding.dart';

/// Chart/legend colours for [AssetClass] — distinct from the app's
/// success/danger palette (those are reserved for P&L direction), used by
/// `AllocationDonut` (Invest tab-root) and `AllocationBar` (Portfolio
/// Detail) so both allocation views share one consistent colour key.
const Map<AssetClass, Color> assetClassColors = {
  AssetClass.stock: Color(0xFF3B82F6),
  AssetClass.equity: Color(0xFF8B5CF6),
  AssetClass.bond: Color(0xFFF59E0B),
  AssetClass.etf: Color(0xFF06B6D4),
  AssetClass.crypto: Color(0xFFEC4899),
  AssetClass.cash: Color(0xFF14B8A6),
  AssetClass.other: Color(0xFF9CA3AF),
};

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
