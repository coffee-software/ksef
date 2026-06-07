part of '../ksef.dart';

final _log = Logger('ksef');

class KsefClient {
  KsefEnvironment environment;
  String nip;
  String token;

  String get baseUrl => environment == .prod
      ? 'https://api.ksef.mf.gov.pl/api/v2'
      : 'https://api-test.ksef.mf.gov.pl/api/v2';

  KsefClient(this.environment, this.nip, this.token);

  Future<T> _post<T>(String path, String? authToken, dynamic jsonData) async {
    _log.fine('POST $path');
    final body = jsonData == null ? null : jsonEncode(jsonData);
    final headers = {'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    _log.fine(body);
    final response = await http.post(Uri.parse('$baseUrl$path'), headers: headers, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KsefException(path, 'HTTP ${response.statusCode}: ${response.body}');
    }
    _log.fine(response.body);
    return (T == dynamic) ? response.body as T : (jsonDecode(response.body) as T);
  }

  Future<T> _get<T>(String path, String? authToken) async {
    _log.fine('GET $path');
    final headers = {'Accept': T == String ? 'application/xml' : 'application/json'};
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KsefException(path, 'HTTP ${response.statusCode}: ${response.body}');
    }
    _log.fine(response.body);
    return (T == String) ? response.body as T : (jsonDecode(response.body) as T);
  }

  Future<Map<String, dynamic>> _getChallenge() async {
    return await _post<Map<String, dynamic>>('/auth/challenge', null, null);
  }

  RSAPublicKey _extractRsaPublicKeyFromCertDer(Uint8List certDer) {
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

  List<dynamic>? _ksefCertificates;
  Future<KsefPublicKey> _fetchPublicKey(String usage) async {
    _ksefCertificates ??= await _get<List<dynamic>>('/security/public-key-certificates', null);
    final certEntry = _ksefCertificates!.firstWhere(
      (c) => (c['usage'] as List).contains(usage),
    );
    final certB64 = certEntry['certificate'] as String;
    return KsefPublicKey(
      certEntry['publicKeyId'],
      _extractRsaPublicKeyFromCertDer(base64Decode(certB64)),
    );
  }

  /// KSeF token auth = Base64( RSA-OAEP-SHA256( utf8("token|timestamp") ) )
  String _buildEncryptedToken(int timestampMs, RSAPublicKey publicKey) {
    // TODO: remove this after fixing KSeF docs and confirming this is a proper way
    // final timestampMs = DateTime.parse(timestamp).toUtc().millisecondsSinceEpoch;
    final plaintextStr = '$token|$timestampMs';
    final plaintext = utf8.encode(plaintextStr);

    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final encrypted = cipher.process(Uint8List.fromList(plaintext));
    return base64Encode(encrypted);
  }

  /// Authenticates in KSeF using configured token, saves auth tokens for later use.
  /// This method will be called automatically when needed (for example when tokens expire).
  /// You dont need to call this method manually.
  Future<void> authenticate({
    Duration authTimeout = const Duration(seconds: 60),
    Duration authInterval = const Duration(seconds: 2),
  }) async {
    final challengeResp = await _getChallenge();
    final timestampMs = challengeResp['timestampMs'] as int;
    final challenge = challengeResp['challenge'] as String;

    final publicKey = await _fetchPublicKey('KsefTokenEncryption');
    final encryptedToken = _buildEncryptedToken(timestampMs, publicKey.publicKey);

    final tokenResponse = await _post<Map<String, dynamic>>('/auth/ksef-token', null, {
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
      final pollResp = await _get<Map<String, dynamic>>('/auth/$referenceNumber', authToken);
      statusCode = pollResp['status']['code'] as int;
      statusDescription = pollResp['status']['description'] as String;
      if (statusCode == 200) {
        //Authenticated
        break;
      }
    }
    if (statusCode != 200) {
      throw KsefException(
        '/auth/$referenceNumber',
        'Auth Exception $statusCode: $statusDescription',
      );
    }
    final tokens = await _post<Map<String, dynamic>>('/auth/token/redeem', authToken, null);
    _saveTokens(tokens);
  }

  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  Future<String> getValidAccessToken() async {
    if (_accessToken != null &&
        _accessTokenExpiry != null &&
        _accessTokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return _accessToken!;
    }
    if (_refreshToken != null) {
      try {
        await _refreshAccessToken();
        return _accessToken!;
      } catch (_) {
        _refreshToken = null;
      }
    }
    await authenticate();
    return _accessToken!;
  }

  DateTime _parseJwtExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT format');
    }
    final payload = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
    final exp = decoded['exp'] as int;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  void _saveTokens(Map<String, dynamic> tokens) {
    _accessToken = tokens['accessToken']['token'] as String;
    _refreshToken = tokens['refreshToken']['token'] as String;
    _accessTokenExpiry = _parseJwtExpiry(_accessToken!);
  }

  Future<void> _refreshAccessToken() async {
    final tokens = await _post<Map<String, dynamic>>('/auth/token/refresh', null, {
      'refreshToken': _refreshToken,
    });
    _saveTokens(tokens);
  }

  /// Open interactive session and generates encryption keys for it.
  Future<KsefSession> openSession() async {
    var session = KsefSession(this, await _fetchPublicKey('SymmetricKeyEncryption'));
    // Encrypt the AES key with KSeF's RSA public key (OAEP-SHA256)
    final rsaCipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(session._publicKey.publicKey));
    final encryptedAesKey = base64Encode(
      rsaCipher.process(Uint8List.fromList(session._aesKey)),
    );
    final data = await _post<Map<String, dynamic>>(
      '/sessions/online',
      await getValidAccessToken(),
      {
        'formCode': {'systemCode': 'FA (3)', 'schemaVersion': '1-0E', 'value': 'FA'},
        'encryption': {
          'encryptedSymmetricKey': encryptedAesKey,
          'initializationVector': base64Encode(session._iv),
          'publicKeyId': session._publicKey.publicKeyId,
        },
      },
    );
    session.sessionRef = data['referenceNumber'] as String;
    return session;
  }

  /// Fetch invoice XML by ksef number
  /// this requires token to have "view invoices" privilege
  Future<String> getInvoiceXmlByKsefNumber(String ksefNumber) async {
    return await _get<String>('/invoices/ksef/$ksefNumber', await getValidAccessToken());
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// Format date and time to be used in invoice XMLs
  static String formatUtcTimestamp(DateTime time) {
    var utcTime = time.isUtc ? time : time.toUtc();
    return '${formatDate(utcTime)}T${_pad(utcTime.hour)}:${_pad(utcTime.minute)}:${_pad(utcTime.second)}Z';
  }

  /// Format date to be used in invoice XMLs
  static String formatDate(DateTime time) {
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)}';
  }
}
