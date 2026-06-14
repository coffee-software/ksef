part of '../../ksef.dart';

/// BT-27..BT-44: Seller or Buyer party data
/// Maps to FA(3): Podmiot1 (seller) or Podmiot2 (buyer)
class KsefParty {
  /// BT-31 / BT-48: Polish tax ID (NIP), 10 digits
  /// FA(3): DaneIdentyfikacyjne/NIP
  final String? nip;

  /// BT-27 / BT-44: Full company name
  /// FA(3): DaneIdentyfikacyjne/PelnaNazwa
  final String name;

  /// BT-40 / BT-55: Country code (ISO 3166-1 alpha-2), e.g. 'PL'
  /// FA(3): Adres/KodKraju
  final String countryCode;

  /// BT-35 / BT-50: Street address line 1
  /// FA(3): Adres/AdresL1
  final String addressLine1;

  /// BT-37+BT-38 / BT-52+BT-53: Postal code + city, e.g. '00-001 Warszawa'
  /// FA(3): Adres/AdresL2
  final String? addressLine2;

  /// BT-29 / BT-46: EU VAT prefix, e.g. 'PL' (optional, for EU transactions)
  /// FA(3): PrefiksPodatnika
  final String? euVatPrefix;

  const KsefParty({
    required this.nip,
    required this.name,
    required this.countryCode,
    required this.addressLine1,
    this.addressLine2,
    this.euVatPrefix,
  });
}
