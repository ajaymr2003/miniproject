import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'evuser_profile.dart';
import 'ev_user_setup.dart';

/// HomePage is the main view for the 'Home' tab, redesigned to match the UI.
class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Helper to encode email for RTDB path
  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final vehicleRtdbRef = FirebaseDatabase.instance
        .ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

    // The main UI is built using a StreamBuilder to get live data
    return StreamBuilder<DatabaseEvent>(
      stream: vehicleRtdbRef.onValue,
      builder: (context, snapshot) {
        // Provide default values for a clean initial render
        int batteryLevel = 78;
        String locationName = 'JP Nagar, Bengaluru';
        bool isRunning = false;

        // Once data arrives from Firebase, update the variables
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data =
              Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          batteryLevel = data['batteryLevel'] ?? 78;
          locationName = data['locationName'] ?? 'JP Nagar, Bengaluru';
          isRunning = data['isRunning'] ?? false;
        }

        // The main scrollable layout
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
              const SizedBox(height: 32),
              _buildSectionTitle('Nearby Stations'),
              const SizedBox(height: 16),
              _buildNearbyStations(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature coming soon!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6777EF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Find Best Station'),
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

  // Helper widget for section titles
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  // Widget for the Battery Status section
  Widget _buildBatteryStatus(int batteryLevel, String locationName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$batteryLevel%',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Current Location: $locationName',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Widget for the "Enable Live Tracking" card
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
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRunning ? "Live Tracking Enabled" : "Enable Live Tracking",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isRunning
                      ? "Monitoring your EV in real-time."
                      : "Monitor your EV's battery in real-time and get alerts.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // Only show the "Enable" button if simulation is not running
                if (!isRunning)
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Start simulation from the web dashboard to enable.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Enable'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // NOTE: If you have a car image, place it in an 'assets' folder
          // and replace this Icon with: Image.asset('assets/car.png', height: 60)
          Icon(Icons.electric_car,
              size: 80, color: Colors.blueAccent.withOpacity(0.7)),
        ],
      ),
    );
  }

  // Widget for Nearby Stations (Placeholder)
  Widget _buildNearbyStations() {
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildStationCard('ChargePoint - Downtown', '0.5 mi, 3 slots',
              const Color(0xFF4A6B61)),
          _buildStationCard(
              'EVgo - City Center', '1.2 mi, 2 slots', const Color(0xFF569EA2)),
          _buildStationCard(
              'Electrify Mall', '2.1 mi', const Color(0xFF4CB8B0)),
        ],
      ),
    );
  }

  // Helper for a single station card
  Widget _buildStationCard(String name, String details, Color color) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Feature coming soon!'))),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.ev_station, color: Colors.white, size: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(details,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget for Charging History (Placeholder)
  Widget _buildChargingHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Sessions: 3',
            style: TextStyle(color: Colors.grey),
          ),
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

  // Helper for a single history bar
  Widget _buildHistoryBar(String day, double heightFraction) {
    return Column(
      children: [
        Container(
          height: 80,
          width: 20,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 80 * heightFraction,
              width: 20,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// MapPage placeholder
class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Map Page - Coming Soon!', style: TextStyle(fontSize: 24)),
    );
  }
}

// HistoryPage placeholder
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('History Page - Coming Soon!', style: TextStyle(fontSize: 24)),
    );
  }
}

/// EVUserDashboard is the main Scaffold that holds the BottomNavigationBar.
class EVUserDashboard extends StatefulWidget {
  final String role;
  final String email;
  const EVUserDashboard({super.key, required this.role, required this.email});

  @override
  State<EVUserDashboard> createState() => _EVUserDashboardState();
}

class _EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;
  bool _setupDialogOpen = false;
  String? _email;

  List<Widget> get _pages => [
        HomePage(email: _email ?? widget.email),
        const MapPage(),
        const HistoryPage(),
        const EVUserProfile(), // Navigate to profile directly
      ];

  @override
  void initState() {
    super.initState();
    _initEmailAndCheckProfile();
  }

  Future<void> _initEmailAndCheckProfile() async {
    String emailToUse = widget.email;
    if (emailToUse.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      emailToUse = prefs.getString('email') ?? '';
    }
    if (mounted) {
      setState(() {
        _email = emailToUse;
      });
      _checkProfileCompletion();
    }
  }

  Future<void> _checkProfileCompletion() async {
    final emailToUse = _email;
    if (emailToUse == null || emailToUse.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(emailToUse)
          .get();
      final data = doc.data();
      if (data == null ||
          data['brand'] == null ||
          (data['brand'] as String).isEmpty) {
        // Use a post-frame callback to safely show the dialog after the build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileSetupDialog();
        });
      }
    } catch (e) {
      // Handle error if necessary
    }
  }

  Future<void> _showProfileSetupDialog() async {
    if (_setupDialogOpen || !mounted) return;
    _setupDialogOpen = true;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: EVUserSetup(email: _email ?? widget.email),
        ),
      ),
    );
    _setupDialogOpen = false;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('EV Smart Charge',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications Page Coming Soon!')),
              );
            },
            icon: const Icon(Icons.notifications_none, color: Colors.black),
          ),
        ],
        backgroundColor:
            const Color(0xFFF8F9FA), // Match body background color
        elevation: 0,
      ),
      body: (_email ?? widget.email).isEmpty
          ? const Center(child: Text("Loading user..."))
          : IndexedStack( // Use IndexedStack to keep page state
              index: _selectedIndex,
              children: _pages,
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black, // Active icon color
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed, // Important for more than 3 items
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