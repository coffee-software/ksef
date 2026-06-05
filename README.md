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
        "YOUR_NIP", // 10-digit Polish tax identifier
        "YOUR_KSEF_TOKEN" // generated in the KSeF web panel
    );
    // authenticate and open an AES-encrypted session
    final session = await client.openSession();
    try {
      // send a raw FA(3) invoice XML
      final invoiceRequest = await session.sendRawInvoice(rawInvoiceXml);

      // poll until accepted or rejected (default timeout: 1 minute)
      final invoiceStatus = await session.waitForInvoiceStatus(
        invoice,
        timeout: const Duration(minutes: 5),
      );
      
      if (invoiceStatus.code == KsefInvoiceStatus.accepted) {
        print('Issued: ${invoiceStatus.ksefNumber}');
      } else if (invoiceStatus.code == KsefInvoiceStatus.duplicate) {
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

- Support for more KSeF endpoints (offline invoices, batch sending, privileges, etc.)
- Typed, generated invoice model from official FA(3) XSD schema
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

## Disclaimer

This is an unofficial library, not affiliated with or endorsed by the Polish
Ministry of Finance.