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
    """<?xml version="1.0" encoding="utf-8"?>
<Faktura xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
         xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/">
    <Naglowek>
        <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
        <WariantFormularza>3</WariantFormularza>
        <DataWytworzeniaFa>${KsefClient.formatTimestamp(date)}</DataWytworzeniaFa>
        <SystemInfo>swift.shop</SystemInfo>
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
        <P_13_1>615</P_13_1>
        <P_14_1>141.45</P_14_1>
        <P_15>756.45</P_15>
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
            <P_7>test pozycja</P_7>
            <P_8A>5</P_8A>
            <P_8B>5</P_8B>
            <P_9A>123</P_9A>
            <P_11>615</P_11>
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
  final invoiceXml = testInvoiceXml(config['ksef_nip'], invoiceNumber, DateTime.now());
  String? goodInvoiceKsefNumber = '';

  test('sending an invoice', () async {
    final client = KsefClient(.test, config['ksef_nip'], config['ksef_token']);
    final session = await client.openSession();
    try {
      final invoiceRequest = await session.sendRawInvoice(invoiceXml);
      final goodInvoiceStatus = await session.waitForInvoiceStatus(invoiceRequest);
      expect(goodInvoiceStatus.code, KsefInvoiceStatusCodes.accepted);
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
      expect(invoiceDuplicateStatus.code, KsefInvoiceStatusCodes.duplicate);
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
}
