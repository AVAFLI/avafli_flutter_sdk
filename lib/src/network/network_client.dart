import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../services/logger.dart';
import '../winr_error.dart';
import 'api_request.dart';
import 'gts_roots.dart';

/// HTTP client for making authenticated requests to the WINR backend.
///
/// Handles authentication, token refresh, certificate pinning, retry logic,
/// and error handling for all API communications.
abstract class NetworkClient {
  /// Sends an API request and returns the parsed response.
  Future<T> send<T>(ApiRequest<T> request);

  /// Sets the authentication token for requests.
  void setAuthToken(String? token);

  /// Sets a callback for handling token refresh.
  void setRefreshHandler(Future<String?> Function() handler);
}

/// HTTP client implementation using the dart:io HttpClient.
///
/// Provides certificate pinning, automatic token refresh, and retry logic.
class NetworkClientImpl implements NetworkClient {
  final String baseURL;
  final String apiKey;
  final Duration timeout;
  final int maxRetries;

  String? _authToken;
  Future<String?> Function()? _refreshHandler;

  /// Lazily-built pinning client. Reused across requests so we don't pay the
  /// HttpClient setup cost on every call.
  http.Client? _pinnedClient;

  /// Creates a new network client.
  NetworkClientImpl({
    required this.baseURL,
    required this.apiKey,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  });

  /// Builds (once) an [IOClient] over a `dart:io` [HttpClient] whose trust
  /// store is RESTRICTED to the Google Trust Services roots, with an SPKI
  /// leaf-pin backstop (via [CertificatePinner]) as defense-in-depth.
  ///
  /// **Trust-store restriction (the real CA pin).** The backend runs on
  /// `*.cloudfunctions.net`, whose certificates chain to the GTS hierarchy.
  /// We build the client from a `SecurityContext(withTrustedRoots: false)`
  /// loaded with ONLY GTS Root R1 and GTS Root R4 (see `gts_roots.dart`, both
  /// valid through 2036). Chain validation therefore succeeds only for chains
  /// terminating at a GTS root — a certificate issued by any other CA
  /// (compromised public CA, user-installed corporate root, MITM proxy) fails
  /// the TLS handshake outright. This achieves CA pinning in pure Dart
  /// despite `badCertificateCallback` only ever exposing the leaf: `dart:io`
  /// never shows Dart the intermediates of the presented chain, but it DOES
  /// let us dictate which roots the platform validator may chain to.
  ///
  /// **SPKI backstop.** `badCertificateCallback` fires only when chain
  /// validation against the restricted store fails. We keep the existing
  /// fail-closed [CertificatePinner] check there: a distrusted leaf is
  /// accepted only if its SPKI directly matches a GTS pin (it normally
  /// won't), otherwise the handshake is aborted.
  http.Client _client() {
    final existing = _pinnedClient;
    if (existing != null) return existing;

    // Trust ONLY the GTS roots — everything else is rejected at handshake.
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(gtsRootR1Pem))
      ..setTrustedCertificatesBytes(utf8.encode(gtsRootR4Pem));

    const pinner = CertificatePinner(CertificatePinner.defaultPins);
    final httpClient = HttpClient(context: context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        final ok = pinner.validate(cert);
        if (!ok) {
          Logger.instance
              .error('Certificate pin validation failed for $host:$port');
        }
        return ok;
      };

