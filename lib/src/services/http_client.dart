// lib/src/services/http_client.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class HttpClient {
  final String baseUrl;
  final String apiKey;
  final Logger _logger;
  late final http.Client _client;

  HttpClient({
    required this.baseUrl,
    required this.apiKey,
    required bool enableLogs,
  }) : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        ) {
    _client = http.Client();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': apiKey,
      };

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _logger.d('GET $url');

    try {
      final response = await _client.get(url, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      _logger.e('GET request failed: $e');
      throw WebRTCException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _logger.d('POST $url');
    _logger.d('Data: $data');

    try {
      final response = await _client.post(
        url,
        headers: _headers,
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      _logger.e('POST request failed: $e');
      throw WebRTCException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _logger.d('PUT $url');

    try {
      final response = await _client.put(
        url,
        headers: _headers,
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      _logger.e('PUT request failed: $e');
      throw WebRTCException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _logger.d('DELETE $url');

    try {
      final response = await _client.delete(url, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      _logger.e('DELETE request failed: $e');
      throw WebRTCException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _logger.d('UPLOAD $url');

    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'X-API-KEY': apiKey,
      });

      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _logger.e('File upload failed: $e');
      throw WebRTCException('Upload error: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    _logger.d('Response ${response.statusCode}: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'success': true};
      }
    } else {
      String errorMessage = 'Request failed';
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage =
            errorData['message'] ?? errorData['error'] ?? errorMessage;
      } catch (e) {
        errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
      }
      throw WebRTCException(errorMessage);
    }
  }

  void dispose() {
    _client.close();
  }
}

class WebRTCException implements Exception {
  final String message;
  const WebRTCException(this.message);

  @override
  String toString() => 'WebRTCException: $message';
}
