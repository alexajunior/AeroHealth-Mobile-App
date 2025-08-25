
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui';
import 'package:aerohealth/views/devicesscreen.dart';
import 'package:aerohealth/views/education.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class AQIMapScreen extends StatefulWidget {
  const AQIMapScreen({super.key});

  @override
  State<AQIMapScreen> createState() => _AQIMapScreenState();
}

class _AQIMapScreenState extends State<AQIMapScreen> {
  final String _apiKey = '254a1023cb1fdfcf257a4c37a6a592e1'; // OpenWeather API
  final String _geoApiKey = 'AIzaSyCNvZqqlb8QL5nM0E4KKZ7Q5zjtwZFE5tk'; // Geocoding API

  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _gibsLayers = {
    'Aerosol': 'MODIS_Terra_Aerosol',
  };

  String _selectedLayer = 'MODIS_Terra_Aerosol';
  String _selectedType = 'aqi'; // 'aqi' or 'pm2_5'

  GoogleMapController? _mapController;
  LocationData? _userLocation;
  bool _isLoading = false;
  final Set<Marker> _aqiMarkers = {};
  final Set<TileOverlay> _tileOverlays = {};

  @override
  void initState() {
    super.initState();
    _initLocationAndAQI();
  }

  Future<void> _initLocationAndAQI() async {
    final location = Location();
    if (!await location.serviceEnabled()) {
      await location.requestService();
    }
    if (await location.hasPermission() == PermissionStatus.denied) {
      await location.requestPermission();
    }

    final loc = await location.getLocation();
    setState(() => _userLocation = loc);
    _fetchAQIMarkers(loc.latitude!, loc.longitude!);
  }

  Future<void> _fetchAQIMarkers(double lat, double lon) async {
    setState(() => _isLoading = true);
    final url = 'http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$_apiKey';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final c = data['list'][0]['components'];
        final aqi = data['list'][0]['main']['aqi'];
        final pm25 = c['pm2_5'];
        final value = _selectedType == 'aqi' ? aqi : pm25;

        final markerIcon = await _createCustomMarker(value.toString());

        setState(() {
          _aqiMarkers.clear();
          _aqiMarkers.add(
            Marker(
              markerId: MarkerId('pollutant_marker'),
              position: LatLng(lat, lon),
              icon: markerIcon,
              infoWindow: InfoWindow(
                title: _selectedType.toUpperCase(),
                snippet: _selectedType == 'aqi' ? 'Air Quality Index: $aqi' : 'PM2.5: $pm25 µg/m³',
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('AQI Fetch Error: \$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(String text) async {
    const double size = 100;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.green.shade700;

    final rect = Rect.fromLTWH(0, 0, size, size);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 40, color: Colors.white),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: size);
    final offset = Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _searchAndNavigate(String query) async {
    if (query.isEmpty) return;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$_geoApiKey',
    );

    try {
      final res = await http.get(url);
      debugPrint('Search response: ${res.body}');

      final data = json.decode(res.body);

      if (data['status'] == 'OK') {
        final loc = data['results'][0]['geometry']['location'];
        final latLng = LatLng(loc['lat'], loc['lng']);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 12),
        );

        _fetchAQIMarkers(latLng.latitude, latLng.longitude);
      } else {
        debugPrint('Geocoding API Error: ${data['status']}');
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }


  TileOverlay _buildGIBSTileOverlay() {
    return TileOverlay(
      tileOverlayId: TileOverlayId(_selectedLayer),
      tileProvider: _GIBSTileProvider(layerId: _selectedLayer),
      transparency: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _userLocation != null
        ? LatLng(_userLocation!.latitude!, _userLocation!.longitude!)
        : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.black.withAlpha(170),
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _selectedLayer,
            dropdownColor: Colors.grey[900],
            icon: const Icon(Icons.layers, color: Colors.white),
            underline: const SizedBox(),
            items: _gibsLayers.entries.map((entry) => DropdownMenuItem(
              value: entry.value,
              child: Text(entry.key, style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (val) {
              setState(() => _selectedLayer = val!);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _tileOverlays.clear();
                    _tileOverlays.add(_buildGIBSTileOverlay());
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 10),
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() => _tileOverlays.add(_buildGIBSTileOverlay()));
                }
              });
            },
            minMaxZoomPreference: const MinMaxZoomPreference(4, 16),
            markers: _aqiMarkers,
            tileOverlays: _tileOverlays,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            top: kToolbarHeight + 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _searchAndNavigate,
                decoration: const InputDecoration(
                  hintText: 'Search location',
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),
          SizedBox(
            child: Positioned(
              right: 100,
              top: 10,
              child: Material(
                color: Colors.black.withAlpha(102),
                borderRadius: BorderRadius.circular(12),
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: Colors.blue,
                  isSelected: [_selectedType == 'aqi', _selectedType == 'pm2_5'],
                  onPressed: (index) {
                    setState(() {
                      _selectedType = index == 0 ? 'aqi' : 'pm2_5';
                      if (_userLocation != null) {
                        _fetchAQIMarkers(_userLocation!.latitude!, _userLocation!.longitude!);
                      }
                    });
                  },
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('AQI')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('PM2.5')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AQIMapScreen()),
            );
          }
          else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DevicesScreen()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EducationalScreen()),
            );
          } else if (index != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${['Devices', 'Buy', 'Ranking'][index - 2]} coming soon!',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _GIBSTileProvider extends TileProvider {
  final String layerId;

  _GIBSTileProvider({required this.layerId});

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    try {
      final bbox = _calculateBoundingBox(x, y, zoom!);
      final url =
          'https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0'
          '&LAYERS=$layerId&FORMAT=image/png&CRS=EPSG:3857&BBOX=$bbox&WIDTH=256&HEIGHT=256'
          '&TIME=2024-06-15&TRANSPARENT=true';

      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200
          ? Tile(256, 256, response.bodyBytes)
          : Tile(256, 256, Uint8List(0));
    } catch (_) {
      return Tile(256, 256, Uint8List(0));
    }
  }

  String _calculateBoundingBox(int x, int y, int zoom) {
    final n = math.pow(2.0, zoom);
    final lonLeft = x / n * 360.0 - 180.0;
    final lonRight = (x + 1) / n * 360.0 - 180.0;
    final latTop = _tile2lat(y, zoom);
    final latBottom = _tile2lat(y + 1, zoom);
    return '${_lon2merc(lonLeft)},${_lat2merc(latBottom)},${_lon2merc(lonRight)},${_lat2merc(latTop)}';
  }

  double _tile2lat(int y, int z) {
    final n = math.pow(2.0, z);
    final exp = math.exp(math.pi * (1 - 2 * y / n));
    final sinh = (exp - 1 / exp) / 2;
    final latRad = math.atan(sinh);
    return latRad * 180.0 / math.pi;
  }

  double _lon2merc(double lon) => lon * 20037508.34 / 180.0;

  double _lat2merc(double lat) {
    final rad = lat * math.pi / 180.0;
    return math.log(math.tan(math.pi / 4 + rad / 2)) * 20037508.34 / math.pi;
  }
}
