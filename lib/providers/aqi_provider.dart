import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/aqi_model.dart';

final aqiProvider = FutureProvider<AQIModel>((ref) async {
  final url = 'https://api.airvisual.com/v2/nearest_city?key=6d2c6642-6252-42d6-8edc-f251b6117f10';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return AQIModel.fromJson(data);
  } else {
    throw Exception('Failed to load AQI data');
  }
});
