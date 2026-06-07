part of '../../ksef.dart';

/// BT-3: Invoice type
enum KsefInvoiceType {
  /// Standard VAT invoice (default)
  vat, // FA/RodzajFaktury = VAT
  /// Correction invoice
  correction, // KOR
  /// Advance invoice
  advance, // ZAL
  /// Simplified invoice
  simplified, // UPR
}

/// BT-81: Payment method
/// FA(3) specific: Fa/Platnosc/FormaPlatnosci
enum KsefPaymentMethod {
  cash, // 1
  card, // 2
  voucher, // 3
  check, // 4
  credit, // 5
  bankTransfer, // 6
  mobile, // 7
  other, // none
}

/// FA(3) specific: VAT rates supported by Polish law
enum KsefVatRate {
  p23, // 23%  → P_12 = 23
  p8, // 8%   → P_12 = 8
  p5, // 5%   → P_12 = 5
  p0, // 0%   → P_12 = 0
  zw, // zwolniony (exempt) → P_12 = ZW
  np, // nie podlega (N/A)  → P_12 = NP
  oo, // odwrotne obciążenie (reverse charge) → P_12 = OO
}
