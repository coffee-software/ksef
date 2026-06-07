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

/// Validates provided totals against values calculated from lines.
/// Returns list of discrepancies — empty list means totals are correct.
List<String> validateTotals(KsefInvoiceTotals provided, List<KsefInvoiceLine> lines) {
  final calculated = calcTotals(lines);
  final errors = <String>[];

  for (final rate in KsefVatRate.values) {
    final calc = calculated.byRate[rate];
    final prov = provided.byRate[rate];

    if (calc == null && prov == null) continue;

    if (calc == null && prov != null) {
      errors.add(
        '${rate.name}: provided net=${prov.netAmount} vat=${prov.vatAmount} '
        'but no lines with this rate found',
      );
      continue;
    }

    if (calc != null && prov == null) {
      errors.add(
        '${rate.name}: missing totals — expected net=${calc.netAmount} vat=${calc.vatAmount}',
      );
      continue;
    }

    if (_round(calc!.netAmount) != _round(prov!.netAmount)) {
      errors.add(
        '${rate.name}: net mismatch — provided=${prov.netAmount} calculated=${calc.netAmount}',
      );
    }
    if (_round(calc.vatAmount) != _round(prov.vatAmount)) {
      errors.add(
        '${rate.name}: vat mismatch — provided=${prov.vatAmount} calculated=${calc.vatAmount}',
      );
    }
  }

  if (_round(provided.grossTotal) != _round(calculated.grossTotal)) {
    errors.add(
      'grossTotal mismatch — provided=${provided.grossTotal} calculated=${calculated.grossTotal}',
    );
  }

  return errors;
}

double _calcVatAmount(double netAmount, KsefVatRate rate) => switch (rate) {
  KsefVatRate.p23 => _round(netAmount * 0.23),
  KsefVatRate.p8 => _round(netAmount * 0.08),
  KsefVatRate.p5 => _round(netAmount * 0.05),
  KsefVatRate.p0 => 0,
  KsefVatRate.zw => 0,
  KsefVatRate.np => 0,
  KsefVatRate.oo => 0,
};

double _round(double v) => double.parse(v.toStringAsFixed(2));
