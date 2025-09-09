import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'evuser_profile.dart';
import 'ev_user_setup.dart';
import 'widgets/nearby_stations_widget.dart';
import 'ai_recommendation_page.dart';
import '../../services/ai_recommendation_service.dart';
import 'live_map_page.dart';

// HomePage and its State class
class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isAiLoading = false;
  List<StationWithDistance> _sortedStations = [];
  late final Stream<DatabaseEvent> _vehicleStream;

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

  Future<void> _findBestStation(double batteryLevel) async {
    if (_isAiLoading) return;
    setState(() => _isAiLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.email).get();
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
      final recommendation = await aiService.getEVStationRecommendation(
        userVehicle: userVehicle,
        batteryLevel: batteryLevel,
        nearbyStations: nearbyStationsForPrompt,
      );

      if (mounted && recommendation != null) {
        final recommendedStationName = recommendation['recommendation'];
        final reason = recommendation['reason'] ?? 'The AI determined this is the best option.';
        final stationDetails = _sortedStations.firstWhere(
          (s) => s.data['name'] == recommendedStationName,
          orElse: () => _sortedStations.first,
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiRecommendationPage(
              reason: reason,
              stationDetails: stationDetails,
              email: widget.email, // Pass the email here
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
        String locationName = 'Determining location...';
        bool isRunning = false;
        bool isLowBattery = false;

        if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData &&
            snapshot.data?.snapshot.value != null) {
          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          batteryLevel = (data['batteryLevel'] as num?)?.toInt() ?? 100;
          locationName = data['locationName'] ?? 'Unknown';
          isRunning = data['isRunning'] ?? false;
          isLowBattery = batteryLevel <= 30;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Battery Status'),
              const SizedBox(height: 8),
              _buildBatteryStatus(batteryLevel, locationName),
              const SizedBox(height: 24),
              _buildLiveTrackingCard(isRunning),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.map_outlined,
                label: 'View Live Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LiveMapPage(email: widget.email)),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Nearby Stations'),
              const SizedBox(height: 16),
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
                  onPressed: _isAiLoading ? null : () => _findBestStation(batteryLevel.toDouble()),
                  icon: _isAiLoading
                      ? Container(
                          width: 24, height: 24, padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isAiLoading ? 'Analyzing...' : 'Find Best Station'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLowBattery ? Colors.red.shade600 : const Color(0xFF6777EF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
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
    return Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildBatteryStatus(int batteryLevel, String locationName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$batteryLevel%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Text('Current Location: $locationName', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLiveTrackingCard(bool isRunning) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isRunning ? "Live Tracking Enabled" : "Enable Live Tracking", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(isRunning ? "Monitoring your EV in real-time." : "Monitor your EV's battery and get alerts.", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.electric_car, size: 80, color: Colors.blueAccent.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildChargingHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Sessions', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHistoryBar('Mon', 0.8), _buildHistoryBar('Tue', 0.6), _buildHistoryBar('Wed', 0.9),
              _buildHistoryBar('Thu', 0.4), _buildHistoryBar('Fri', 0.7), _buildHistoryBar('Sat', 0.5),
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
          height: 80, width: 20,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 80 * heightFraction, width: 20,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}


class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('History Page - Coming Soon!', style: TextStyle(fontSize: 24)));
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
  const EVUserDashboard({super.key, required this.role, required this.email});

  @override
  State<EVUserDashboard> createState() => _EVUserDashboardState();
}

class _EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;
  String? _email;
  bool _isLoading = true;
  bool _setupDialogOpen = false;

  List<Widget> get _pages => [
    HomePage(email: _email!),
    const MapPlaceholderPage(),
    const HistoryPage(),
    const EVUserProfile(),
  ];

  @override
  void initState() {
    super.initState();
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(emailToUse).get();
      final data = doc.data();
      if (!doc.exists || data == null || data['brand'] == null || (data['brand'] as String).isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileSetupDialog();
        });
      }
    } catch (e) {
      print("Error checking profile completion: $e");
    }
    if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('EV Smart Charge', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications Page Coming Soon!'))),
            icon: const Icon(Icons.notifications_none, color: Colors.black),
          ),
        ],
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _email == null
              ? const Center(child: Text("Could not load user data. Please log in again."))
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
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}