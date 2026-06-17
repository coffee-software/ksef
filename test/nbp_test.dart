library;

import 'package:test/test.dart';
import 'package:ksef/ksef.dart';
import 'package:ksef/nbp.dart';

void main() {
  test('look up for holiday', () async {
    final rate = await NbpClient().rateForTaxObligationDate(
      currency: 'EUR',
      taxObligationDate: DateTime(2026, 4, 7),
    );

    expect(rate.mid, equals(4.2776));
    expect(rate.code, equals('EUR'));
    expect(rate.effectiveDate, equals(DateTime(2026, 4, 3)));
  });

  test('look up for working day', () async {
    final rate = await NbpClient().rateForTaxObligationDate(
      currency: 'TRY',
      taxObligationDate: DateTime(2026, 6, 17),
    );

    expect(rate.mid, equals(0.079));
    expect(rate.code, equals('TRY'));
    expect(rate.effectiveDate, equals(DateTime(2026, 6, 16)));
  });

  test('generating invoice with currency rate', () async {
    final currency = 'USD';
    final issueDate = DateTime(2026, 4, 7);
    final party = KsefParty(
      nip: '1231231231',
      name: 'ACME Sp. z o.o.',
      countryCode: 'PL',
      addressLine1: 'ul. Testowa 1',
    );
    final invoice = KsefInvoice(
      number: 'TEST',
      issueDate: issueDate,
      currency: currency,
      exchangeRate: (await NbpClient().rateForTaxObligationDate(
        currency: currency,
        taxObligationDate: issueDate,
      )).mid,
      seller: party,
      buyer: party,
      lines: [
        KsefInvoiceLine(
          lineNumber: 1,
          description: 'example service',
          unit: 'usł',
          quantity: 2,
          unitNetPrice: 10000,
          vatRate: KsefVatRate.p23,
        ),
      ],
      payment: KsefPayment(
        method: KsefPaymentMethod.other,
        methodDescription: 'TEST_OPIS_PLATNOSCI',
        paidDate: issueDate,
      ),
    );
    final xml = invoice.toXml();

    expect(xml, contains('<KodWaluty>USD</KodWaluty>'));
    expect(xml, contains('<KursWaluty>3.705800</KursWaluty>'));
  });
}
