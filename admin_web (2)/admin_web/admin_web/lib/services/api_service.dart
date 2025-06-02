import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AdminApiService {
  Future<bool> validateToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final token = prefs.getString('token');
    if (token == null) {
      print('No token found in SharedPreferences');
      return false;
    }

    try {
      final payload = _decodeToken(token);
      print('Token payload: $payload');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/auth/validate'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
        'Token validation: status=${response.statusCode}, body=${response.body}',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Token validation failed: $e');
      return false;
    }
  }

  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final token = prefs.getString('token');
    if (token == null) {
      print('No token found for refresh');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token']?.toString();
        if (newToken != null) {
          await prefs.setString('token', newToken);
          print('Token refreshed: $newToken');
          return newToken;
        }
      }
      print(
        'Token refresh failed: status=${response.statusCode}, body=${response.body}',
      );
      return null;
    } catch (e) {
      print('Token refresh error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = _handleResponse(response, '/auth/login');
      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('role', data['user']?['role'] ?? 'user');
        await prefs.setString('userId', data['user']?['id']?.toString() ?? '');
        await prefs.setString('name', data['user']?['name']?.toString() ?? '');
        await prefs.setString(
          'email',
          data['user']?['email']?.toString() ?? '',
        );
        print(
          'Stored prefs: token=${data['token']}, userId=${data['user']?['_id']}',
        );
      }
      return data;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print('No token found, proceeding with logout');
      } else {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode != 200) {
          print(
            'Logout API call failed: ${response.statusCode} ${response.body}',
          );
        }
      }
      await prefs.remove('token');
      await prefs.remove('role');
      await prefs.remove('userId');
      await prefs.remove('name');
      await prefs.remove('email');
    } catch (e) {
      print('Error during logout: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('role');
      await prefs.remove('userId');
      await prefs.remove('name');
      await prefs.remove('email');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    return _withTokenRetry<List<Map<String, dynamic>>>(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString('token');
      if (token == null) throw Exception('User not authenticated');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final bodySnippet =
          response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body;
      print(
        'Get users response: status ${response.statusCode}, body: $bodySnippet, length: ${response.body.length}',
      );
      final decodedResponse = _handleResponse(response, '/users');
      if (decodedResponse is! List) {
        throw Exception(
          'Expected a list from /users, got ${decodedResponse.runtimeType}',
        );
      }
      return (decodedResponse).cast<Map<String, dynamic>>();
    });
  }

  Future<Map<String, dynamic>> getReports({
    int page = 1,
    int limit = 10,
  }) async {
    return _withTokenRetry<Map<String, dynamic>>(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString('token');
      if (token == null) throw Exception('User not authenticated');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/missing-persons?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
        'Get reports response: status ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = _handleResponse(response, '/missing-persons');
        if (data is Map<String, dynamic> && data['missingPersons'] is List) {
          return {
            'reports': List<Map<String, dynamic>>.from(data['missingPersons']),
            'pagination': Map<String, dynamic>.from(data['pagination'] ?? {}),
          };
        }
        throw Exception(
          'Expected a map with a "missingPersons" list, but got: $data',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Session expired or unauthorized. Please log in again. Status: ${response.statusCode}, Message: ${jsonDecode(response.body)['message'] ?? ''}',
        );
      } else {
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
          throw Exception(
            'Failed to fetch reports: ${errorBody['message']} - ${errorBody['error'] ?? ''}',
          );
        } catch (_) {
          throw Exception(
            'Failed to fetch reports: HTTP ${response.statusCode}',
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSightings(String reportId) async {
    return _withTokenRetry<List<Map<String, dynamic>>>(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString('token');
      if (token == null) throw Exception('User not authenticated');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/missing-persons/$reportId/sightings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = _handleResponse(
        response,
        '/missing-persons/$reportId/sightings',
      );
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Expected a list of sightings, but got: $data');
    });
  }

  Future<Map<String, dynamic>> updateReportStatus(
    String reportId,
    String status,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/missing-persons/$reportId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    print('Updating report status: $reportId to $status');
    print('Response: ${response.statusCode} ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : {};
    }
    try {
      final data = jsonDecode(response.body);
      throw Exception(
        data['message'] ??
            'Failed to update report status: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(
        'Failed to update report status: ${response.statusCode}, response: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> updateSightingStatus(
    String missingPersonId,
    String sightingId,
    String status,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.patch(
      Uri.parse(
        '$apiBaseUrl/missing-persons/$missingPersonId/sightings/$sightingId/status',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    print('Updating sighting status: $sightingId to $status');
    print('Response: ${response.statusCode} ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : {};
    }
    try {
      final data = jsonDecode(response.body);
      throw Exception(
        data['message'] ??
            'Failed to update sighting status: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(
        'Failed to update sighting status: ${response.statusCode}, response: ${response.body}',
      );
    }
  }

  Future<void> deleteMissingPerson(String id) async {
    await _withTokenRetry<void>(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString('token');
      if (token == null) throw Exception('User not authenticated');

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/missing-persons/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      _handleResponse(response, '/missing-persons/$id');
    });
  }

  Future<T> _withTokenRetry<T>(Future<T> Function() request) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final token = prefs.getString('token');
        if (token == null) throw Exception('User not authenticated');

        return await request();
      } catch (e) {
        if (e.toString().contains('429 Too many requests')) {
          if (attempt == maxRetries - 1) {
            print('Max retries reached for 429 error: $e');
            throw Exception('Too many requests. Please try again later.');
          }
          final delay =
              baseDelay * (1 << attempt); // Exponential backoff: 2s, 4s, 8s
          print(
            'Retrying after 429 error, attempt ${attempt + 1}, delay: $delay',
          );
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Unexpected error after retries');
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Retrieved token: $token');
    return token;
  }

  dynamic _handleResponse(http.Response response, String endpoint) {
    final isHtml =
        response.body.trim().startsWith('<!DOCTYPE') ||
        response.body.contains('<html');
    if (isHtml) {
      print(
        'Received HTML instead of JSON from $endpoint: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
      throw Exception('Received HTML instead of JSON from $endpoint');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print(
          'Error decoding JSON at $endpoint: $e, raw body: ${response.body}',
        );
        throw Exception('Failed to parse response: $e');
      }
    } else {
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          'Request to $endpoint failed: ${errorBody['message']} - ${errorBody['error'] ?? ''}',
        );
      } catch (e) {
        print(
          'Error parsing error response at $endpoint: $e, raw body: ${response.body}',
        );
        throw Exception(
          'Request to $endpoint failed: HTTP ${response.statusCode}, body: ${response.body}',
        );
      }
    }
  }

  Map<String, dynamic>? _decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      print('Failed to decode token: $e');
      return null;
    }
  }
}
