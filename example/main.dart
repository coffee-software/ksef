// ignore_for_file: avoid_print

import 'package:ksef/ksef.dart';
import 'package:logging/logging.dart';
import 'dart:io';

Future<KsefInvoiceRequest> sendRawInvoice(KsefSession session) async {
  final invoiceXml = File(
    '${File(Platform.script.toFilePath()).parent.path}/raw_invoice.xml',
  ).readAsStringSync();

  return await session.sendRawInvoice(invoiceXml);
}

Future<KsefInvoiceRequest> sendGeneratedInvoice(KsefSession session, String nip) async {
  final invoice = KsefInvoice(
    number: 'FV/${DateTime.now().millisecondsSinceEpoch}',
    issueDate: DateTime.now(),
    seller: KsefParty(
      nip: nip,
      name: 'ACME Sp. z o.o.',
      countryCode: 'PL',
      addressLine1: 'ul. Testowa 1; 00-001 Warszawa',
    ),
    buyer: KsefParty(
      nip: '3560182156',
      name: 'Buyer Corp S.A.',
      countryCode: 'PL',
      addressLine1: 'ul. Testowa 2; 00-001 Warszawa',
    ),
    lines: [
      KsefInvoiceLine(
        lineNumber: 1,
        description: 'example service',
        unit: 'usł',
        quantity: 2.0,
        unitNetPrice: 10000,
        vatRate: KsefVatRate.p23,
      ),
    ],
    payment: KsefPayment(method: KsefPaymentMethod.other, paidDate: DateTime.now()),
  );

  return await session.sendInvoice(invoice);
}

Future<void> waitForStatus(KsefSession session, KsefInvoiceRequest request) async {
  print('Waiting for invoice ${request.referenceNumber} status...');
  final invoiceStatus = await session.waitForInvoiceStatus(request);
  if (invoiceStatus.code == KsefInvoiceStatusCode.accepted) {
    print('Issued: ${invoiceStatus.ksefNumber}');
  } else if (invoiceStatus.code == KsefInvoiceStatusCode.duplicate) {
    print('Duplicate of: ${invoiceStatus.ksefNumber}');
  } else {
    print('Failed: ${invoiceStatus.errorInfo}');
  }
}

/// to run this example:
/// * generate a test token at https://ap-test.ksef.mf.gov.pl
/// * edit raw_invoice.xml with your NIP and current dates (without this step you will get invoice validation errors)
/// * dart run --define='KSEF_NIP=YOUR_NIP' --define='KSEF_TOKEN=YOUR_TOKEN' example/main.dart
/// * see this invoice at https://ap-test.ksef.mf.gov.pl
Future<void> main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('\x1B[90m[log.${r.level}] ${r.message}\x1B[0m'));

  final nip = String.fromEnvironment('KSEF_NIP');
  final token = String.fromEnvironment('KSEF_TOKEN');

  final client = KsefClient(.test, nip, token);
  print('Opening interactive session...');
  final session = await client.openSession();
  print('Sending RAW invoice...');
  await waitForStatus(session, await sendRawInvoice(session));
  print('Sending GENERATED invoice...');
  await waitForStatus(session, await sendGeneratedInvoice(session, nip));
  print('Closing session...');
  await session.close();
}
