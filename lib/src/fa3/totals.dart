part of '../../ksef.dart';

/// Totals for a specific VAT rate
/// FA(3) specific — grouped by Polish VAT rate
class KsefVatTotal {
  /// Net amount sum for this VAT rate
  final double netAmount;

  /// VAT amount for this rate (0 for ZW/NP/OO)
  final double vatAmount;

  const KsefVatTotal({required this.netAmount, required this.vatAmount});
}

/// Calculated invoice totals
class KsefInvoiceTotals {
  /// Net totals grouped by VAT rate
  /// FA(3): P_13_1/P_14_1 (23%), P_13_2/P_14_2 (8%), etc.
  final Map<KsefVatRate, KsefVatTotal> byRate;

  /// BT-109: Total gross amount
  /// FA(3): Fa/P_15
  final double grossTotal;

  const KsefInvoiceTotals({required this.byRate, required this.grossTotal});

  /// Net total across all rates (sum of all byRate.netAmount)
  double get netTotal => byRate.values.fold(0, (s, t) => s + t.netAmount);

  /// VAT total across all rates
  double get vatTotal => byRate.values.fold(0, (s, t) => s + t.vatAmount);
}

/// Calculates invoice totals from line items.
/// Amounts are rounded to 2 decimal places per Polish VAT law requirements.
KsefInvoiceTotals calcTotals(List<KsefInvoiceLine> lines) {
  final map = <KsefVatRate, ({double net, double vat})>{};

  for (final line in lines) {
    final current = map[line.vatRate] ?? (net: 0.0, vat: 0.0);
    final vatAmount = _calcVatAmount(line.effectiveNetAmount, line.vatRate);
    map[line.vatRate] = (
      net: _round(current.net + line.effectiveNetAmount),
      vat: _round(current.vat + vatAmount),
    );
  }

  final byRate = map.map(
    (rate, t) => MapEntry(rate, KsefVatTotal(netAmount: t.net, vatAmount: t.vat)),
  );

  final gross = _round(byRate.values.fold(0.0, (s, t) => s + t.netAmount + t.vatAmount));

  return KsefInvoiceTotals(byRate: byRate, grossTotal: gross);
}

double _calcVatAmount(double netAmount, KsefVatRate rate) => switch (rate) {
  KsefVatRate.p23 => _round(netAmount * 0.23),
  KsefVatRate.p22 => _round(netAmount * 0.22),
  KsefVatRate.p8 => _round(netAmount * 0.08),
  KsefVatRate.p7 => _round(netAmount * 0.07),
  KsefVatRate.p5 => _round(netAmount * 0.05),
  KsefVatRate.p4 => _round(netAmount * 0.04),
  KsefVatRate.p3 => _round(netAmount * 0.03),
  KsefVatRate.p0kr => 0,
  KsefVatRate.p0wdt => 0,
  KsefVatRate.p0ex => 0,
  KsefVatRate.zw => 0,
  KsefVatRate.np1 => 0,
  KsefVatRate.np2 => 0,
  KsefVatRate.oo => 0,
};

double _round(double v) => double.parse(v.toStringAsFixed(2));
