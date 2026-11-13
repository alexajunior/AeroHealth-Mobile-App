import 'package:aerohealth/views/devicesscreen.dart';
import 'package:aerohealth/views/map.dart';
import 'package:aerohealth/views/dashboard.dart';
import 'package:flutter/material.dart';

class EducationalScreen extends StatefulWidget {
  const EducationalScreen({super.key});

  @override
  State<EducationalScreen> createState() => _EducationalScreenState();
}

class _EducationalScreenState extends State<EducationalScreen> {
  final List<String> facts = const [
    "🌿 Trees act as natural air filters by absorbing pollutants.",
    "😷 Wearing masks during high AQI days reduces inhalation of harmful particles.",
    "🏠 Indoor plants like Spider Plant & Peace Lily help improve indoor air quality.",
    "🔥 Burning trash or leaves contributes to local air pollution.",
    "💨 Vehicles are a major source of air pollution in urban areas.",
    "🚴‍♂️ Biking or walking instead of driving helps reduce air pollution.",
    "📱 Checking AQI daily can help you plan outdoor activities better.",
  ];

  final List<String> funFacts = const [
    "🧠 Trees can reduce neighborhood temperatures by up to 8°F.",
    "🧪 Peace Lilies remove up to 60% of air pollutants indoors.",
    "🌍 Using public transport significantly reduces your carbon footprint.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        title: const Text(
          'Air Quality Insights',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFunFacts(),
          const SizedBox(height: 10),
          Expanded(child: _buildFactsList()),
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
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AQIMapScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DevicesScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EducationalScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildFunFacts() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFD2E3FC),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fun Facts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 20),
          ...funFacts.map(
                (fact) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "• $fact",
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactsList() {
    return ListView.separated(
      itemCount: facts.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 25),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: const Icon(Icons.eco, color: Color(0xFF388E3C)),
            title: Text(
              facts[index],
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}