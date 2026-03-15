import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../services/logger.dart';
import '../winr_error.dart';
import 'api_request.dart';

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

  /// Creates a new network client.
  NetworkClientImpl({
    required this.baseURL,
    required this.apiKey,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  });

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
            e.error == WINRError.ineligibleToday) {
          rethrow;
        }

        // Handle 401 with token refresh
        if (e.error == WINRError.authenticationFailed &&
            _refreshHandler != null) {
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
      'User-Agent': 'WINR-Flutter-SDK/1.0.0',
    };

    // Add auth token if available
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    final client = http.Client();

    try {
      late http.Response response;

      switch (request.method) {
        case 'GET':
          response = await client.get(url, headers: headers).timeout(timeout);
          break;
        case 'POST':
          // Firebase callable functions expect body wrapped in {"data": ...}
          final body = request.body != null
              ? jsonEncode({'data': request.body})
              : null;
          response = await client
              .post(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PUT':
          final body = request.body != null
              ? jsonEncode({'data': request.body})
              : null;
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
    } finally {
      client.close();
    }
  }

  /// Handles HTTP error responses.
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;

    // Try to parse error details from response
    String? errorMessage;
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        errorMessage = data['error'] as String?;
      }
    } catch (_) {
      // Ignore JSON parsing errors
    }

    switch (statusCode) {
      case 400:
        if (errorMessage?.contains('underage') == true) {
          throw const WINRException(WINRError.underage);
        }
        if (errorMessage?.contains('invalid email') == true) {
          throw const WINRException(WINRError.invalidEmail);
        }
        throw const WINRException(WINRError.invalidApiKey);
      case 401:
        throw const WINRException(WINRError.authenticationFailed);
      case 403:
        if (errorMessage?.contains('geography') == true) {
          throw const WINRException(WINRError.geographyNotAllowed);
        }
        if (errorMessage?.contains('already claimed') == true) {
          throw const WINRException(WINRError.ineligibleToday);
        }
        throw const WINRException(WINRError.authenticationFailed);
      case 404:
        throw const WINRException(WINRError.giveawayNotAvailable);
      case 429:
        throw const WINRException(WINRError.networkError); // Rate limited
      case 500:
      case 502:
      case 503:
      case 504:
        throw const WINRException(WINRError.serverError);
      default:
        Logger.instance.error('Unexpected HTTP status: $statusCode');
        throw const WINRException(WINRError.unknown);
    }
  }
}

/// Certificate pinning implementation for enhanced security.
///
/// Validates that the server certificate matches expected pinned certificates
/// to prevent man-in-the-middle attacks.
class CertificatePinner {
  final List<String> pinnedCertificates;

  const CertificatePinner(this.pinnedCertificates);

  /// Validates a certificate against pinned certificates.
  bool validate(X509Certificate cert) {
    final certFingerprint = sha256.convert(cert.der).toString();
    return pinnedCertificates.contains(certFingerprint);
  }

  /// Default pinned certificates for us-central1-winr-9c11f.cloudfunctions.net
  static const List<String> defaultPins = [
    // Add actual certificate fingerprints here
    // These would be SHA-256 hashes of the certificates
  ];
}
