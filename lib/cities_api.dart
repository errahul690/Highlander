import 'dart:convert';
import 'package:http/http.dart' as http;
import 'otp_api.dart';

class CitiesApi {
  CitiesApi({http.Client? client}) : _client = client ?? http.Client();
  static CitiesApi instance = CitiesApi();
  final http.Client _client;

  Future<List<Map<String, dynamic>>> search(String query) async {
    final uri = Uri.parse('${OtpApi.apiBase}/api/common/cities').replace(queryParameters: {'q': query});
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'City search is unavailable. Enter your city manually.');
    }
    return (data['cities'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
