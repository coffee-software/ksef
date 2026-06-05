// ignore_for_file: avoid_print

import 'package:ksef/ksef.dart';
import 'package:logging/logging.dart';
import 'dart:io';

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
  final invoiceXml = File(
    '${File(Platform.script.toFilePath()).parent.path}/raw_invoice.xml',
  ).readAsStringSync();

  final client = KsefClient(.test, nip, token);
  print('Opening interactive session...');
  final session = await client.openSession();
  print('Sending invoice...');
  final invoiceRequest = await session.sendRawInvoice(invoiceXml);
  print('Waiting for invoice ${invoiceRequest.referenceNumber} status...');
  final invoiceStatus = await session.waitForInvoiceStatus(invoiceRequest);
  print('Invoice status:  ${invoiceStatus.code}');
  print(invoiceStatus.errorInfo);
  print('Closing session...');
  await session.close();
}
