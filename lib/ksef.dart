import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/export.dart';
import 'package:logging/logging.dart';

final _log = Logger('ksef');

enum KsefEnvironment {
  /// PROD environment
  /// info: https://ksef.mf.gov.pl/
  /// panel login: https://ap.ksef.mf.gov.pl (you can generate token here)
  /// api docs: https://api.ksef.mf.gov.pl/docs/v2/index.html
  prod,

  /// TEST environment
  /// info: https://ksef-test.mf.gov.pl/
  /// panel login: https://ap-test.ksef.mf.gov.pl (you can generate token here)
  /// api docs: https://api-test.ksef.mf.gov.pl/docs/v2/index.html
  test,
}

class KsefPublicKey {
  String publicKeyId;
  RSAPublicKey publicKey;
  KsefPublicKey(this.publicKeyId, this.publicKey);
}

enum KsefInvoiceStatusCodes { pending, accepted, rejected, duplicate, unknown }

class KsefInvoiceRequest {
  String referenceNumber;
  KsefInvoiceRequest(this.referenceNumber);
}

class KsefInvoiceStatus {
  KsefInvoiceStatusCodes code = .pending;
  String? ksefNumber;
  String? errorInfo;
  KsefInvoiceStatus();
}

class KsefSession {
  KsefClient client;
  KsefPublicKey publicKey;
  String sessionRef = '';
  List<int> aesKey;
  Uint8List iv;

