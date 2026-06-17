# ksef

Simple, unofficial Dart client for the [KSeF API](https://api.ksef.mf.gov.pl/docs/v2/index.html).

KSeF (Krajowy System e-Faktur) is Poland's official platform for structured
electronic invoicing, mandatory for all Polish VAT taxpayers since February 2026.

This library is used by [swift.shop](https://swift.shop), an open source eCommerce 
framework to automatically issue invoices after payment.

## Features

- Authentication via KSeF token (with RSA-OAEP encrypted challenge flow)
- AES-256 encrypted session management
- Sending raw FA(3) invoice XMLs to KSeF
- Polling invoice status with timeout handling
- Fetching invoices by KSeF reference numbers
- Generating FA(3) invoice XMLs using human-friendly named static types
- Automatic invoice totals calculation
- Verify token permissions for reading and writing invoices
- Fetch NBP exchange rates for foreign-currency invoices

## Installation

```dart
dart pub add ksef
```
## Usage

```dart
import 'package:ksef/ksef.dart';

Future<void> main() async {
  
    final client = KsefClient(
        KsefEnvironment.prod, // or KsefEnvironment.test 
        'YOUR_NIP', // 10-digit Polish tax identifier
        'YOUR_KSEF_TOKEN' // generated in the KSeF web panel
    );
    // authenticate and open an AES-encrypted session
    final session = await client.openSession();
    try {
      // send a raw FA(3) invoice XML
      final invoiceRequest = await session.sendInvoice(KsefInvoice(
        /* YOUR_INVOICE_DETAILS */
      ));

      // poll until accepted or rejected (default timeout: 1 minute)
      final invoiceStatus = await session.waitForInvoiceStatus(
        invoiceRequest,
        timeout: const Duration(minutes: 5),
      );
      
      if (invoiceStatus.code == KsefInvoiceStatusCode.accepted) {
        print('Issued: ${invoiceStatus.ksefNumber}');
      } else if (invoiceStatus.code == KsefInvoiceStatusCode.duplicate) {
        print('Duplicate of: ${invoiceStatus.ksefNumber}');
      } else {
        print('Failed: ${invoiceStatus.errorInfo}');
      }
    } finally {
      await session.close(); // always close, even on error
    }
}
```

For a complete working example see `example/main.dart`

### Invoice XML Generation

KSeF requires invoices in FA(3) XML format with fields named `P_1`, `P_2`, `P_13_1` etc.
which is not exactly readable. The library provides a typed Dart model using human-friendly names
loosely based on [EN 16931 Business Terms](https://docs.peppol.eu/poacc/billing/3.0/bis/):

```dart

final invoice = KsefInvoice(
  number: 'FV/2026/05/0001',
  issueDate: DateTime(2026, 5, 8),
  seller: KsefParty(nip: '1231231230', name: 'ACME Sp. z o.o.', countryCode: 'PL', addressLine1: 'ul. Testowa 1'),
  buyer: KsefParty(nip: '1231231230', name: 'Buyer Corp S.A.', countryCode: 'PL', addressLine1: 'ul. Testowa 2'),
  lines: [
    KsefInvoiceLine(
      description: 'Web development services',
      quantity: 1,
      unitNetPrice: 10000, // = 100.00 PLN (prices are stored in minor currency units)
      vatRate: KsefVatRate.p23,
    ),
  ],
  payment: KsefPayment(
    dueDate: DateTime(2026, 5, 15),
    method: KsefPaymentMethod.bankTransfer,
    bankAccount: 'PL12123412341234123412341234',
  ),
);

await session.sendInvoice(invoice);
```

Alternatively, `sendRawInvoice()` accepts raw FA(3) XML if you need full control or already have FA(3) XML generated
from other software.

Invoice totals are calculated unless you provide `forceTotals` field explicitly.

All monetary amounts use integers in minor currency units (e.g. grosz for PLN,
cent for EUR) to avoid floating-point precision errors. Values are converted
to decimal strings with the correct number of fractional digits when generating XML.

### NBP Currency Rates

Polish VAT law (art. 31a) requires non-PLN invoices to include the NBP average exchange
rate used to convert the VAT amount to PLN. The applicable rate is always from the last
working day preceding the invoice issue date - meaning weekends and public holidays are
skipped automatically.

`NbpClient` fetches the correct rate from the [NBP Web API](https://api.nbp.pl/) and
handles non-working day fallback for you.

```dart
import 'package:ksef/ksef.dart';
import 'package:ksef/nbp.dart';

Future<void> main() async {
  final currency = 'USD';
  final issueDate = DateTime.now();

  final invoice = KsefInvoice(
    //...
      issueDate: issueDate,
      currency: currency,
      exchangeRate: (await NbpClient().rateForTaxObligationDate(currency: currency, taxObligationDate: issueDate)).mid
    //...
  );
}
```

## Roadmap

Feel free to contribute.

- Typed correction invoice model (`KsefCorrectionInvoice`)
- Batch session support
- Offline invoices
- Invoice PDF generation (likely as a separate `ksef_pdf` package to keep
  dependencies minimal)

## Running tests:

Copy `test/config.yaml.example` to `test/config.yaml`, fill in your KSeF
test environment credentials, then run:

```
dart test
```

## Resources

- [Official KSeF API docs (CIRFMF)](https://github.com/CIRFMF/ksef-docs)
- [KSeF API v2 reference](https://api.ksef.mf.gov.pl/docs/v2/index.html)
- [EN 16931 Business Terms](https://docs.peppol.eu/poacc/billing/3.0/bis/)

## Disclaimers

This is an unofficial library, not affiliated with or endorsed by the Polish
Ministry of Finance.

Although this library is used in production by **swift.shop** sellers, only a subset
of FA(3) fields is currently covered. If you plan to use the `KsefInvoice` XML
generator, it is recommended to first generate a similar invoice using the KSeF web
panel and compare the resulting XMLs before sending to the KSeF production environment.
Please report any discrepancies or missing fields at
https://github.com/coffee-software/ksef/issues
