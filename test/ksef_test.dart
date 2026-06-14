library;

import 'dart:io';
import 'dart:math';

import 'package:ksef/ksef.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

String generateRandomString(int len) {
  var r = Random();
  const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
}

String testInvoiceXml(String nip, String invoiceNumber, DateTime date) =>
    """<?xml version="1.0" encoding="UTF-8"?>
<Faktura xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/">
  <Naglowek>
    <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
    <WariantFormularza>3</WariantFormularza>
    <DataWytworzeniaFa>${KsefClient.formatUtcTimestamp(date)}</DataWytworzeniaFa>
    <SystemInfo>ksef.dart</SystemInfo>
  </Naglowek>
  <Podmiot1>
    <DaneIdentyfikacyjne>
      <NIP>$nip</NIP>
      <Nazwa>ACME Sp. z o.o.</Nazwa>
    </DaneIdentyfikacyjne>
    <Adres>
      <KodKraju>PL</KodKraju>
      <AdresL1>ul. Testowa 1</AdresL1>
      <AdresL2>00-001 Warszawa</AdresL2>
    </Adres>
  </Podmiot1>
  <Podmiot2>
    <DaneIdentyfikacyjne>
      <NIP>9876543210</NIP>
      <Nazwa>Buyer Corp S.A.</Nazwa>
    </DaneIdentyfikacyjne>
    <Adres>
      <KodKraju>PL</KodKraju>
      <AdresL1>ul. Kupiecka 5</AdresL1>
      <AdresL2>30-001 Kraków</AdresL2>
    </Adres>
    <JST>2</JST>
    <GV>2</GV>
  </Podmiot2>
  <Fa>
    <KodWaluty>PLN</KodWaluty>
    <P_1>${KsefClient.formatDate(date)}</P_1>
    <P_2>$invoiceNumber</P_2>
    <P_13_1>200.00</P_13_1>
    <P_14_1>46.00</P_14_1>
    <P_15>246.00</P_15>
    <Adnotacje>
      <P_16>2</P_16>
      <P_17>2</P_17>
      <P_18>2</P_18>
      <P_18A>2</P_18A>
      <Zwolnienie>
        <P_19N>1</P_19N>
      </Zwolnienie>
      <NoweSrodkiTransportu>
        <P_22N>1</P_22N>
      </NoweSrodkiTransportu>
      <P_23>2</P_23>
      <PMarzy>
        <P_PMarzyN>1</P_PMarzyN>
      </PMarzy>
    </Adnotacje>
    <RodzajFaktury>VAT</RodzajFaktury>
    <FaWiersz>
      <NrWierszaFa>1</NrWierszaFa>
      <P_7>example service</P_7>
      <P_8A>usł</P_8A>
      <P_8B>2.00</P_8B>
      <P_9A>100.00</P_9A>
      <P_11>200.00</P_11>
      <P_12>23</P_12>
    </FaWiersz>
    <Platnosc>
      <Zaplacono>1</Zaplacono>
      <DataZaplaty>${KsefClient.formatDate(date)}</DataZaplaty>
      <PlatnoscInna>1</PlatnoscInna>
      <OpisPlatnosci>TEST_OPIS_PLATNOSCI</OpisPlatnosci>
    </Platnosc>
  </Fa>
</Faktura>""";

void main() async {
  final config = loadYaml(File('test/config.yaml').readAsStringSync());
  final invoiceNumber = generateRandomString(32);
  final invoiceDate = DateTime.now();
  final invoiceXml = testInvoiceXml(config['ksef_nip'], invoiceNumber, invoiceDate);
  String? goodInvoiceKsefNumber = '';
  final invoice = KsefInvoice(
    number: invoiceNumber,
    issueDate: invoiceDate,
    seller: KsefParty(
      nip: config['ksef_nip'],
      name: 'ACME Sp. z o.o.',
      countryCode: 'PL',
      addressLine1: 'ul. Testowa 1',
      addressLine2: '00-001 Warszawa',
    ),
    buyer: KsefParty(
      nip: '9876543210',
      name: 'Buyer Corp S.A.',
      countryCode: 'PL',
      addressLine1: 'ul. Kupiecka 5',
      addressLine2: '30-001 Kraków',
    ),
    lines: [
      KsefInvoiceLine(
        lineNumber: 1,
        description: 'example service',
        unit: 'usł',
        quantity: 2.0,
        unitNetPrice: 100.00,
        vatRate: KsefVatRate.p23,
      ),
    ],
    payment: KsefPayment(
      method: KsefPaymentMethod.other,
      methodDescription: 'TEST_OPIS_PLATNOSCI',
      paidDate: invoiceDate,
    ),
  );

  test('ksef nr validation', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);

    final testNumber = client.buildKsefNumber('7363337349', '20260614', '000000000000');
    expect(testNumber, '7363337349-20260614-000000000000-B9');

    final validResult = client.validateKsefNumber(
      client.buildKsefNumber(config['ksef_nip'], '20260614', '000000000000'),
    );
    expect(validResult, true);

    final invalidResult = client.validateKsefNumber('7363337349-20260614-000000000000-00');
    expect(invalidResult, false);
  });

  test('test token', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    final tokenTest = await client.testToken();
    expect(tokenTest.canAuthenticate, true);
    expect(tokenTest.canReadInvoices, true);
    expect(tokenTest.canWriteInvoices, true);
    expect(tokenTest.error, null);
  });

  test('generating XML', () async {
    expect(invoice.toXml(), equals(invoiceXml));
  });

  test('sending  invoice', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    final session = await client.openSession();
    try {
      final invoiceRequest = await session.sendInvoice(invoice);
      final goodInvoiceStatus = await session.waitForInvoiceStatus(invoiceRequest);
      expect(goodInvoiceStatus.code, KsefInvoiceStatusCode.accepted);
      expect(goodInvoiceStatus.errorInfo, null);
      goodInvoiceKsefNumber = goodInvoiceStatus.ksefNumber;
    } finally {
      await session.close();
    }
  });

  test('sending invoice duplicate', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    final session = await client.openSession();
    try {
      final invoiceDuplicateRequest = await session.sendRawInvoice(invoiceXml);
      final invoiceDuplicateStatus = await session.waitForInvoiceStatus(
        invoiceDuplicateRequest,
      );
      expect(invoiceDuplicateStatus.code, KsefInvoiceStatusCode.duplicate);
      expect(invoiceDuplicateStatus.errorInfo, null);
      expect(invoiceDuplicateStatus.ksefNumber, goodInvoiceKsefNumber);
    } finally {
      await session.close();
    }
  });

  test('fetch invoice by ksef number', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    final invoice = await client.getInvoiceXmlByKsefNumber(goodInvoiceKsefNumber!);
    expect(invoice.contains('<P_2>$invoiceNumber</P_2>'), true);
  });

  test('fetch non existing invoice', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    expect(() async {
      await client.getInvoiceXmlByKsefNumber(
        client.buildKsefNumber(config['ksef_nip'], '20260614', '000000000000'),
      );
    }, throwsA(isA<KsefException>()));
  });
}
