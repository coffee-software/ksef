part of '../../ksef.dart';

/// BT-126..BT-161: Single invoice line item
/// Maps to FA(3): Fa/FaWiersz
class KsefInvoiceLine {
  /// BT-155: Line number (1-based)
  /// FA(3): NrWierszaFa
  final int lineNumber;

  /// BT-153: Item/service description
  /// FA(3): P_7
  final String description;

  /// BT-130: Unit of measure, e.g. 'szt', 'usł', 'kg'
  /// FA(3): P_8A
  final String unit;

  /// BT-129: Quantity
  /// FA(3): P_8B
  final double quantity;

  /// BT-146: Unit net price
  /// FA(3): P_9A
  /// in minor currency units (e.g. grosz for PLN, cent for EUR)
  final int unitNetPrice;

  /// BT-131: Line net amount (quantity * unitNetPrice)
  /// FA(3): P_11
  /// in minor currency units (e.g. grosz for PLN, cent for EUR)
  final int? netAmount;

  /// FA(3) specific: VAT rate for this line
  /// FA(3): P_12
  final KsefVatRate vatRate;

  /// BT-154: Item description (optional, additional)
  /// FA(3): P_7 (used when different from description)
  final String? gtu; // FA(3) specific: GTU code (e.g. GTU_01..GTU_13)

  const KsefInvoiceLine({
    required this.lineNumber,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitNetPrice,
    required this.vatRate,
    this.netAmount,
    this.gtu,
  });

  /// Effective net amount
  /// this might be extended in the future to add discount functionality.
  int get effectiveNetAmount => netAmount ?? _round(quantity * unitNetPrice);
}
