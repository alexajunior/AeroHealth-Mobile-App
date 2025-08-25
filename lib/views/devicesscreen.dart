import 'package:aerohealth/views/education.dart';
import 'package:aerohealth/views/map.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final List<IoTDevice> mockDevices = [
    IoTDevice(name: 'Living Room Sensor', id: 'device_001'),
    IoTDevice(name: 'Bedroom Sensor', id: 'device_002'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: mockDevices.isEmpty
          ? const Center(child: Text("No devices added yet."))
          : ListView.builder(
        itemCount: mockDevices.length,
        itemBuilder: (context, index) {
          final device = mockDevices[index];
          return DeviceCard(device: device);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
          );

          if (result != null && mounted) {
            setState(() {
              mockDevices.add(
                IoTDevice(name: result['name'], id: result['id']),
              );
            });
          }
        },
        tooltip: 'Add Device',
        child: const Icon(Icons.add),
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

class IoTDevice {
  final String name;
  final String id;
  IoTDevice({required this.name, required this.id});
}

class DeviceCard extends StatelessWidget {
  final IoTDevice device;
  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final random = Random();
    final pm25 = 10 + random.nextInt(90);
    final co2 = 350 + random.nextInt(500);
    final temp = 20 + random.nextDouble() * 10;
    final humidity = 40 + random.nextInt(40);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("PM2.5: $pm25 µg/m³"),
            Text("CO₂: $co2 ppm"),
            Text("Temp: ${temp.toStringAsFixed(1)} °C"),
            Text("Humidity: $humidity%"),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Updated just now', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register AQI Device')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Device Name'),
                validator: (val) => val!.isEmpty ? 'Enter device name' : null,
              ),
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Device ID'),
                validator: (val) => val!.isEmpty ? 'Enter device ID' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'name': _nameController.text,
                      'id': _idController.text,
                    });
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Add Device'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
