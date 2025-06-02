import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _handleResponse(response);
    if (response.statusCode == 200 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('role', data['user']['role'] ?? 'user');
      await prefs.setString('name', data['user']['name'] ?? '');
      await prefs.setString('email', data['user']['email'] ?? '');
      await prefs.setString('id', data['user']['_id'] ?? '');
      print('Login successful, token saved: ${data['token']}');
    }
    return data;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = _handleResponse(response);
    if (response.statusCode == 201 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('role', data['user']['role'] ?? 'user');
      await prefs.setString('name', data['user']['name'] ?? name);
      await prefs.setString('email', data['user']['email'] ?? email);
      await prefs.setString('id', data['user']['_id'] ?? '');
    }
    return data;
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      await http.post(
        Uri.parse('$apiBaseUrl/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('id');
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<Map<String, dynamic>> getUserData(BuildContext context) async {
    final response = await _getRequest('/users/profile', context);
    return response;
  }

  Future<Map<String, dynamic>> getProfile(BuildContext context) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/users/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile(
    String name,
    String email,
    String phone,
    XFile? profilePicture,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$apiBaseUrl/users/profile'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['phone'] = phone;

    if (profilePicture != null) {
      final fileBytes = await profilePicture.readAsBytes();
      final fileName = profilePicture.name;
      request.files.add(
        http.MultipartFile.fromBytes(
          'profilePicture',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', fileName.split('.').last),
        ),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', name);
      await prefs.setString('email', email);
      return responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
    }
    try {
      final data = jsonDecode(responseBody);
      throw Exception(
        data['message'] ?? 'Request failed with status: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(
        'Request failed with status: ${response.statusCode}, response: $responseBody',
      );
    }
  }

  Future<Map<String, dynamic>> getReport(
    String reportId,
    BuildContext context,
  ) async {
    final response = await _getRequest('/missing-persons/$reportId', context);
    return response;
  }

  Future<Map<String, dynamic>> getReports({
    String? name,
    int? ageMin,
    int? ageMax,
    String? gender,
    String? location,
    double? radius,
    bool? myPosts,
    int page = 1,
    int limit = 10,
    required BuildContext context,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();
    if (name != null) queryParams['name'] = name;
    if (ageMin != null) queryParams['ageMin'] = ageMin.toString();
    if (ageMax != null) queryParams['ageMax'] = ageMax.toString();
    if (gender != null) queryParams['gender'] = gender;
    if (location != null) queryParams['location'] = location;
    if (radius != null) queryParams['radius'] = radius.toString();
    if (myPosts != null) queryParams['myPosts'] = myPosts.toString();

    final uri = Uri.parse(
      '$apiBaseUrl/missing-persons',
    ).replace(queryParameters: queryParams);
    print('Request URL: $uri');
    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );
      if (response.statusCode == 401) {
        await _handleUnauthorized(context);
      }
      final data = _handleResponse(response);
      if (data is Map<String, dynamic> && data['missingPersons'] is List) {
        return {
          'reports': List<Map<String, dynamic>>.from(data['missingPersons']),
          'pagination': Map<String, dynamic>.from(data['pagination'] ?? {}),
        };
      }
      throw Exception(
        'Expected a map with a "missingPersons" list, but got: $data',
      );
    } catch (e) {
      print('HTTP error: $e');
      rethrow;
    }
  }

  Future<void> updateReport(
    String reportId,
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$apiBaseUrl/missing-persons/$reportId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    _handleResponse(response);
  }

  Future<void> deleteReport(String reportId, BuildContext context) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$apiBaseUrl/missing-persons/$reportId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    _handleResponse(response);
  }

  Future<Map<String, dynamic>> submitSighting(
    String missingPersonId,
    Map<String, dynamic> sighting,
    List<XFile> images,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/missing-persons/$missingPersonId/sightings'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['reportId'] = missingPersonId;
    request.fields['description'] = sighting['description'] ?? '';
    request.fields['dateTime'] = sighting['location']['dateTime'] ?? '';
    if (sighting['location']['address'] != null &&
        sighting['location']['address'].isNotEmpty) {
      request.fields['address'] = sighting['location']['address'];
    }
    if (sighting['location']['coordinates'] != null) {
      request.fields['coordinates'] = jsonEncode(
        sighting['location']['coordinates'],
      );
    }
    if (sighting['contactInfo']['name'] != null &&
        sighting['contactInfo']['name'].isNotEmpty) {
      request.fields['name'] = sighting['contactInfo']['name'];
    }
    if (sighting['contactInfo']['phone'] != null &&
        sighting['contactInfo']['phone'].isNotEmpty) {
      request.fields['phone'] = sighting['contactInfo']['phone'];
    }
    if (sighting['contactInfo']['email'] != null &&
        sighting['contactInfo']['email'].isNotEmpty) {
      request.fields['email'] = sighting['contactInfo']['email'];
    }

    for (var image in images) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            bytes,
            filename: image.name,
            contentType: MediaType('image', image.name.split('.').last),
          ),
        );
      } else {
        final file = File(image.path);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'photos',
              file.path,
              contentType: MediaType('image', image.name.split('.').last),
            ),
          );
        }
      }
    }

    print('Submitting sighting for report: $missingPersonId');
    print('Sighting data: ${request.fields}');
    print('Photos: ${request.files.map((f) => f.filename).toList()}');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    print('Sighting submission response: ${response.statusCode} $responseBody');

    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
    }
    try {
      final data = jsonDecode(responseBody);
      throw Exception(
        data['message'] ?? 'Failed to submit sighting: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(
        'Failed to submit sighting: ${response.statusCode}, response: $responseBody',
      );
    }
  }

  Future<Map<String, dynamic>> updateSighting(
    String missingPersonId,
    String sightingId,
    Map<String, dynamic> sighting,
    List<XFile> images,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse(
        '$apiBaseUrl/missing-persons/$missingPersonId/sightings/$sightingId',
      ),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['description'] = sighting['description'] ?? '';
    request.fields['dateTime'] = sighting['location']['dateTime'] ?? '';
    if (sighting['location']['address'] != null &&
        sighting['location']['address'].isNotEmpty) {
      request.fields['address'] = sighting['location']['address'];
    }
    if (sighting['location']['coordinates'] != null) {
      request.fields['coordinates'] = jsonEncode(
        sighting['location']['coordinates'],
      );
    }
    if (sighting['contactInfo']['name'] != null &&
        sighting['contactInfo']['name'].isNotEmpty) {
      request.fields['name'] = sighting['contactInfo']['name'];
    }
    if (sighting['contactInfo']['phone'] != null &&
        sighting['contactInfo']['phone'].isNotEmpty) {
      request.fields['phone'] = sighting['contactInfo']['phone'];
    }
    if (sighting['contactInfo']['email'] != null &&
        sighting['contactInfo']['email'].isNotEmpty) {
      request.fields['email'] = sighting['contactInfo']['email'];
    }

    for (var image in images) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            bytes,
            filename: image.name,
            contentType: MediaType('image', image.name.split('.').last),
          ),
        );
      } else {
        final file = File(image.path);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'photos',
              file.path,
              contentType: MediaType('image', image.name.split('.').last),
            ),
          );
        }
      }
    }

    print('Updating sighting: $sightingId for report: $missingPersonId');
    print('Sighting data: ${request.fields}');
    print('Photos: ${request.files.map((f) => f.filename).toList()}');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    print('Sighting update response: ${response.statusCode} $responseBody');

    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
    }
    try {
      final data = jsonDecode(responseBody);
      throw Exception(
        data['message'] ?? 'Failed to update sighting: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(
        'Failed to update sighting: ${response.statusCode}, response: $responseBody',
      );
    }
  }

  Future<Map<String, dynamic>> updateSightingStatus(
    String missingPersonId,
    String sightingId,
    String status,
    BuildContext context,
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

    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
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

  Future<List<Map<String, dynamic>>> getSightings(
    String missingPersonId,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/missing-persons/$missingPersonId/sightings'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Fetching sightings for report: $missingPersonId');
    print('Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    final data = _handleResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Expected a list of sightings, but got: $data');
  }

  Future<Map<String, dynamic>> submitReport(
    Map<String, dynamic> reportData,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) {
      await _handleUnauthorized(context);
      return {};
    }

    final response = await http.post(
      Uri.parse('$apiBaseUrl/missing-persons'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(reportData),
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String reportId,
    String content,
  ) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(reportId)) {
      throw Exception('Invalid reportId format: $reportId');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No token found');

    // ignore: avoid_print
    print('Sending message with reportId: $reportId, content: $content');

    final response = await http.post(
      Uri.parse('$apiBaseUrl/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'conversationId': conversationId,
        'reportId': reportId,
        'content': content,
      }),
    );

    // ignore: avoid_print
    print(
      'Send message response: status ${response.statusCode}, body: ${response.body}',
    );

    if (response.statusCode == 201) {
      return {'status': response.statusCode, 'body': jsonDecode(response.body)};
    }
    throw Exception('Failed to send message: ${response.body}');
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/messages/$conversationId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    final data = _handleResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Expected a list of messages, but got: $data');
  }

  Future<List<Map<String, dynamic>>> getConversations(
    BuildContext context,
  ) async {
    final response = await _authenticatedRequest(
      context: context,
      request:
          (token) => http.get(
            Uri.parse('$apiBaseUrl/conversations'),
            headers: {'Authorization': 'Bearer $token'},
          ),
    );
    print(
      'Get conversations response: status ${response.statusCode}, body: ${response.body}',
    );

    final data = _handleResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Expected a list of conversations, but got: $data');
  }

  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(conversationId)) {
      throw Exception('Invalid conversationId format: $conversationId');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/conversations/$conversationId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    // ignore: avoid_print
    print(
      'Get conversation response: status ${response.statusCode}, body: ${response.body}',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch conversation: ${response.body}');
  }

  Future<Map<String, dynamic>> getOrCreateConversation(
    String reportId,
    String participantId,
    BuildContext context,
  ) async {
    final response = await _authenticatedRequest(
      context: context,
      request: (token) {
        print(
          'Sending conversation request with reportId: $reportId, participantIds: [$participantId]',
        );
        return http.post(
          Uri.parse('$apiBaseUrl/conversations'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'reportId': reportId,
            'participantIds': [participantId], // Send as array
          }),
        );
      },
    );
    print(
      'Get or create conversation response: status ${response.statusCode}, body: ${response.body}',
    );

    return _handleResponse(response);
  }

  Future<dynamic> _getRequest(String endpoint, BuildContext context) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$apiBaseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Request failed with status: ${response.statusCode}, response: ${response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications(
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    final data = _handleResponse(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Expected a list of notifications, but got: $data');
  }

  Future<void> markNotificationAsRead(
    String notificationId,
    BuildContext context,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      await _handleUnauthorized(context);
    }
    _handleResponse(response);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Retrieved token: $token');
    return token;
  }

  Future<bool> _refreshToken(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('token');
    if (oldToken == null) {
      print('Refresh token: No old token found');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Authorization': 'Bearer $oldToken'},
      );
      print(
        'Refresh token response: status ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('token', data['token']);
        print('Token refreshed successfully');
        return true;
      }
      print('Refresh token failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('Refresh token error: $e');
      return false;
    }
  }

  Future<void> _handleUnauthorized(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('id');
    await prefs.remove('name');
    await prefs.remove('email');
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception(
      'Request failed: ${response.statusCode}, response: ${response.body}',
    );
  }

  Future<http.Response> _authenticatedRequest({
    required Future<http.Response> Function(String token) request,
    required BuildContext context,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('Authenticated request: No token found');
      await _handleUnauthorized(context);
      throw Exception('Not authenticated');
    }

    final response = await request(token);
    if (response.statusCode == 401) {
      print('Authenticated request: Received 401, attempting token refresh');
      final refreshed = await _refreshToken(context);
      if (refreshed) {
        final newToken = await _getToken();
        if (newToken != null) {
          print('Authenticated request: Retrying with new token');
          return await request(newToken);
        }
      }
      print('Authenticated request: Token refresh failed, logging out');
      await _handleUnauthorized(context);
      throw Exception('Session expired. Please log in again.');
    }
    return response;
  }
}
