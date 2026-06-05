part of '../ksef.dart';

class KsefSession {
  final KsefClient client;
  final KsefPublicKey _publicKey;
  String sessionRef = '';
  final List<int> _aesKey;
  final Uint8List _iv;

  KsefSession(this.client, this._publicKey) : _aesKey = _generateAesKey(), _iv = _generateIv();

  static List<int> _generateAesKey() {
    final rng = Random.secure();
    return List<int>.generate(32, (_) => rng.nextInt(256)); // 256-bit
  }

  static Uint8List _generateIv() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  Uint8List _aesEncrypt(Uint8List data) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(KeyParameter(Uint8List.fromList(_aesKey)), _iv),
          null,
        ),
      );

    return cipher.process(data);
  }

  /// Encrypt invoice with AES-256-CBC and send.
  /// This invoice will be processed asynchronously by KSeF.
  /// `waitForInvoiceStatus` shall be used to check its actual status.
  Future<KsefInvoiceRequest> sendRawInvoice(String xml) async {
    final xmlBytes = utf8.encode(xml);

    // SHA-256 of plaintext
    final plainHash = sha256.convert(xmlBytes);
    final plainHashB64 = base64Encode(plainHash.bytes);

    // Encrypt with AES-256-CBC + PKCS7
    final encrypted = _aesEncrypt(Uint8List.fromList(xmlBytes));
    final encHashB64 = base64Encode(sha256.convert(encrypted).bytes);
    final encryptedB64 = base64Encode(encrypted);

    final data = await client._post<Map<String, dynamic>>(
      '/sessions/online/$sessionRef/invoices/',
      await client.getValidAccessToken(),
      {
        'encryptedInvoiceContent': encryptedB64,
        'invoiceHash': plainHashB64,
        'invoiceSize': xmlBytes.length,
        'encryptedInvoiceHash': encHashB64,
        'encryptedInvoiceSize': encrypted.length,
      },
    );

    return KsefInvoiceRequest((data['referenceNumber'] ?? '') as String);
  }

  /// Polls invoice status that was sent with `sendRawInvoice`
  /// This method calls KSeF periodically using timeout and interval to check if invoice is already processed.
  Future<KsefInvoiceStatus> waitForInvoiceStatus(
    KsefInvoiceRequest invoiceRequest, {
    Duration timeout = const Duration(seconds: 60),
    Duration interval = const Duration(seconds: 2),
  }) async {
    var ret = KsefInvoiceStatus();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);

      final data = await client._get<Map<String, dynamic>>(
        '/sessions/$sessionRef/invoices/${invoiceRequest.referenceNumber}',
        await client.getValidAccessToken(),
      );
      final status = data['status'] as Map<String, dynamic>;
      final statusCode = status['code'] as int;

      if (statusCode == 200) {
        ret.code = .accepted;
        ret.ksefNumber = data['ksefNumber'] as String;
        return ret;
      } else if (statusCode == 440) {
        ret.code = .duplicate;
        ret.ksefNumber = status['extensions']['originalKsefNumber'] as String;
        return ret;
      } else if (statusCode >= 400) {
        ret.code = .rejected;
        var errors = [status['description'] as String];
        errors.addAll(
          (status['details'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        );
        ret.errorInfo = errors.join('\n');
        return ret;
      }
      // statusCode is 100 (submitted) or 102 (processing), continue pooling
    }
    // timeout we dont know what happened and let api user decide
    ret.code = .unknown;
    ret.errorInfo = 'Timeout expired. Status is unknown.';
    return ret;
  }

  /// close session
  Future<void> close() async {
    await client._post(
      '/sessions/online/$sessionRef/close',
      await client.getValidAccessToken(),
      null,
    );
  }
}