    final client = IOClient(httpClient);
    _pinnedClient = client;
    return client;
  }

  @override
  void setAuthToken(String? token) {
    _authToken = token;
  }

  @override
  void setRefreshHandler(Future<String?> Function() handler) {
    _refreshHandler = handler;
  }

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    var attempt = 0;

    while (attempt < maxRetries) {
      try {
        final response = await _performRequest(request);
        return request.parseResponse(response);
      } on WINRException catch (e) {
        // Don't retry on certain errors
        if (e.error == WINRError.invalidApiKey ||
            e.error == WINRError.underage ||
            e.error == WINRError.ineligibleToday ||
            e.error == WINRError.serviceUnavailable) {
          rethrow;
        }

        // Handle 401 with token refresh — but NOT for requests that don't
        // require auth (e.g. refreshToken, registerDevice) to avoid infinite
        // recursive loops where refresh→401→refresh→401→...
        if (e.error == WINRError.authenticationFailed &&
            _refreshHandler != null &&
            request.requiresAuth) {
          Logger.instance
              .debug('Authentication failed, attempting token refresh');
          final newToken = await _refreshHandler!();
          if (newToken != null) {
            setAuthToken(newToken);
            // Retry the request with new token
            attempt++;
            continue;
          }
        }

        // Retry on network errors
        if (e.error == WINRError.networkError && attempt < maxRetries - 1) {
          attempt++;
          await Future.delayed(
              Duration(seconds: attempt * 2)); // Exponential backoff
          continue;
        }

        rethrow;
      } catch (e) {
        if (attempt >= maxRetries - 1) {
          throw const WINRException(WINRError.networkError);
        }
        attempt++;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw const WINRException(WINRError.networkError);
  }

  /// Performs the actual HTTP request.
  Future<http.Response> _performRequest<T>(ApiRequest<T> request) async {
    final url = Uri.parse('$baseURL${request.endpoint}');

    Logger.instance.debug('${request.method} ${request.endpoint}');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
      'User-Agent': 'WINR-Flutter-SDK/v1.0.0',
    };

    // Add auth token if available and the request requires it
    if (_authToken != null && request.requiresAuth) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    final client = _client();

    try {
      late http.Response response;

      switch (request.method) {
        case 'GET':
          response = await client.get(url, headers: headers).timeout(timeout);
          break;
        case 'POST':
          // Firebase callable functions expect body wrapped in {"data": ...}
          // Always send {"data": {}} even with no params — Firebase rejects empty POST bodies.
          final body = jsonEncode({'data': request.body ?? {}});
          response = await client
              .post(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PUT':
          final body = jsonEncode({'data': request.body ?? {}});
          response = await client
              .put(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'DELETE':
          response =
              await client.delete(url, headers: headers).timeout(timeout);
          break;
        default:
          throw const WINRException(WINRError.unknown);
      }

      Logger.instance
          .debug('Response: ${response.statusCode} ${response.reasonPhrase}');

      // Handle HTTP errors
      if (response.statusCode >= 400) {
        _handleHttpError(response);
      }

      return response;
    } on SocketException {
      throw const WINRException(WINRError.networkError);
    } on HttpException {
      throw const WINRException(WINRError.networkError);
    } catch (e) {
      if (e is WINRException) rethrow;
      Logger.instance.error('Network request failed', e);
      throw const WINRException(WINRError.networkError);
    }
    // Note: the pinned client is reused across requests and closed via
    // [dispose]; we intentionally do not close it per-request here.
  }

  /// Closes the underlying pinned HTTP client. Call when the SDK is torn down.
  void dispose() {
    _pinnedClient?.close();
    _pinnedClient = null;
  }

  /// Handles HTTP error responses.
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;

    // Parse the error message from the Firebase callable (onCall) envelope. On
    // error the body is {"error":{"message":"...","status":"..."}} — so the
    // message lives at error.message, NOT error (which is a Map). An earlier
    // `data['error'] as String?` always silently failed, leaving every error
    // unlabelled and every 400 mislabelled as "invalid API key".
    String? errorMessage;
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          errorMessage = err['message'] as String?;
        } else if (err is String) {
          errorMessage = err;
        }
      }
    } catch (_) {
      // Ignore JSON parsing errors
    }

    final lower = errorMessage?.toLowerCase();

    switch (statusCode) {
      case 400:
        // A 400 is invalid-argument / failed-precondition — never an API-key
        // problem. Map the known cases, otherwise surface the backend's text.
        if (lower?.contains('underage') == true || lower?.contains('13 or older') == true) {
          throw const WINRException(WINRError.underage);
        }
        if (lower?.contains('email') == true &&
            (lower!.contains('confirm') || lower.contains('required') || lower.contains('consent'))) {
          throw WINRException(WINRError.emailRequired, errorMessage);
        }
        if (lower?.contains('valid email') == true || lower?.contains('invalid email') == true) {
          throw const WINRException(WINRError.invalidEmail);
        }
        throw WINRException(WINRError.unknown, errorMessage);
      case 401:
        throw const WINRException(WINRError.authenticationFailed);
      case 403:
        // A suspended/revoked publisher surfaces as a `permission-denied`
        // (403) callable error whose message mentions "suspended" or
        // "revoked" (e.g. "API key suspended or revoked" / "Publisher
        // account suspended"). Map it to serviceUnavailable so the SDK can
        // degrade gracefully instead of looking like an auth failure.
        if (_isSuspendedError(errorMessage)) {
          throw const WINRException(WINRError.serviceUnavailable);
        }
        if (lower?.contains('geograph') == true || lower?.contains('location') == true) {
          throw const WINRException(WINRError.geographyNotAllowed);
        }
        if (lower?.contains('already claimed') == true || lower?.contains('already entered') == true) {
          throw const WINRException(WINRError.ineligibleToday);
        }
        throw WINRException(WINRError.authenticationFailed, errorMessage);
      case 404:
        throw const WINRException(WINRError.giveawayNotAvailable);
      case 409:
        // already-exists — the daily entry was already claimed.
        throw WINRException(WINRError.ineligibleToday, errorMessage);
      case 429:
        throw const WINRException(WINRError.networkError); // Rate limited
      case 500:
      case 502:
      case 503:
      case 504:
        throw WINRException(WINRError.serverError, errorMessage);
      default:
        Logger.instance.error('Unexpected HTTP status: $statusCode — $errorMessage');
        throw WINRException(WINRError.unknown, errorMessage);
    }
  }

  /// Detects the backend "publisher suspended / API key revoked" error from
  /// its message. The backend emits a `permission-denied` (403) callable error
  /// with one of:
  ///   - "API key suspended or revoked"
  ///   - "Publisher account suspended"
  static bool _isSuspendedError(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('suspended') || lowered.contains('revoked');
  }
}

