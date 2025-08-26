import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'evuser_profile.dart';
import 'ev_user_setup.dart';

// HomePage remains the same
class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final vehicleRtdbRef = FirebaseDatabase.instance
        .ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

    return StreamBuilder<DatabaseEvent>(
      stream: vehicleRtdbRef.onValue,
      builder: (context, snapshot) {
        int batteryLevel = 78;
        String locationName = 'JP Nagar, Bengaluru';
        bool isRunning = false;

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data =
              Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          batteryLevel = data['batteryLevel'] ?? 78;
          locationName = data['locationName'] ?? 'JP Nagar, Bengaluru';
          isRunning = data['isRunning'] ?? false;
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

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
          Icon(Icons.electric_car,
              size: 80, color: Colors.blueAccent.withOpacity(0.7)),
        ],
      ),
    );
  }

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

// MapPage and HistoryPage placeholders remain the same
class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Map Page - Coming Soon!', style: TextStyle(fontSize: 24)),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('History Page - Coming Soon!', style: TextStyle(fontSize: 24)),
    );
  }
}


// =========================================================================
// --- MODIFIED: The main dashboard state logic is refactored ---
// =========================================================================

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
  bool _isLoading = true; // Added loading state for better UX
  bool _setupDialogOpen = false;

  List<Widget> get _pages => [
        // Pass the guaranteed non-null email to HomePage
        HomePage(email: _email!),
        const MapPage(),
        const HistoryPage(),
        const EVUserProfile(),
      ];

  @override
  void initState() {
    super.initState();
    // This is the single entry point for our check.
    _initializeAndCheckProfile();
  }
  
  // This new function handles the entire sequence: get email, check profile.
  Future<void> _initializeAndCheckProfile() async {
    // 1. Determine the correct email to use
    String emailToUse = widget.email;
    if (emailToUse.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      emailToUse = prefs.getString('email') ?? '';
    }

    // 2. If no email can be found, stop loading and show an error state
    if (emailToUse.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _email = null; // Ensure email is null to show error
        });
      }
      return;
    }
    
    // 3. Set the email for the widget state
    if(mounted) {
      setState(() {
        _email = emailToUse;
      });
    }

    // 4. Check if the user's vehicle setup is complete in Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(emailToUse)
          .get();

      final data = doc.data();
      // If the document doesn't exist, or 'brand' is missing, user needs setup.
      if (!doc.exists || data == null || data['brand'] == null || (data['brand'] as String).isEmpty) {
        // Use a post-frame callback to safely show the dialog AFTER the first frame is built.
        // This prevents errors related to showing dialogs during a build phase.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileSetupDialog();
        });
      }
    } catch (e) {
      print("Error checking profile completion: $e");
      // Optionally show a SnackBar to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking profile: ${e.toString()}")),
        );
      }
    }
    
    // 5. Once all checks are done, stop loading and build the main UI
    if(mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // This function is now only responsible for showing the dialog
  Future<void> _showProfileSetupDialog() async {
    if (_setupDialogOpen || !mounted) return;
    _setupDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // User MUST complete the setup
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
    setState(() => _selectedIndex = index);
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications Page Coming Soon!')),
              );
            },
            icon: const Icon(Icons.notifications_none, color: Colors.black),
          ),
        ],
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
      ),
      // Use the loading state to provide clear user feedback
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _email == null
              ? const Center(child: Text("Could not load user data. Please log in again."))
              : IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
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