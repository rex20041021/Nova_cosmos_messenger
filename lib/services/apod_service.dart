import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nova_cosmos_messenger/config/api_config.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';

class ApodService {
  static Future<ApodData> fetchApod({String? date, bool random = false}) async {
    final params = <String, String>{};
    if (random) {
      params['random'] = 'true';
    } else if (date != null) {
      params['date'] = date;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/apod').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 200));
    if (response.statusCode != 200) {
      throw Exception('APOD fetch failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ApodData.fromJson(json);
  }
}