/// Certificate pinning implementation for enhanced security.
///
/// Validates that the server certificate matches expected pinned public keys
/// to prevent man-in-the-middle attacks.
///
/// We pin on the **Subject Public Key Info (SPKI)** SHA-256 — `base64(sha256(DER
/// SPKI))` — rather than on the whole certificate, so the pins survive leaf
/// rotation. The pinned keys are **Google Trust Services CA** keys because the
/// WINR backend is hosted on `*.cloudfunctions.net`, whose leaf certs are all
/// issued under the GTS hierarchy and rotate frequently. Pinning the long-lived
/// GTS CA SPKIs gives MITM protection that does not break on routine leaf
/// renewal.
class CertificatePinner {
  /// Pins in the form `sha256/<base64>` (HPKP-style), matched against the
  /// SPKI SHA-256 of each certificate presented in the chain.
  final List<String> pinnedKeys;

  const CertificatePinner(this.pinnedKeys);

  /// Validates a presented leaf certificate against the configured pins.
  ///
  /// Accepts if the SPKI SHA-256 of the cert matches ANY pin. SPKI extraction
  /// is done by walking the DER (see [_extractSpki]); if that fails (malformed
  /// DER), we fall back to hashing the full certificate DER — see the limitation
  /// note on [_spkiPin].
  bool validate(X509Certificate cert) {
    final pin = _spkiPin(Uint8List.fromList(cert.der));
    if (pin != null && pinnedKeys.contains(pin)) return true;

    // Documented fallback: pin on the full-certificate DER SHA-256. This is
    // LESS robust than SPKI pinning (it breaks whenever the cert itself rotates,
    // even if the key is unchanged) and is only used if SPKI extraction fails.
    final derPin =
        'sha256/${base64.encode(sha256.convert(cert.der).bytes)}';
    return pinnedKeys.contains(derPin);
  }

