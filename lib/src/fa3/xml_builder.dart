part of '../../ksef.dart';

extension KsefInvoiceXml on KsefInvoice {
  String toXml() {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<Faktura xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/">');

    // Naglowek
    sb.writeln('  <Naglowek>');
    sb.writeln(
      '    <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>',
    );
    sb.writeln('    <WariantFormularza>3</WariantFormularza>');
    sb.writeln(
      '    <DataWytworzeniaFa>${KsefClient.formatUtcTimestamp(createdDate)}</DataWytworzeniaFa>',
    );
    sb.writeln('    <SystemInfo>$systemInfo</SystemInfo>');
    sb.writeln('  </Naglowek>');

    // Podmiot1 (seller)
    _buildParty(sb, 'Podmiot1', seller);

    // Podmiot2 (buyer)
    _buildParty(sb, 'Podmiot2', buyer);

    // Fa
    sb.writeln('  <Fa>');
    sb.writeln('    <KodWaluty>$currency</KodWaluty>');
    sb.writeln('    <P_1>${KsefClient.formatDate(issueDate)}</P_1>');
    if (issuePlace != null) {
      sb.writeln('    <P_1M>$issuePlace</P_1M>');
    }
    sb.writeln('    <P_2>$number</P_2>');
    if (taxPointDate != null) {
      sb.writeln('    <P_6>${KsefClient.formatDate(taxPointDate!)}</P_6>');
    }

    // Totals
    final invoiceTotals = getTotals();

    // 23% || 22%
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p23) ||
        invoiceTotals.byRate.containsKey(KsefVatRate.p22)) {
      int sumNet =
          (invoiceTotals.byRate[KsefVatRate.p23]?.netAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p22]?.netAmount ?? 0);
      sb.writeln('    <P_13_1>${_fmt(sumNet)}</P_13_1>');
      int sumVat =
          (invoiceTotals.byRate[KsefVatRate.p23]?.vatAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p22]?.vatAmount ?? 0);
      sb.writeln('    <P_14_1>${_fmt(sumVat)}</P_14_1>');
    }
    // 8% || 7%
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p8) ||
        invoiceTotals.byRate.containsKey(KsefVatRate.p7)) {
      int sumNet =
          (invoiceTotals.byRate[KsefVatRate.p8]?.netAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p7]?.netAmount ?? 0);
      sb.writeln('    <P_13_2>${_fmt(sumNet)}</P_13_2>');
      int sumVat =
          (invoiceTotals.byRate[KsefVatRate.p8]?.vatAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p7]?.vatAmount ?? 0);
      sb.writeln('    <P_14_2>${_fmt(sumVat)}</P_14_2>');
    }
    // 5%
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p5)) {
      sb.writeln(
        '    <P_13_3>${_fmt(invoiceTotals.byRate[KsefVatRate.p5]!.netAmount)}</P_13_3>',
      );
      sb.writeln(
        '    <P_14_3>${_fmt(invoiceTotals.byRate[KsefVatRate.p5]!.vatAmount)}</P_14_3>',
      );
    }
    // 4% || 3%
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p4) ||
        invoiceTotals.byRate.containsKey(KsefVatRate.p3)) {
      int sumNet =
          (invoiceTotals.byRate[KsefVatRate.p4]?.netAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p3]?.netAmount ?? 0);
      sb.writeln('    <P_13_4>${_fmt(sumNet)}</P_13_4>');
      int sumVat =
          (invoiceTotals.byRate[KsefVatRate.p4]?.vatAmount ?? 0) +
          (invoiceTotals.byRate[KsefVatRate.p3]?.vatAmount ?? 0);
      sb.writeln('    <P_14_4>${_fmt(sumVat)}</P_14_4>');
    }

    if (invoiceTotals.byRate.containsKey(KsefVatRate.p0kr)) {
      sb.writeln(
        '    <P_13_6_1>${_fmt(invoiceTotals.byRate[KsefVatRate.p0kr]!.netAmount)}</P_13_6_1>',
      );
    }
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p0wdt)) {
      sb.writeln(
        '    <P_13_6_2>${_fmt(invoiceTotals.byRate[KsefVatRate.p0wdt]!.netAmount)}</P_13_6_2>',
      );
    }
    if (invoiceTotals.byRate.containsKey(KsefVatRate.p0ex)) {
      sb.writeln(
        '    <P_13_6_3>${_fmt(invoiceTotals.byRate[KsefVatRate.p0ex]!.netAmount)}</P_13_6_3>',
      );
    }

    if (invoiceTotals.byRate.containsKey(KsefVatRate.zw)) {
      sb.writeln(
        '    <P_13_7>${_fmt(invoiceTotals.byRate[KsefVatRate.zw]!.netAmount)}</P_13_7>',
      );
    }
    if (invoiceTotals.byRate.containsKey(KsefVatRate.np1)) {
      sb.writeln(
        '    <P_13_8>${_fmt(invoiceTotals.byRate[KsefVatRate.np1]!.netAmount)}</P_13_8>',
      );
    }
    if (invoiceTotals.byRate.containsKey(KsefVatRate.np2)) {
      sb.writeln(
        '    <P_13_9>${_fmt(invoiceTotals.byRate[KsefVatRate.np2]!.netAmount)}</P_13_9>',
      );
    }
    if (invoiceTotals.byRate.containsKey(KsefVatRate.oo)) {
      sb.writeln(
        '    <P_13_10>${_fmt(invoiceTotals.byRate[KsefVatRate.oo]!.netAmount)}</P_13_10>',
      );
    }

    // Gross total
    sb.writeln('    <P_15>${_fmt(invoiceTotals.grossTotal)}</P_15>');

    // Adnotacje
    sb.writeln('    <Adnotacje>');
    sb.writeln('      <P_16>${payment.method == KsefPaymentMethod.cash ? 1 : 2}</P_16>');
    sb.writeln('      <P_17>${annotations.selfBilling ? 1 : 2}</P_17>');
    sb.writeln('      <P_18>${annotations.reverseCharge ? 1 : 2}</P_18>');
    sb.writeln('      <P_18A>${annotations.oss ? 1 : 2}</P_18A>');
    //sb.writeln('      <P_20>${annotations.splitPayment ? 1 : 0}</P_20>');
    //sb.writeln('      <P_21>${annotations.cashAccounting ? 1 : 0}</P_21>');

    sb.writeln('      <Zwolnienie>');
    sb.writeln('        <P_19N>1</P_19N>');
    sb.writeln('      </Zwolnienie>');

    sb.writeln('      <NoweSrodkiTransportu>');
    sb.writeln('        <P_22N>1</P_22N>');
    sb.writeln('      </NoweSrodkiTransportu>');

    sb.writeln('      <P_23>2</P_23>');

    sb.writeln('      <PMarzy>');
    sb.writeln('        <P_PMarzyN>1</P_PMarzyN>');
    sb.writeln('      </PMarzy>');

    sb.writeln('    </Adnotacje>');

    sb.writeln('    <RodzajFaktury>${_invoiceTypeCode(type)}</RodzajFaktury>');

    // Lines
    for (final line in lines) {
      sb.writeln('    <FaWiersz>');
      sb.writeln('      <NrWierszaFa>${line.lineNumber}</NrWierszaFa>');
      sb.writeln('      <P_7>${_esc(line.description)}</P_7>');
      sb.writeln('      <P_8A>${line.unit}</P_8A>');
      sb.writeln('      <P_8B>${_fmtQty(line.quantity)}</P_8B>');
      sb.writeln('      <P_9A>${_fmt(line.unitNetPrice)}</P_9A>');
      sb.writeln('      <P_11>${_fmt(line.effectiveNetAmount)}</P_11>');
      sb.writeln('      <P_12>${_vatRateCode(line.vatRate)}</P_12>');
      if (line.gtu != null) {
        sb.writeln('      <GTU>${line.gtu}</GTU>');
      }

      // optional exchange rate
      if (currency != 'PLN') {
        if (exchangeRate != null) {
          /// rate formatted to 6 decimal places, as required by schema field [KursWaluty].
          sb.writeln('    <KursWaluty>${exchangeRate!.toStringAsFixed(6)}</KursWaluty>');
        } else {
          KsefException('invoice', null, 'exchangeRate is required for non PLN invoices');
        }
      }
      sb.writeln('    </FaWiersz>');
    }
    // Payment
    sb.writeln('    <Platnosc>');

    if (payment.paidDate != null) {
      sb.writeln('      <Zaplacono>1</Zaplacono>');
      sb.writeln(
        '      <DataZaplaty>${KsefClient.formatDate(payment.paidDate!)}</DataZaplaty>',
      );
    }

    if (payment.dueDate != null) {
      sb.writeln('      <TerminPlatnosci>');
      sb.writeln('        <Termin>${KsefClient.formatDate(payment.dueDate!)}</Termin>');
      sb.writeln('      </TerminPlatnosci>');
    }

    int? paymentCode = _paymentMethodCode(payment.method);

    if (paymentCode != null) {
      sb.writeln('      <FormaPlatnosci>$paymentCode</FormaPlatnosci>');
    } else {
      if (payment.methodDescription == null) {
        KsefException('invoice', null, 'methodDescription must be set if method == other');
      }
      sb.writeln('      <PlatnoscInna>1</PlatnoscInna>');
      sb.writeln('      <OpisPlatnosci>${payment.methodDescription}</OpisPlatnosci>');
    }

    if (payment.bankAccount != null) {
      sb.writeln('      <RachunekBankowy>');
      sb.writeln('        <NrRB>${payment.bankAccount}</NrRB>');
      if (payment.bankName != null) {
        sb.writeln('        <NazwaBanku>${_esc(payment.bankName!)}</NazwaBanku>');
      }
      sb.writeln('      </RachunekBankowy>');
    }
    sb.writeln('    </Platnosc>');

    // Order reference
    if (orderNumber != null) {
      sb.writeln('    <WarunkiTransakcji>');
      sb.writeln('      <Zamowienia>');
      sb.writeln('        <NrZamowienia>$orderNumber</NrZamowienia>');
      sb.writeln('      </Zamowienia>');
      sb.writeln('    </WarunkiTransakcji>');
    }

    sb.writeln('  </Fa>');
    sb.write('</Faktura>');
    return sb.toString();
  }

  String _buildParty(StringBuffer sb, String tag, KsefParty p) {
    sb.writeln('  <$tag>');
    sb.writeln('    <DaneIdentyfikacyjne>');
    if (p.euVatPrefix != null) {
      sb.writeln('      <PrefiksPodatnika>${p.euVatPrefix}</PrefiksPodatnika>');
    }
    if (p.nip == null) {
      sb.writeln('      <BrakID>1</BrakID>');
    } else {
      sb.writeln('      <NIP>${p.nip}</NIP>');
    }
    sb.writeln('      <Nazwa>${_esc(p.name)}</Nazwa>');
    sb.writeln('    </DaneIdentyfikacyjne>');
    sb.writeln('    <Adres>');
    sb.writeln('      <KodKraju>${p.countryCode}</KodKraju>');
    sb.writeln('      <AdresL1>${_esc(p.addressLine1)}</AdresL1>');
    if (p.addressLine2 != null) {
      sb.writeln('      <AdresL2>${_esc(p.addressLine2!)}</AdresL2>');
    }
    sb.writeln('    </Adres>');
    if (tag == 'Podmiot2') {
      sb.writeln('    <JST>2</JST>');
      sb.writeln('    <GV>2</GV>');
    }
    sb.writeln('  </$tag>');
    return sb.toString();
  }

  String _fmt(int v) => (v / 100).toStringAsFixed(2);

  /// Formats quantity for FA(3) P_8B field.
  /// Removes trailing zeros: 2.0 → "2", 11.3527 → "11.3527", 1.5 → "1.5"
  String _fmtQty(double qty) {
    return qty
        .toStringAsFixed(10)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _esc(String s) => htmlEscape.convert(s);

  String _invoiceTypeCode(KsefInvoiceType t) => switch (t) {
    KsefInvoiceType.vat => 'VAT',
    KsefInvoiceType.correction => 'KOR',
    KsefInvoiceType.advance => 'ZAL',
    KsefInvoiceType.simplified => 'UPR',
  };

  String _vatRateCode(KsefVatRate r) => switch (r) {
    KsefVatRate.p23 => '23',
    KsefVatRate.p22 => '22',
    KsefVatRate.p8 => '8',
    KsefVatRate.p7 => '8',
    KsefVatRate.p5 => '5',
    KsefVatRate.p4 => '4',
    KsefVatRate.p3 => '3',
    KsefVatRate.p0kr => '0 KR',
    KsefVatRate.p0wdt => '0 WDT',
    KsefVatRate.p0ex => '0 EX',
    KsefVatRate.zw => 'zw',
    KsefVatRate.np1 => 'np I',
    KsefVatRate.np2 => 'np II',
    KsefVatRate.oo => 'oo',
  };

  int? _paymentMethodCode(KsefPaymentMethod m) => switch (m) {
    KsefPaymentMethod.cash => 1,
    KsefPaymentMethod.card => 2,
    KsefPaymentMethod.voucher => 3,
    KsefPaymentMethod.check => 4,
    KsefPaymentMethod.credit => 5,
    KsefPaymentMethod.bankTransfer => 6,
    KsefPaymentMethod.mobile => 7,
    KsefPaymentMethod.other => null,
  };
}
