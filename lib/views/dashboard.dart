import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:aerohealth/views/devicesscreen.dart';
import 'package:aerohealth/views/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:aerohealth/views/map.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aerohealth/views/education.dart';
import 'package:geocoding/geocoding.dart';



final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class UserProfile {
  final String respiratoryCondition;
  UserProfile({required this.respiratoryCondition});
}



void _setupNotifications(BuildContext ctx) async {
  if (kIsWeb) {
    return;
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ Notification permission granted');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showDialog(
          context: ctx, // make sure ctx is passed into _setupNotifications(ctx)
          builder: (_) => AlertDialog(
            title: Text(message.notification!.title ?? "📬 New Notification"),
            content: Text(message.notification!.body ?? ""),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK")),
            ],
          ),
        );
      }
    });


  }
}

void _initializeNotifications() async {
  if (kIsWeb) {
    return;
  }

  const AndroidInitializationSettings androidInitSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
  InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}


void _showAQIAlert(BuildContext ctx, String title, String message) {
  showDialog(
    context: ctx,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

void _saveUserLocationAndToken(Position pos) async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();

    await FirebaseFirestore.instance.collection('users').doc(token).set({
      'fcmToken': token,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print("📍 Token & location saved to Firestore");
  } catch (e) {
    print("❌ Error saving to Firestore: $e");
  }
}




class _HomeScreenState extends State<HomeScreen> {
  final UserProfile userProfile = UserProfile(respiratoryCondition: 'Asthma');
  int? liveAQI;
  int currentAQI = 0;
  bool isHealthTipsExpanded = false;
  bool isLoading = false;
  String userCity = 'Loading...';
  String userCountry = '';
  String mainPollutant = 'Loading...';
  double pm25 = 0.0;
  double pm10 = 0.0;
  double no2 = 0.0;
  double o3 = 0.0;
  String weatherCondition = "Loading...";
  double temperature = 0.0;
  int humidity = 0;
  double windSpeed = 0.0;
  double uvIndex = 0.0;
  List<int> forecastAQI = [];
  List<Map<String, dynamic>> hourlyWeather = [];
  Position? _currentPosition;
  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return WeatherIcons.day_sunny;
      case 'clouds':
        return WeatherIcons.cloudy;
      case 'rain':
        return WeatherIcons.rain;
      case 'drizzle':
        return WeatherIcons.sprinkle;
      case 'thunderstorm':
        return WeatherIcons.thunderstorm;
      case 'snow':
        return WeatherIcons.snow;
      case 'mist':
      case 'fog':
      case 'haze':
      case 'smoke':
        return WeatherIcons.fog;
      default:
        return WeatherIcons.na;
    }
  }
  bool isDarkMode = false;





  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeNotifications();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupNotifications(context);
      });

      FirebaseMessaging.instance.getToken().then((token) {
        print('🔥 FCM Token: $token');
      });
    }

    _loadDashboardData();
  }

  Future<Position?> _getDevicePosition() async {
    if (_currentPosition != null) {
      return _currentPosition;
    }

    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => userCity = 'Location services are off');
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => userCity = 'Location permission required');
        }
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      debugPrint('Location initialization failed: $e');
      if (mounted) {
        setState(() => userCity = 'Location unavailable');
      }
      return null;
    }
  }

  Future<void> _loadDashboardData() async {
    final position = await _getDevicePosition();
    if (position == null) {
      return;
    }

    await Future.wait([
      fetchAQIData(),
      fetchPollutants(),
      fetchAQIForecast(),
      fetchHourlyWeather(),
      fetchWeatherInfo(),
    ]);
  }

  Future<Map<String, String>> _resolveLocationName(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = <String?>[
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ].whereType<String>().firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );
        final country = placemark.country ?? '';
        if (city.isNotEmpty || country.isNotEmpty) {
          return {'city': city.isNotEmpty ? city : 'Your location', 'country': country};
        }
      }
    } catch (e) {
      debugPrint('Device geocoding unavailable: $e');
    }

    try {
      const mapsApiKey = 'AIzaSyCNvZqqlb8QL5nM0E4KKZ7Q5zjtwZFE5tk';
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'key': mapsApiKey,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          String city = '';
          String country = '';
          final components = results.first['address_components'] as List<dynamic>? ?? [];
          for (final component in components) {
            final types = List<String>.from(component['types'] ?? []);
            final name = component['long_name'] as String? ?? '';
            if (types.contains('locality') ||
                types.contains('postal_town') ||
                types.contains('administrative_area_level_2')) {
              city = city.isEmpty ? name : city;
            } else if (types.contains('country')) {
              country = name;
            }
          }
          return {
            'city': city.isNotEmpty ? city : 'Your location',
            'country': country,
          };
        }
      }
    } catch (e) {
      debugPrint('Google reverse geocoding unavailable: $e');
    }

    return {'city': 'Your location', 'country': 'Location detected'};
  }


  Future<void> fetchAQIData() async {
    if (!mounted) return;
    setState(() => isLoading = true); // Start loading

    final apiKey = '254a1023cb1fdfcf257a4c37a6a592e1'; // Replace with your actual API key

    try {
      final position = await _getDevicePosition();
      if (position == null) {
        return;
      }

      _saveUserLocationAndToken(position); // ✅ Save location to Firestore

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey',
      );

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final item = jsonResponse['list'][0];
        final aqi = item['main']['aqi'];
        final components = item['components'];
        final main = _getMainPollutant(components);
        final convertedAQI = _mapOWAQIToUSScale(aqi);

        setState(() {
          mainPollutant = main.toUpperCase();
          liveAQI = convertedAQI;
          currentAQI = convertedAQI;
        });

        final locationName = await _resolveLocationName(position);
        final city = locationName['city']!;
        final country = locationName['country']!;
        if (mounted) {
          setState(() {
            userCity = city;
            userCountry = country;
          });
        }

        if (convertedAQI > 150) {
          await showLocalNotification(
            "⚠️ Air Quality Alert",
            "AQI is $convertedAQI, bro this air be wild. Stay indoors!",
          );
        }

        final token = await FirebaseMessaging.instance.getToken();
        final user = FirebaseAuth.instance.currentUser;

        if (user != null && token != null) {
          await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
            "fcmToken": token,
            "currentAQI": convertedAQI,
            "city": city,
            "country": country,
          }, SetOptions(merge: true));

          print("📍 Token & AQI saved to Firestore");
        }

        if (convertedAQI > 150) {
          await FirebaseFirestore.instance.collection('alerts').add({
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'aqi': convertedAQI,
            'timestamp': Timestamp.now(),
          });
        }

        // 🧠 Show alert
        if (convertedAQI <= 50) {
          _showAQIAlert(context, "Air Quality: Excellent 😮‍💨", "The air is fresh and clean. Feel free to go outside and enjoy your day! 🌿");
        } else if (convertedAQI <= 100) {
          _showAQIAlert(context, "Air Quality: Moderate 😌", "Air quality is acceptable. You’re good to go about your activities.");
        } else if (convertedAQI <= 150) {
          _showAQIAlert(context, "Air Quality: Sensitive Groups Alert 🥴", "Air may not be ideal for those with respiratory conditions. Please take precautions.");
        } else if (convertedAQI <= 200) {
          _showAQIAlert(context, "Air Quality: Unhealthy 😷", "It's best to limit your time outdoors. Try to stay inside if possible.");
        } else {
          _showAQIAlert(context, "Air Quality: Very Unhealthy ☠️", "The air is seriously polluted. Stay indoors and consider wearing a mask if you must go out.");
        }

        print('💨 AQI (est.): $convertedAQI');
        print('🌍 Location: $city, $country');
      } else {
        print('❌ Failed to fetch AQI: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Error fetching AQI: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

// Converts OpenWeather's AQI (1–5) to approximate US AQI
  int _mapOWAQIToUSScale(int owAqi) {
    switch (owAqi) {
      case 1: return 50;
      case 2: return 100;
      case 3: return 150;
      case 4: return 200;
      case 5: return 300;
      default: return 0;
    }
  }

// Determines main pollutant by highest concentration
  String _getMainPollutant(Map<String, dynamic> components) {
    final sorted = components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }






  Future<void> fetchPollutants() async {
    final openWeatherKey = '254a1023cb1fdfcf257a4c37a6a592e1';

    try {
      final position = await _getDevicePosition();
      if (position == null) {
        return;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/air_pollution?lat=${position.latitude}&lon=${position.longitude}&appid=$openWeatherKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final components = data['list'][0]['components'];

        setState(() {
          pm25 = components['pm2_5'];
          pm10 = components['pm10'];
          no2 = components['no2'];
          o3 = components['o3'];
        });

        print('✅ Pollutants: PM2.5: $pm25, PM10: $pm10, NO2: $no2, O3: $o3');
      } else {
        print('❌ Pollutant fetch failed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Pollutant error: $e');
    }
  }

  Future<void> fetchAQIForecast() async {
    const token = '254a1023cb1fdfcf257a4c37a6a592e1';

    try {
      final position = await _getDevicePosition();
      if (position == null) {
        return;
      }

      final lat = position.latitude;
      final lon = position.longitude;

      final url =
          'https://pro.openweathermap.org/data/2.5/air_pollution/forecast?lat=$lat&lon=$lon&appid=$token';

      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final list = jsonResponse['list'];

        List<int> aqiList = [];
        for (int i = 0; i < 7; i++) {
          aqiList.add(list[i]['main']['aqi']);
        }

        setState(() {
          forecastAQI = aqiList;

        });

        print('🗓️ Forecast AQI: $forecastAQI');
      } else {
        print('❌ Forecast fetch failed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Forecast fetch error: $e');
    }
  }


  Future<void> fetchHourlyWeather() async {
    final apiKey = '254a1023cb1fdfcf257a4c37a6a592e1'; // my openweather key

    try {
      final position = await _getDevicePosition();
      if (position == null) {
        return;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['list'];

        List<Map<String, dynamic>> fetchedHourly = list.take(5).map((item) {
          final time = DateTime.parse(item['dt_txt']);
          final temp = item['main']['temp'].round().toString();
          final condition = item['weather'][0]['main'];

          IconData icon;
          switch (condition) {
            case 'Clear':
              icon = WeatherIcons.day_sunny;
              break;
            case 'Rain':
              icon = WeatherIcons.rain;
              break;
            case 'Clouds':
              icon = WeatherIcons.cloudy;
              break;
            default:
              icon = WeatherIcons.day_cloudy;
          }

          return {
            'time': time.hour.toString().padLeft(2, '0'),
            'icon': icon,
            'temp': '$temp°',
          };
        }).toList();

        setState(() {
          hourlyWeather = fetchedHourly;
        });
      } else {
        print('❌ Weather fetch failed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Error getting weather: $e');
    }
  }

  Future<void> fetchWeatherInfo() async {
    final apiKey = '254a1023cb1fdfcf257a4c37a6a592e1';

    try {
      final position = await _getDevicePosition();
      if (position == null) {
        return;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          temperature = data['main']['temp'];
          weatherCondition = data['weather'][0]['main'];
          humidity = data['main']['humidity'];
          windSpeed = data['wind']['speed'].toDouble();
        });

        print('🌤️ Weather: $weatherCondition, $temperature°C, Humidity: $humidity%, Wind: $windSpeed km/h');
      } else {
        print('❌ Weather fetch failed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Weather error: $e');
    }
  }

  Future<void> showLocalNotification(String title, String body) async {
    if (kIsWeb) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'aqi_channel',
      'AQI Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AeroHealth',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ?   Icons.nights_stay_outlined :Icons.wb_sunny_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(color: Colors.white, Icons.person),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Profile'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user != null)
                          Text('Logged in as:\n${user.email}')
                        else
                          const Text('Not logged in.'),
                      ],
                    ),
                    actions: [
                      if (user != null)
                        TextButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              );
                            }
                          },
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isDarkMode ? 'assets/brown.jpg' : 'assets/black.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 560;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                  _buildLocationHeader().animate().fadeIn(duration: 800.ms),
                  const SizedBox(height: 28),
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAQICard().animate().scale(
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: _buildAQIEmoji().animate().fadeIn(
                            duration: 800.ms,
                            delay: 200.ms,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildAQICard().animate().scale(
                            duration: 800.ms,
                            curve: Curves.easeOut,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildAQIEmoji().animate().fadeIn(
                          duration: 800.ms,
                          delay: 200.ms,
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),
                  _buildPollutantsInfo().animate().slideY(
                    begin: 0.2,
                    duration: 800.ms,
                    delay: 400.ms,
                  ),
                  const SizedBox(height: 28),
                  _buildHealthTipsCard().animate().fadeIn(
                    duration: 800.ms,
                    delay: 600.ms,
                  ),
                  const SizedBox(height: 28),
                  _buildAQIScale().animate().slideY(
                    begin: 0.2,
                    duration: 800.ms,
                    delay: 800.ms,
                  ),
                  const SizedBox(height: 28),
                  _buildWeatherInfo().animate().fadeIn(
                    duration: 800.ms,
                    delay: 1000.ms,
                  ),
                  const SizedBox(height: 28),
                  _buildForecastSection2().animate().slideY(
                    begin: 0.2,
                    duration: 800.ms,
                    delay: 1200.ms,
                  ),
                  const SizedBox(height: 28),
                  _buildForecastSection().animate().slideY(
                    begin: 0.2,
                    duration: 800.ms,
                    delay: 1200.ms,
                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
        floatingActionButton: FloatingActionButton(
          onPressed: isLoading
              ? null
              : () async {
            await fetchAQIData(); // fetch handles isLoading itself
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AQI data refreshed')),
              );
            }
          },
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          )
              : const Icon(Icons.refresh),
        )
        .animate().scale(duration: 800.ms, delay: 1400.ms),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white.withAlpha(242),
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn More'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AQIMapScreen(
                  initialPosition: _currentPosition,
                ),
              ),
            );
          }
          else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DevicesScreen()),
            );
          }
          else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EducationalScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userCity,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        Text(
          userCountry,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white70,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (_currentPosition == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.location_on),
              label: const Text('Allow location'),
            ),
          ),
      ],
    );
  }


  Widget _buildAQICard() {
    final displayedAQI = liveAQI ?? 0;
    final color = _getAQIColor(displayedAQI);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              liveAQI != null ? 'AQI: $liveAQI' : 'Fetching AQI...',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: displayedAQI / 300,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withAlpha(51),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '$displayedAQI',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 6,
                        color: color.withAlpha(128),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Air Quality is',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getAQIStatus(displayedAQI),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: color.withAlpha(102),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildAQIEmoji() {
    String emoji = _getAQIEmoji(currentAQI);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        border: Border.all(color: Colors.white.withAlpha(77)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 40)),
    );
  }


  Widget _buildPollutantsInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(77)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPollutantItem('PM2.5', '${pm25.toStringAsFixed(1)} μg/m³'),
              const SizedBox(width: 16),
              _buildPollutantItem('PM10', '${pm10.toStringAsFixed(1)} μg/m³'),
              const SizedBox(width: 16),
              _buildPollutantItem('NO₂', '${no2.toStringAsFixed(1)} μg/m³'),
              const SizedBox(width: 16),
              _buildPollutantItem('O₃', '${o3.toStringAsFixed(1)} μg/m³'),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildPollutantItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAQIScale() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(77)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AQI Scale',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildScaleItem('Good', 0, Colors.green),
                _buildScaleItem('Moderate', 50, Colors.yellow),
                _buildScaleItem('Poor', 100, Colors.orange),
                _buildScaleItem('Unhealthy', 150, Colors.red),
                _buildScaleItem('Severe', 200, Colors.purple),
                _buildScaleItem('Hazardous', 301, Colors.deepPurple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleItem(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTipsCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isHealthTipsExpanded = !isHealthTipsExpanded;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(77),),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personalized Health Tips',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedCrossFade(
                firstChild: Text(
                  '${_getHealthTips(
                    currentAQI,
                    userProfile.respiratoryCondition,
                  ).substring(0, 50)}...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                secondChild: Text(
                  _getHealthTips(currentAQI, userProfile.respiratoryCondition),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                crossFadeState: isHealthTipsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getRecommendations(
                  currentAQI,
                  userProfile.respiratoryCondition,
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(77)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Icon(
                  _getWeatherIcon(weatherCondition),
                  size: 56,
                  color: Colors.white,
                ).animate().shake(duration: 2000.ms, delay: 1000.ms),
                const SizedBox(height: 12),
                Text(
                  '${temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  weatherCondition,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
            Column(
              children: [
                _buildWeatherDetailItem(Icons.water_drop, '$humidity%'),
                _buildWeatherDetailItem(Icons.air, '${windSpeed.toStringAsFixed(1)} km/h'),
                _buildWeatherDetailItem(Icons.light_mode, 'UV N/A'), // Placeholder
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWeatherDetailItem(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.white70),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(77)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather Forecast',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            hourlyWeather.isEmpty
                ? const Center(
              child: Text(
                'Loading...',
                style: TextStyle(color: Colors.white70),
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: hourlyWeather.map((item) {
                  final isNow = item['time'] == DateTime.now().hour.toString().padLeft(2, '0');
                  return _buildForecastItem(
                    isNow ? 'Now' : item['time'],
                    item['icon'],
                    item['temp'],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildForecastItem(String time, IconData icon, String temp) {
    return Container(
      margin: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Text(
            time,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 36, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            temp,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection2() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekly AQI Forecast",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: forecastAQI.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final aqi = forecastAQI[index];
                String emoji;

                if (aqi == 1) {
                  emoji = "🌿";
                } else if (aqi == 2) emoji = "😌";
                else if (aqi == 3) emoji = "🥴";
                else if (aqi == 4) emoji = "😷";
                else emoji = "☠️";

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Day ${index + 1}",
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text("AQI: $aqi",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          buildForecastChart(), // 👈 ADD THIS FOR THE GRAPH CHART VIEW BELOW
        ],
      ),
    );
  }

  Widget buildForecastChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = ['D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7'];
                  return Text(labels[value.toInt() % 7], style: const TextStyle(color: Colors.white));
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(forecastAQI.length, (i) => FlSpot(i.toDouble(), forecastAQI[i].toDouble())),
              isCurved: true,
              color: Colors.green,
              belowBarData: BarAreaData(show: true, color: Colors.green.withAlpha(51)),
              dotData: FlDotData(show: true),
              barWidth: 3,
            ),
          ],
        ),
      ),
    );
  }





  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.deepPurple;
  }

  String _getAQIStatus(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Poor';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Severe';
    return 'Hazardous';
  }

  String _getAQIEmoji(int aqi) {
    if (aqi <= 50) return '😊👍';
    if (aqi <= 100) return '🙂';
    if (aqi <= 150) return '😷';
    if (aqi <= 200) return '😣';
    if (aqi <= 300) return '😓';
    return '😵';
  }

  String _getHealthTips(int aqi, String condition) {
    if (condition == 'Asthma' || condition == 'COPD') {
      if (aqi <= 50) {
        return 'Air quality is good, but remain cautious. Monitor for any respiratory symptoms and keep your inhaler handy.';
      } else if (aqi <= 100) {
        return 'Air quality is moderate. Sensitive individuals may experience mild symptoms. Limit prolonged outdoor activities.';
      } else if (aqi <= 150) {
        return 'Air quality is poor. You may experience respiratory discomfort. Avoid strenuous outdoor activities and use your medication as prescribed.';
      } else {
        return 'Air quality is unhealthy or worse. High risk of respiratory issues. Stay indoors and use air purifiers if possible.';
      }
    } else {
      if (aqi <= 50) {
        return 'Air quality is good and suitable for all outdoor activities.';
      } else if (aqi <= 100) {
        return 'Air quality is moderate. Generally safe, but sensitive groups may need to take precautions.';
      } else if (aqi <= 150) {
        return 'Air quality is poor. Consider reducing outdoor activities, especially if you feel discomfort.';
      } else {
        return 'Air quality is unhealthy or worse. Limit outdoor exposure and consider using a mask if you must go outside.';
      }
    }
  }

  String _getRecommendations(int aqi, String condition) {
    String baseRecommendations =
        '- Stay hydrated and avoid smoking.\n- Keep windows closed during high pollution periods.\n- Use HEPA air purifiers indoors.';
    if (condition == 'Asthma' || condition == 'COPD') {
      if (aqi <= 50) {
        return '$baseRecommendations\n- Continue regular medication and monitor symptoms closely.';
      } else if (aqi <= 100) {
        return '$baseRecommendations\n- Carry your rescue inhaler and avoid heavy exercise outdoors.';
      } else if (aqi <= 150) {
        return '$baseRecommendations\n- Consult your doctor if symptoms worsen and limit outdoor time.';
      } else {
        return '$baseRecommendations\n- Avoid outdoor activities entirely and follow your treatment plan strictly.';
      }
    } else {
      if (aqi <= 100) {
        return '$baseRecommendations\n- No special precautions needed for most people.';
      } else {
        return '$baseRecommendations\n- Consider wearing a mask during outdoor activities.';
      }
    }
  }


}


