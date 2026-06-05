part of '../ksef.dart';

/// Exception thrown by KSeF API, may include network exceptions
class KsefException implements Exception {
  String path;
  String message;
  KsefException(this.path, this.message);

  @override
  String toString() => '$path: $message';
}

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

/// invoice request info returned by KSeF after sending invoice
class KsefInvoiceRequest {
  String referenceNumber;
  KsefInvoiceRequest(this.referenceNumber);
}

/// invoice status returned after invoice is processed by KSeF
/// for code `accepted`, `ksefNumber` is set to valid KSeF invoice number for the new invoice.
/// for code `duplicate`, `ksefNumber` is set to the invoice that this request was a duplicate of.
/// for other statuses `ksefNumber` is empty and errorInfo contains human readable issue description.
class KsefInvoiceStatus {
  KsefInvoiceStatusCodes code = .pending;
  String? ksefNumber;
  String? errorInfo;
  KsefInvoiceStatus();
}
