import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://abdul-nondivergent-penny.ngrok-free.dev';

  static Future<List<Map<String, dynamic>>> fetchReadings({
    required String type,
    String filter = 'all',
    String? deviceId,
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['filter'] = filter;
      if (deviceId != null) {
        queryParams['deviceId'] = deviceId;
      }

      final uri = Uri.parse('$baseUrl/readings/$type')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [];
        }
      } else {
        throw Exception(
            'Failed to fetch $type readings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching $type readings: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllReadings({
    String filter = 'all',
    String? deviceId,
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['filter'] = filter;
      if (deviceId != null) {
        queryParams['deviceId'] = deviceId;
      }

      final uri =
          Uri.parse('$baseUrl/readings').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to fetch readings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching readings: $e');
      return [];
    }
  }
}