  /// Computes `sha256/<base64>` over the certificate's SubjectPublicKeyInfo,
  /// or null if the SPKI cannot be located.
  static String? _spkiPin(Uint8List der) {
    final spki = _extractSpki(der);
    if (spki == null) return null;
    return 'sha256/${base64.encode(sha256.convert(spki).bytes)}';
  }

  /// Minimal DER walker that extracts the SubjectPublicKeyInfo sub-structure
  /// from an X.509 certificate.
  ///
  /// Structure: Certificate ::= SEQUENCE { tbsCertificate SEQUENCE { ... ,
  /// subjectPublicKeyInfo SEQUENCE { algorithm, subjectPublicKey } } }.
  /// The SPKI is itself a SEQUENCE whose first element is the algorithm
  /// identifier SEQUENCE (tag 0x30) and whose second element is a BIT STRING
  /// (tag 0x03). We scan the TBSCertificate for the first SEQUENCE matching
  /// that shape and return its full DER (tag+length+content).
  static Uint8List? _extractSpki(Uint8List der) {
    try {
      var pos = 0;
      // Outer Certificate SEQUENCE.
      pos = _expectSeq(der, pos);
      // tbsCertificate SEQUENCE.
      final tbsStart = pos;
      if (der[tbsStart] != 0x30) return null;
      final tbsContent = _readLen(der, tbsStart + 1);
      final tbsEnd = tbsContent.contentStart + tbsContent.length;
      var p = tbsContent.contentStart;
      // Walk the TBSCertificate fields looking for the SPKI SEQUENCE.
      while (p < tbsEnd) {
        final tag = der[p];
        final len = _readLen(der, p + 1);
        final fieldStart = p;
        final fieldEnd = len.contentStart + len.length;
        if (tag == 0x30) {
          // Candidate SEQUENCE — check it looks like an SPKI:
          // first inner element is a SEQUENCE (algorithm), and somewhere a
          // BIT STRING (0x03) follows.
          final innerStart = len.contentStart;
          if (innerStart < fieldEnd && der[innerStart] == 0x30) {
            final algLen = _readLen(der, innerStart + 1);
            final afterAlg = algLen.contentStart + algLen.length;
            if (afterAlg < fieldEnd && der[afterAlg] == 0x03) {
              return Uint8List.sublistView(der, fieldStart, fieldEnd);
            }
          }
        }
        p = fieldEnd;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static int _expectSeq(Uint8List der, int pos) {
    if (der[pos] != 0x30) throw const FormatException('expected SEQUENCE');
    final len = _readLen(der, pos + 1);
    return len.contentStart;
  }

  /// Reads a DER length field starting at [pos], returning where the content
  /// begins and how long it is.
  static _DerLen _readLen(Uint8List der, int pos) {
    final first = der[pos];
    if (first < 0x80) {
      return _DerLen(pos + 1, first);
    }
    final numBytes = first & 0x7f;
    var length = 0;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | der[pos + 1 + i];
    }
    return _DerLen(pos + 1 + numBytes, length);
  }

  /// Default pinned Google Trust Services CA public keys (SPKI SHA-256).
  /// Backend runs on `*.cloudfunctions.net` (GTS-issued leaves).
  static const List<String> defaultPins = [
    // GTS Root R1 — long-lived root, stable through 2036.
    'sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=',
    // GTS WR2 intermediate — backup pin in case issuance moves intermediates.
    'sha256/YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM=',
  ];
}

/// Result of reading a DER TLV length field.
class _DerLen {
  final int contentStart;
  final int length;
  const _DerLen(this.contentStart, this.length);
}
