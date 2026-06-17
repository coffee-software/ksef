import 'dart:convert';
import 'package:http/http.dart' as http;

/// A single exchange rate entry returned by the NBP API.
class NbpRate {
  /// The currency code (e.g. "EUR", "USD").
  final String currency;

  /// The ISO 4217 currency code.
  final String code;

  /// The NBP table number (e.g. "121/A/NBP/2025").
  final String tableNo;

  /// The date for which this rate is effective.
  final DateTime effectiveDate;

  /// The average (mid) exchange rate against PLN.
  final double mid;

  const NbpRate({
    required this.currency,
    required this.code,
    required this.tableNo,
    required this.effectiveDate,
    required this.mid,
  });
}

/// Thrown when the NBP API returns an unexpected error.
class NbpException implements Exception {
  final String message;
  const NbpException(this.message);

  @override
  String toString() => 'NbpException: $message';
}

/// Simple client for the NBP (Narodowy Bank Polski) Web API (https://api.nbp.pl).
/// Implements the exchange-rate lookup rules for KSeF invoices.
class NbpClient {
  static const String _baseUrl = 'https://api.nbp.pl/api';

  /// How many days to walk back when a date falls on a weekend or holiday.
  static const int _maxLookbackDays = 7;

  NbpClient();

  /// Returns the NBP average rate for [currency] for given tax obligation date.
  ///
  /// Per art. 31a ust. 1 ustawy o VAT: the applicable rate is the NBP average
  /// from the **last working day preceding [taxObligationDate]**.
  ///
  /// We assume here that NBP will publish rates on days that are considered working days.
  ///
  /// Example: for invoice issued on 2025-06-23 (Monday) we will return rate for 2025-06-20 (Friday).
  Future<NbpRate> rateForTaxObligationDate({
    required String currency,
    required DateTime taxObligationDate,
  }) {
    final lookupFrom = taxObligationDate.subtract(const Duration(days: 1));
    return _rateOnOrBefore(currency.toUpperCase(), lookupFrom);
  }

  Future<NbpRate> _rateOnOrBefore(String currency, DateTime endDate) async {
    final startDate = endDate.subtract(Duration(days: _maxLookbackDays));
    final url = Uri.parse(
      '$_baseUrl/exchangerates/rates/a/$currency/${_fmt(startDate)}/${_fmt(endDate)}/?format=json',
    );
    final http.Response response;
    try {
      response = await http.get(url);
    } catch (e) {
      throw NbpException('Network error contacting NBP API: $e');
    }

    if (response.statusCode != 200) {
      throw NbpException(
        'NBP API returned HTTP ${response.statusCode} for $currency: ${response.body}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;

      final rates = json['rates'] as List<dynamic>;
      final last = rates.last as Map<String, dynamic>;

      return NbpRate(
        currency: json['currency'] as String,
        code: json['code'] as String,
        tableNo: last['no'] as String,
        effectiveDate: DateTime.parse(last['effectiveDate'] as String),
        mid: (last['mid'] as num).toDouble(),
      );
    } catch (e) {
      throw NbpException('Failed to parse NBP API response: $e');
    }
  }

  /// Formats a [DateTime] as YYYY-MM-DD for the NBP API.
  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
