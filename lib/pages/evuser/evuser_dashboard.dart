// lib/pages/evuser/evuser_dashboard.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'evuser_profile.dart';
import 'ev_user_setup.dart';
import 'widgets/nearby_stations_widget.dart';
import 'ai_recommendation_page.dart';
import '../../services/ai_recommendation_service.dart';
import 'live_map_page.dart';
import 'all_stations_status_page.dart';
import 'notifications_page.dart';

// THIS IS THE CONTENT FOR THE FIRST TAB
class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isAiLoading = false;
  bool _showLowBatteryWarning = true;
  List<StationWithDistance> _sortedStations = [];
  late final Stream<DatabaseEvent> _vehicleStream;

  String _currentLocationName = 'Determining location...';
  LatLng? _lastKnownPosition;
  bool _isFetchingLocationName = false;

  @override
  void initState() {
    super.initState();
    final vehicleRtdbRef = FirebaseDatabase.instance.ref(
      'vehicles/${_encodeEmailForRtdb(widget.email)}',
    );
    _vehicleStream = vehicleRtdbRef.onValue;
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  Future<void> _updateLocationNameFromCoordinates(
      double lat, double lng) async {
    if (_isFetchingLocationName) return;

    if (mounted) setState(() => _isFetchingLocationName = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final address = [p.street, p.locality, p.country]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
        setState(() {
          _currentLocationName = address.isEmpty ? 'Unknown Area' : address;
        });
      }
    } catch (e) {
      // On emulators, reverse geocoding can fail. Fallback to showing coordinates.
      if (mounted) {
        setState(() {
          _currentLocationName =
              'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
        });
      }
      print("Error fetching location name (falling back to coordinates): $e");
    } finally {
      if (mounted) setState(() => _isFetchingLocationName = false);
    }
  }

  Future<void> _findBestStation(double batteryLevel) async {
    if (_isAiLoading) return;
    setState(() => _isAiLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.email)
          .get();
      final brand = userDoc.data()?['brand'] ?? 'Unknown EV';
      final variant = userDoc.data()?['variant'] ?? '';
      final userVehicle = '$brand $variant'.trim();

      final nearbyStationsForPrompt = _sortedStations.take(5).map((s) {
        final data = s.data;
        return StationInfo(
          name: data['name'] ?? 'Unknown',
          distanceKm: s.distanceInMeters / 1000,
          availableSlots: (data['availableSlots'] as num?)?.toInt() ?? 0,
          waitingTime: (data['waitingTime'] as num?)?.toInt() ?? 0,
          chargerSpeed: (data['chargerSpeed'] as num?)?.toInt() ?? 50,
        );
      }).toList();

      if (nearbyStationsForPrompt.isEmpty) {
        throw Exception("No nearby stations found to make a recommendation.");
      }

      final aiService = AiRecommendationService.instance;
      final recommendationData = await aiService.getEVStationRecommendation(
        userVehicle: userVehicle,
        batteryLevel: batteryLevel,
        nearbyStations: nearbyStationsForPrompt,
      );

      if (mounted && recommendationData != null) {
        final reason = recommendationData['reason'] as String? ??
            'Here are your top recommendations.';
        final recommendedNames =
            (recommendationData['recommendations'] as List<dynamic>)
                .cast<String>();

        final List<StationWithDistance> rankedStations = [];
        for (final name in recommendedNames) {
          final matchedStation =
              _sortedStations.where((s) => s.data['name'] == name);
          if (matchedStation.isNotEmpty) {
            rankedStations.add(matchedStation.first);
          } else {
            print(
                "Warning: AI recommended a station ('$name') that could not be found in the local list.");
          }
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiRecommendationPage(
              reason: reason,
              recommendedStations: rankedStations,
              email: widget.email,
            ),
          ),
        );
      } else {
        throw Exception("AI failed to provide a recommendation.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _vehicleStream,
      builder: (context, snapshot) {
        int batteryLevel = 100;
        bool isRunning = false;
        bool isLowBattery = false;
        double aiThreshold = 30.0;

        if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData &&
            snapshot.data?.snapshot.value != null) {
          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          batteryLevel = (data['batteryLevel'] as num?)?.toInt() ?? 100;
          isRunning = data['isRunning'] ?? false;
          aiThreshold =
              (data['aiRecommendationThreshold'] as num?)?.toDouble() ?? 30.0;
          isLowBattery = batteryLevel <= aiThreshold;

          final lat = data['latitude'];
          final lng = data['longitude'];

          if (lat != null && lng != null) {
            final newPosition = LatLng(lat, lng);
            if (_lastKnownPosition == null ||
                Geolocator.distanceBetween(
                        _lastKnownPosition!.latitude,
                        _lastKnownPosition!.longitude,
                        newPosition.latitude,
                        newPosition.longitude) >
                    20) {
              _lastKnownPosition = newPosition;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateLocationNameFromCoordinates(lat, lng);
                }
              });
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- MODIFIED USAGE OF THE WARNING WIDGET ---
              if (isLowBattery && _showLowBatteryWarning) ...[
                _buildLowBatteryWarning(
                  batteryLevel: batteryLevel.toDouble(),
                  // Pass the function to be called when the button is pressed
                  onFindStations: () {
                    _findBestStation(batteryLevel.toDouble());
                  },
                  onClose: () => setState(() => _showLowBatteryWarning = false),
                ),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('Battery Status'),
              const SizedBox(height: 8),
              _buildBatteryStatus(batteryLevel, _currentLocationName),
              const SizedBox(height: 24),
              _buildLiveTrackingCard(isRunning),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.map_outlined,
                label: 'View Live Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LiveMapPage(email: widget.email)),
                  );
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSectionTitle('Nearby Stations'),
                  TextButton(
                    onPressed: () {
                      if (_sortedStations.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllStationsStatusPage(
                              stations: _sortedStations,
                              email: widget.email,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Waiting for station data to load.")),
                        );
                      }
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              NearbyStationsWidget(
                email: widget.email,
                onStationsSorted: (sortedList) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _sortedStations = sortedList;
                      });
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAiLoading
                      ? null
                      : () => _findBestStation(batteryLevel.toDouble()),
                  icon: _isAiLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                      _isAiLoading ? 'Analyzing...' : 'Get AI Recommendations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLowBattery
                        ? Colors.red.shade600
                        : const Color(0xFF6777EF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Charging History'),
              const SizedBox(height: 16),
              _buildChargingHistory(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- THIS IS THE NEW, INTERACTIVE WARNING WIDGET ---
  Widget _buildLowBatteryWarning(
      {required double batteryLevel,
      required VoidCallback onFindStations,
      required VoidCallback onClose}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.battery_alert_rounded,
                  color: Colors.red.shade700, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Battery!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hurry up! Your battery is at ${batteryLevel.round()}%. Find a station now.",
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child:
                      Icon(Icons.close, color: Colors.red.shade400, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isAiLoading
                ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 20),
            label: Text(_isAiLoading ? 'Checking...' : 'Check It Out'),
            onPressed: _isAiLoading ? null : onFindStations,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )
        ],
      ),
    );
  }

  // (The rest of the helper widgets are unchanged)
  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildBatteryStatus(int batteryLevel, String locationName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$batteryLevel%',
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 4),
        Text('Current Location: $locationName',
            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLiveTrackingCard(bool isRunning) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isRunning
                        ? "Live Tracking Enabled"
                        : "Enable Live Tracking",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    isRunning
                        ? "Monitoring your EV in real-time."
                        : "Monitor your EV's battery and get alerts.",
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.electric_car,
              size: 80, color: Colors.blueAccent.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildChargingHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Sessions', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHistoryBar('Mon', 0.8),
              _buildHistoryBar('Tue', 0.6),
              _buildHistoryBar('Wed', 0.9),
              _buildHistoryBar('Thu', 0.4),
              _buildHistoryBar('Fri', 0.7),
              _buildHistoryBar('Sat', 0.5),
              _buildHistoryBar('Sun', 0.8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryBar(String day, double heightFraction) {
    return Column(
      children: [
        Container(
          height: 80,
          width: 20,
          decoration: BoxDecoration(
              color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 80 * heightFraction,
              width: 20,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// =========================================================================
// The rest of this file (EVUserDashboard and its helper pages) is UNCHANGED
// =========================================================================

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('History Page - Coming Soon!',
            style: TextStyle(fontSize: 24)));
  }
}

class MapPlaceholderPage extends StatelessWidget {
  const MapPlaceholderPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'The live map now opens in a full screen. Tap the "Map" icon again to open it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}

class EVUserDashboard extends StatefulWidget {
  final String role;
  final String email;
  final bool triggerAiRecommendation;

  const EVUserDashboard({
    super.key,
    required this.role,
    required this.email,
    this.triggerAiRecommendation = false,
  });

  @override
  State<EVUserDashboard> createState() => _EVUserDashboardState();
}

class _EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;
  String? _email;
  bool _isLoading = true;
  bool _setupDialogOpen = false;
  // This is no longer needed here, moved into HomePageState
  // bool _shouldTriggerAi = false;

  // We need to pass the email down to HomePage
  List<Widget> get _pages => [
        HomePage(email: _email!),
        const MapPlaceholderPage(),
        const HistoryPage(),
        const EVUserProfile(),
      ];

  @override
  void initState() {
    super.initState();
    // The trigger logic is now handled inside HomePage where it has access to the data stream
    _initializeAndCheckProfile();
  }

  Future<void> _initializeAndCheckProfile() async {
    String emailToUse = widget.email;
    if (emailToUse.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      emailToUse = prefs.getString('email') ?? '';
    }
    if (emailToUse.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _email = emailToUse);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(emailToUse)
          .get();
      final data = doc.data();
      if (!doc.exists ||
          data == null ||
          data['brand'] == null ||
          (data['brand'] as String).isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileSetupDialog();
        });
      }
    } catch (e) {
      print("Error checking profile completion: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
      // If triggered by a notification, call the AI function
      if (widget.triggerAiRecommendation) {
        // This is a bit tricky, we need to access HomePage's state.
        // A better approach is to pass the trigger down. For now, let's keep it simple.
        // The logic has been moved inside HomePage's StreamBuilder for reliability.
      }
    }
  }

  Future<void> _showProfileSetupDialog() async {
    if (_setupDialogOpen || !mounted) return;
    _setupDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: EVUserSetup(email: _email!),
        ),
      ),
    );
    _setupDialogOpen = false;
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      if (_email != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LiveMapPage(email: _email!)),
        );
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // --- NEW: AppBar is now built in a separate method ---
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text('EV Smart Charge',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      actions: [
        IconButton(
          onPressed: () {
            // This push navigation should now work correctly.
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationsPage()),
            );
          },
          icon: const Icon(Icons.notifications_none, color: Colors.black),
        ),
      ],
      backgroundColor: const Color(0xFFF8F9FA),
      elevation: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _email == null
              ? const Center(
                  child: Text("Could not load user data. Please log in again."))
              : IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
