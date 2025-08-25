class AQIModel {
  final int aqi;
  final String category;
  final Map<String, dynamic> pollutants;
  final String city;
  final String country;
  final int temp;
  final int humidity;
  final double windSpeed;

  AQIModel({
    required this.aqi,
    required this.category,
    required this.pollutants,
    required this.city,
    required this.country,
    required this.temp,
    required this.humidity,
    required this.windSpeed,
  });

  factory AQIModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pollution = data['current']['pollution'];
    final weather = data['current']['weather'];

    int aqi = pollution['aqius'];
    String category = _aqiCategory(aqi);

    return AQIModel(
      aqi: aqi,
      category: category,
      pollutants: {
        pollution['mainus']: {
          'concentration': {
            'value': aqi,
            'units': 'AQI US',
          },
        },
      },
      city: data['city'],
      country: data['country'],
      temp: weather['tp'],
      humidity: weather['hu'],
      windSpeed: (weather['ws'] as num).toDouble(),
    );
  }

  static String _aqiCategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
}
