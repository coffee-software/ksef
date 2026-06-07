part of '../../ksef.dart';

/// FA(3) specific: Mandatory annotations (Adnotacje section)
/// These are Polish VAT-law specific flags, no EN 16931 equivalent
class KsefAnnotations {
  /// Split payment mechanism (mechanizm podzielonej płatności)
  /// FA(3): Adnotacje/P_20 — 1=tak, 0=nie
  final bool splitPayment;

  /// Reverse charge (odwrotne obciążenie)
  /// FA(3): Adnotacje/P_18
  final bool reverseCharge;

  /// Self-billing (samofakturowanie)
  /// FA(3): Adnotacje/P_17
  final bool selfBilling;

  /// OSS procedure (procedura OSS)
  /// FA(3): Adnotacje/P_18A
  final bool oss;

  /// Cash accounting scheme (metoda kasowa)
  /// FA(3): Adnotacje/P_21
  final bool cashAccounting;

  const KsefAnnotations({
    this.splitPayment = false,
    this.reverseCharge = false,
    this.selfBilling = false,
    this.oss = false,
    this.cashAccounting = false,
  });
}

/// BT-81+BT-84: Payment details
/// Maps to FA(3): Fa/Platnosc
class KsefPayment {
  /// BT-9: Payment due date
  /// FA(3): Platnosc/TerminPlatnosci/Termin
  final DateTime? dueDate;

  /// BT-81: Payment method
  /// FA(3): Platnosc/FormaPlatnosci
  final KsefPaymentMethod method;

  /// FA(3) specific: payment description if method == other
  /// FA(3): Platnosc/OpisPlatnosci
  final String? methodDescription;

  /// BT-84: Bank account IBAN
  /// FA(3): Platnosc/RachunekBankowy/NrRB
  final String? bankAccount;

  /// FA(3) specific: Bank name
  /// FA(3): Platnosc/RachunekBankowy/NazwaBanku
  final String? bankName;

  /// FA(3) specific: date of payment (required when paid = true)
  /// FA(3): Platnosc/Zaplacono = 1
  /// FA(3): Platnosc/DataZaplaty
  final DateTime? paidDate;

  const KsefPayment({
    required this.method,
    this.methodDescription,
    this.dueDate,
    this.bankAccount,
    this.bankName,
    this.paidDate,
  });
}

/// Field naming loosely follows EN 16931 Business Terms (BT) where applicable.
/// Reference: https://docs.peppol.eu/poacc/billing/3.0/bis/
/// Note: FA(3) does not fully comply with EN 16931 — Poland-specific fields
/// are documented inline where no BT equivalent exists.
/// Maps to FA(3): root Faktura element
class KsefInvoice {
  /// BT-1: Invoice number (unique, assigned by issuer)
  /// FA(3): Fa/P_2
  final String number;

  /// BT-2: Invoice issue date
  /// FA(3): Fa/P_1
  final DateTime issueDate;

  /// FA(3) specific: Place of issue (city name) — required by Polish law
  /// FA(3): Fa/P_1M
  final String? issuePlace;

  /// BT-7: Tax point date (supply/service date)
  /// FA(3): Fa/P_6
  final DateTime? taxPointDate;

  /// BT-3: Invoice type
  /// FA(3): Fa/RodzajFaktury
  final KsefInvoiceType type;

  /// BT-5: Currency code (ISO 4217), e.g. 'PLN', 'EUR'
  /// FA(3): Fa/KodWaluty
  final String currency;

  /// FA(3) specific: Exchange rate (required when currency != PLN)
  /// FA(3): Fa/KursWalutyZ
  final double? exchangeRate;

  /// BT-27..BT-44: Seller
  /// FA(3): Podmiot1
  final KsefParty seller;

  /// BT-44..BT-56: Buyer
  /// FA(3): Podmiot2
  final KsefParty buyer;

  /// BT-126..BT-161: Invoice line items
  /// FA(3): Fa/FaWiersz (one per line)
  final List<KsefInvoiceLine> lines;

  /// Pre-calculated totals. If null, will be calculated automatically
  /// from [lines] when [toXml] is called.
  /// Use [calcTotals] to preview or [validateTotals] to verify your own calculations.
  final KsefInvoiceTotals? totals;

  /// BT-9, BT-81, BT-84: Payment details
  /// FA(3): Fa/Platnosc
  final KsefPayment payment;

  /// FA(3) specific: Polish VAT law annotations
  /// FA(3): Fa/Adnotacje
  final KsefAnnotations annotations;

  /// BT-13: Purchase order number
  /// FA(3): Fa/WarunkiTransakcji/Zamowienia/NrZamowienia
  final String? orderNumber;

  /// FA(3): system info string
  final String systemInfo;

  const KsefInvoice({
    required this.number,
    required this.issueDate,
    required this.seller,
    required this.buyer,
    required this.lines,
    required this.payment,
    this.issuePlace,
    this.taxPointDate,
    this.type = KsefInvoiceType.vat,
    this.currency = 'PLN',
    this.exchangeRate,
    this.annotations = const KsefAnnotations(),
    this.orderNumber,
    this.systemInfo = 'ksef.dart',
    this.totals,
  });
}
