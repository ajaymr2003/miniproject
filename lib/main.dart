import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EVCarSimulatorApp());
}

class EVCarSimulatorApp extends StatelessWidget {
  const EVCarSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Car Simulator',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const EVCarSimulatorPage(),
    );
  }
}

class EVCarSimulatorPage extends StatefulWidget {
  const EVCarSimulatorPage({super.key});

  @override
  State<EVCarSimulatorPage> createState() => _EVCarSimulatorPageState();
}

class _EVCarSimulatorPageState extends State<EVCarSimulatorPage> {
  // Mock data for charging stations.
  final List<Map<String, dynamic>> _chargingStations = [
    {
      "name": "EcoCharge Hub",
      "distance": "2.5 miles",
      "ports": [
        {"id": "A1", "type": "Level 2", "status": "available"},
        {"id": "A2", "type": "DC Fast", "status": "in use"},
        {"id": "A3", "type": "Level 2", "status": "out of service"}
      ]
    },
    {
      "name": "Future Fuel Station",
      "distance": "5.1 miles",
      "ports": [
        {"id": "B1", "type": "Level 2", "status": "available"},
        {"id": "B2", "type": "DC Fast", "status": "available"}
      ]
    }
  ];

  // State variables for the simulation.
  double _batteryLevel = 100.0;
  bool _isSimulationRunning = false;
  bool _hasAlerted = false;
  static const double _lowBatteryThreshold = 30.0;
  
  // Timer for the simulation loop.
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Initialize the ticker for our simulation loop.
    _ticker = Ticker(_onTick);
  }

  // The function called on every tick of the ticker.
  void _onTick(Duration elapsed) {
    if (_isSimulationRunning && _batteryLevel > 0) {
      setState(() {
        const double drainRatePerSecond = 2.0; // 2% per second.
        _batteryLevel -= drainRatePerSecond * elapsed.inMilliseconds / 1000.0;

        if (_batteryLevel < 0) {
          _batteryLevel = 0;
        }

        // Check for low battery alert.
        if (_batteryLevel <= _lowBatteryThreshold && !_hasAlerted) {
          _hasAlerted = true;
          _showMessage("Warning: Low Battery! Find a charging station now.");
        }

        // Stop the simulation when battery is empty.
        if (_batteryLevel <= 0) {
          _stopSimulation();
          _showMessage("Battery is completely drained. Simulation stopped.");
        }
      });
    }
  }

  // Starts the simulation.
  void _startSimulation() {
    if (_batteryLevel <= 0) {
      _resetSimulation();
    }
    setState(() {
      _isSimulationRunning = true;
    });
    _ticker.start();
    _showMessage("Simulation started!");
  }

  // Stops the simulation.
  void _stopSimulation() {
    setState(() {
      _isSimulationRunning = false;
    });
    _ticker.stop();
    _showMessage("Simulation stopped.");
  }

  // Resets the simulation to its initial state.
  void _resetSimulation() {
    setState(() {
      _batteryLevel = 100.0;
      _isSimulationRunning = false;
      _hasAlerted = false;
      _ticker.stop();
    });
  }

  // Displays a snackbar message.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper function to get the color for the battery bar based on the level.
  Color _getBatteryColor(double level) {
    if (level > 50) {
      return Colors.green.shade500;
    } else if (level > _lowBatteryThreshold) {
      return Colors.yellow.shade400;
    } else {
      return Colors.red.shade500;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLowBattery = _batteryLevel <= _lowBatteryThreshold;
    final String buttonText = _batteryLevel <= 0
        ? 'Restart Simulation'
        : _isSimulationRunning
            ? 'Stop Simulation'
            : 'Start Simulation';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    const Text(
                      'EV Car Simulator',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Watch the battery drain and get an alert for nearby charging stations.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Battery Status Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.battery_charging_full, size: 60, color: Colors.grey.shade700),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Stack(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: _batteryLevel, end: _batteryLevel),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return LinearProgressIndicator(
                                      value: value / 100,
                                      minHeight: 40,
                                      backgroundColor: Colors.grey.shade200,
                                      color: _getBatteryColor(value),
                                      borderRadius: BorderRadius.circular(20),
                                    );
                                  },
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Text(
                                      '${_batteryLevel.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Low Battery Alert Section
                    if (isLowBattery && _hasAlerted)
                      Card(
                        color: Colors.red.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Warning: Low Battery!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You have less than 30% battery remaining. Find a charging station now!',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nearby Charging Stations',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: _chargingStations.map((station) {
                                  return Card(
                                    color: Colors.grey.shade50,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            station['name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text('Distance: ${station['distance']}'),
                                          const SizedBox(height: 8),
                                          ...station['ports'].map<Widget>((port) {
                                            Color portColor = port['status'] == 'available'
                                                ? Colors.green
                                                : port['status'] == 'in use'
                                                    ? Colors.yellow.shade700
                                                    : Colors.red;
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.circle, size: 12, color: portColor),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Port ${port['id']} (${port['type']}) - ${port['status']}',
                                                    style: TextStyle(color: portColor, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Controls Section
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSimulationRunning ? _stopSimulation : _startSimulation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSimulationRunning ? Colors.red.shade600 : Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
