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
- Fetching invoice by KSeF reference number
- Generating invoice XMLs
- Invoice totals calculation

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
      unitNetPrice: 100.00,
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

Alternatively, `sendRawInvoice()` accepts raw FA(3) XML if you need full control or already have FA(3) XML generated from other software.

Invoice totals are calculated unless you provide `totals` field explicitly.

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

## Disclaimer

This is an unofficial library, not affiliated with or endorsed by the Polish
Ministry of Finance.