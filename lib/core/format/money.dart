import 'package:decimal/decimal.dart';

/// Ports `frontend/src/lib/formatMoney.ts`'s `formatZAR` bit-for-bit: en-ZA
/// grouping (space thousands separator, comma decimal separator), leading
/// minus outside the `R` prefix, `R —` for unparseable input.
String formatZAR(Object? value) {
  double? n;
  if (value is num) {
    n = value.toDouble();
  } else if (value is Decimal) {
    n = value.toDouble();
  } else if (value is String) {
    n = double.tryParse(value);
  }
  if (n == null || n.isNaN) return 'R —';

  final abs = n.abs();
  final grouped = _groupWithSpaces(abs);
  return n < 0 ? '-R $grouped' : 'R $grouped';
}

String _groupWithSpaces(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  final reversed = intPart.split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < reversed.length; i++) {
    if (i != 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(reversed[i]);
  }
  final groupedInt = buffer.toString().split('').reversed.join();
  return '$groupedInt,$decPart';
}
