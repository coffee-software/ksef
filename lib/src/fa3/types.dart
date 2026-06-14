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
  p22, // 22%  → P_12 = 22
  p8, // 8%   → P_12 = 8
  p7, // 7%  → P_12 = 7
  p5, // 5%   → P_12 = 5
  p4, // 4%  → P_12 = 4
  p3, // 3%  → P_12 = 3
  p0kr, // 0%   → P_12 = '0 KR' Stawka 0% w przypadku sprzedaży towarów i świadczenia usług na terytorium kraju (z wyłączeniem WDT i eksportu)
  p0wdt, // 0%   → P_12 = '0 WDT' Stawka 0% w przypadku wewnątrzwspólnotowej dostawy towarów (WDT)
  p0ex, // 0%   → P_12 = '0 EX' Stawka 0% w przypadku eksportu towarów
  zw, // (exempt) → P_12 = 'zw' zwolnione od podatku
  np1, // nie podlega → P_12 = 'np I' niepodlegające opodatkowaniu- dostawy towarów oraz świadczenia usług poza terytorium kraju, z wyłączeniem transakcji, o których mowa w art. 100 ust. 1 pkt 4 ustawy oraz OSS
  np2, // nie podlega → P_12 = 'np II' niepodlegajace opodatkowaniu na terytorium kraju, świadczenie usług o których mowa w art. 100 ust. 1 pkt 4 ustawy
  oo, // (reverse charge) → P_12 = 'oo' odwrotne obciążenie
}
