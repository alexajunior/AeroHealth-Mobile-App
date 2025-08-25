import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aerohealth/models/aqi_model.dart';
import 'package:aerohealth/services/location_service.dart';

class AQIService {
  static const _apiKey = 'YOUR_API_KEY'; // Replace with your actual API key

  static Future<AQIModel> fetchAQIData() async {
    final pos = await LocationService.getCurrentLocation();
    final lat = pos.latitude;
    final lon = pos.longitude;

    final url = Uri.parse(
        'https://api.airvisual.com/v2/nearest_city?lat=$lat&lon=$lon&key=$_apiKey');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch AQI: ${res.statusCode}');
    }

    final jsonData = json.decode(res.body);
    return AQIModel.fromJson(jsonData);
  }
}