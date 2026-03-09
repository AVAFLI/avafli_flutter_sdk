import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base class for all API requests.
///
/// Defines the structure for requests to the WINR backend and handles
/// response parsing with proper error handling.
abstract class ApiRequest<T> {
  /// HTTP method for this request
  String get method;

  /// API endpoint path (relative to base URL)
  String get endpoint;

  /// Request body data (for POST/PUT requests)
  Map<String, dynamic>? get body;

  /// Parses the HTTP response into the expected type.
  T parseResponse(http.Response response);

  /// Helper method to parse JSON responses safely.
  Map<String, dynamic> parseJsonResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw const FormatException('Response is not a JSON object');
      }
    } catch (e) {
      throw FormatException('Invalid JSON response: $e');
    }
  }
}

/// Base class for GET requests.
abstract class GetRequest<T> extends ApiRequest<T> {
  @override
  String get method => 'GET';

  @override
  Map<String, dynamic>? get body => null;
}

/// Base class for POST requests.
abstract class PostRequest<T> extends ApiRequest<T> {
  @override
  String get method => 'POST';
}

/// Base class for PUT requests.
abstract class PutRequest<T> extends ApiRequest<T> {
  @override
  String get method => 'PUT';
}

/// Base class for DELETE requests.
abstract class DeleteRequest<T> extends ApiRequest<T> {
  @override
  String get method => 'DELETE';

  @override
  Map<String, dynamic>? get body => null;
}

/// Response wrapper for requests that return simple success status.
class SuccessResponse {
  final bool success;
  final String? message;

  const SuccessResponse({
    required this.success,
    this.message,
  });

  factory SuccessResponse.fromJson(Map<String, dynamic> json) {
    return SuccessResponse(
      success: json['success'] ?? true,
      message: json['message'],
    );
  }
}

/// Response wrapper that includes additional metadata.
class MetadataResponse<T> {
  final T data;
  final Map<String, dynamic>? metadata;

  const MetadataResponse({
    required this.data,
    this.metadata,
  });
}