  KsefSession(this.client, this.publicKey) : aesKey = _generateAesKey(), iv = _generateIv();

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
          ParametersWithIV(KeyParameter(Uint8List.fromList(aesKey)), iv),
          null,
        ),
      );

    return cipher.process(data);
  }

  /// Encrypt invoice with AES-256-CBC and send
  Future<KsefInvoiceRequest> sendRawInvoice(String xml) async {
    final xmlBytes = utf8.encode(xml);

    // SHA-256 of plaintext
    final plainHash = sha256.convert(xmlBytes);
    final plainHashB64 = base64Encode(plainHash.bytes);

    // Encrypt with AES-256-CBC + PKCS7
    final encrypted = _aesEncrypt(Uint8List.fromList(xmlBytes));
    final encHashB64 = base64Encode(sha256.convert(encrypted).bytes);
    final encryptedB64 = base64Encode(encrypted);
    //final ivB64 = base64Encode(publicKey.iv);

    final data = await client.post<Map<String, dynamic>>(
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

  Future<KsefInvoiceStatus> waitForInvoiceStatus(
    KsefInvoiceRequest invoiceRequest, {
    Duration timeout = const Duration(seconds: 60),
    Duration interval = const Duration(seconds: 2),
  }) async {
    var ret = KsefInvoiceStatus();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);

      final data = await client.get<Map<String, dynamic>>(
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
    await client.post(
      '/sessions/online/$sessionRef/close',
      await client.getValidAccessToken(),
      null,
    );
  }
}

class KsefClient {
  KsefEnvironment environment;
  String nip;
  String token;

  String get baseUrl => environment == .prod
      ? 'https://api.ksef.mf.gov.pl/api/v2'
      : 'https://api-test.ksef.mf.gov.pl/api/v2';

  KsefClient(this.environment, this.nip, this.token);

  final Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> authHeaders(String accessToken) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $accessToken',
  };

  Future<T> post<T>(String path, String? accessToken, dynamic jsonData) async {
    _log.fine('POST $path');
    final body = jsonData == null ? null : jsonEncode(jsonData);
    _log.fine(body);
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: accessToken == null ? defaultHeaders : authHeaders(accessToken),
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('[$path] HTTP ${response.statusCode}: ${response.body}');
    }
    _log.fine(response.body);
    return (T == dynamic) ? response.body as T : (jsonDecode(response.body) as T);
  }

  Future<T> get<T>(String path, String? accessToken) async {
    _log.fine('GET $path');
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: accessToken == null ? defaultHeaders : authHeaders(accessToken),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('[$path] HTTP ${response.statusCode}: ${response.body}');
    }
    _log.fine(response.body);
    return (T == dynamic) ? response.body as T : (jsonDecode(response.body) as T);
  }

  Future<Map<String, dynamic>> getChallenge() async {
    return await post<Map<String, dynamic>>('/auth/challenge', null, null);
  }

  RSAPublicKey extractRsaPublicKeyFromCertDer(Uint8List certDer) {
    final certSeq = ASN1Parser(certDer).nextObject() as ASN1Sequence;
    final tbsCert = certSeq.elements![0] as ASN1Sequence;
    final spki = tbsCert.elements![6] as ASN1Sequence;
    final bitString = spki.elements![1] as ASN1BitString;
    // skip the leading 0x00 unused-bits byte
    final keySeq = ASN1Parser(bitString.valueBytes!.sublist(1)).nextObject() as ASN1Sequence;
    final modulus = (keySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  Future<KsefPublicKey> fetchPublicKey(String usage) async {
    final certs = await get<List<dynamic>>('/security/public-key-certificates', null);
    final certEntry = certs.firstWhere((c) => (c['usage'] as List).contains(usage));
    final certB64 = certEntry['certificate'] as String;
    return KsefPublicKey(
      certEntry['publicKeyId'],
      extractRsaPublicKeyFromCertDer(base64Decode(certB64)),
    );
  }

  /// KSeF token auth = Base64( RSA-OAEP-SHA256( utf8("token|timestamp") ) )
  String buildEncryptedToken(int timestampMs, RSAPublicKey publicKey) {
    //final timestampMs = DateTime.parse(timestamp).toUtc().millisecondsSinceEpoch;
    final plaintextStr = '$token|$timestampMs';
    final plaintext = utf8.encode(plaintextStr);

    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final encrypted = cipher.process(Uint8List.fromList(plaintext));
    return base64Encode(encrypted);
  }

  Future<Map<String, dynamic>> authenticate({
    Duration authTimeout = const Duration(seconds: 60),
    Duration authInterval = const Duration(seconds: 2),
  }) async {
    final challengeResp = await getChallenge();
    final timestampMs = challengeResp['timestampMs'] as int;
    final challenge = challengeResp['challenge'] as String;

    final publicKey = await fetchPublicKey('KsefTokenEncryption');
    final encryptedToken = buildEncryptedToken(timestampMs, publicKey.publicKey);

    final tokenResponse = await post<Map<String, dynamic>>('/auth/ksef-token', null, {
      'publicKeyId': publicKey.publicKeyId,
      'contextIdentifier': {'type': 'Nip', 'value': nip},
      'encryptedToken': encryptedToken,
      'challenge': challenge,
    });
    final referenceNumber = tokenResponse['referenceNumber'] as String;
    final authToken = tokenResponse['authenticationToken']['token'] as String;

    /// https://api-test.ksef.mf.gov.pl/docs/v2/index.html#tag/Uzyskiwanie-dostepu/paths/~1auth~1%7BreferenceNumber%7D/get
    int statusCode = 100;
    String statusDescription = '';

    final deadline = DateTime.now().add(authTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(authInterval);
      final pollResp = await get<Map<String, dynamic>>('/auth/$referenceNumber', authToken);
      statusCode = pollResp['status']['code'] as int;
      statusDescription = pollResp['status']['description'] as String;
      if (statusCode == 200) {
        //Authenticated
        break;
      }
    }
    if (statusCode != 200) {
      throw Exception('KSEF Auth Exception ($statusCode) $statusDescription');
    }
    return await post<Map<String, dynamic>>('/auth/token/redeem', authToken, null);
  }

  String? accessToken;
  Future<String> getValidAccessToken() async {
    //TODO: check for expiration locally
    if (accessToken == null) {
      final tokens = await authenticate();
      accessToken = tokens['accessToken']['token'] as String;
      //TODO: save tokens['refreshToken']['token'] for later use
    }
    return accessToken!;
  }

  /// Open interactive session with encrypted AES key
  Future<KsefSession> openSession() async {
    var session = KsefSession(this, await fetchPublicKey('SymmetricKeyEncryption'));
    // Encrypt the AES key with KSeF's RSA public key (OAEP-SHA256)
    final rsaCipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(session.publicKey.publicKey));
    final encryptedAesKey = base64Encode(rsaCipher.process(Uint8List.fromList(session.aesKey)));
    final data = await post<Map<String, dynamic>>(
      '/sessions/online',
      await getValidAccessToken(),
      {
        'formCode': {'systemCode': 'FA (3)', 'schemaVersion': '1-0E', 'value': 'FA'},
        'encryption': {
          'encryptedSymmetricKey': encryptedAesKey,
          'initializationVector': base64Encode(session.iv),
          'publicKeyId': session.publicKey.publicKeyId,
        },
      },
    );
    session.sessionRef = data['referenceNumber'] as String;
    return session;
  }

  /// Fetch invoice XML by ksef number
  /// this requires token to have "view invoices" privilege
  Future<String> getInvoiceXmlByKsefNumber(String ksefNumber) async {
    final data = await get('/invoices/ksef/$ksefNumber', await getValidAccessToken());
    return data.toString();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String formatTimestamp(DateTime time) {
    return '${formatDate(time)}T${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}Z';
  }

  static String formatDate(DateTime time) {
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)}';
  }
}
