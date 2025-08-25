import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'evuser_profile.dart'; // Assuming this file exists
import 'ev_user_setup.dart'; // Assuming this file exists

// --- CHANGE 1: HomePage is now a StatefulWidget ---
// This allows us to manage the "connected" state internally.
class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // This boolean will control what the user sees.
  bool _isConnected = false;

  @override
  Widget build(BuildContext context) {
    // --- CHANGE 2: Conditional UI ---
    // If we are not connected, show the button.
    // If we are connected, show the live data stream.
    return _isConnected ? _buildLiveStatusView() : _buildConnectView();
  }

  // This widget shows the "Connect to EV" button.
  Widget _buildConnectView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Connect to Your Vehicle', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // When the button is pressed, update the state to "connected".
              // This will trigger a rebuild and show the _buildLiveStatusView widget.
              setState(() {
                _isConnected = true;
              });
            },
            icon: const Icon(Icons.electric_car_rounded),
            label: const Text('Connect to EV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This widget uses a StreamBuilder to show live data from Firestore.
  Widget _buildLiveStatusView() {
    return StreamBuilder<DocumentSnapshot>(
      // Listen to the specific vehicle document using the user's email
      stream: FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.email) // Use the email passed from the parent widget
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'Vehicle not found.\nPlease start the simulation from the web dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final batteryLevel = data?['batteryLevel'] ?? 0;
        final isRunning = data?['isRunning'] ?? false;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isRunning ? 'Vehicle is Running' : 'Vehicle is Stopped',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isRunning ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.electric_car, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                'Battery Level',
                style: TextStyle(fontSize: 20, color: Colors.grey[600]),
              ),
              Text(
                '$batteryLevel%',
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Map Page', style: TextStyle(fontSize: 24)),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('History Page', style: TextStyle(fontSize: 24)),
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
  bool _profileCompleted = false;
  bool _setupDialogOpen = false;
  bool _profileCheckStarted = false;
  String? _email;

  // --- CHANGE 3: Use a getter for _pages ---
  // This ensures that when _email is updated, the HomePage widget is rebuilt with the new email.
  List<Widget> get _pages => [
        HomePage(email: _email ?? widget.email),
        const MapPage(),
        const HistoryPage(),
        const Center(child: Text('Profile Page Placeholder')),
      ];

  @override
  void initState() {
    super.initState();
    _initEmail();
  }

  Future<void> _initEmail() async {
    String emailToUse = widget.email;
    if (emailToUse.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      emailToUse = prefs.getString('email') ?? '';
    }
    if (mounted && _email != emailToUse) {
      setState(() {
        _email = emailToUse;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileCheckStarted) {
      _profileCheckStarted = true;
      _checkProfileCompletion();
    }
  }

  Future<void> _checkProfileCompletion() async {
    final emailToUse = _email ?? widget.email;
    if (emailToUse.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(emailToUse)
          .get();
      final data = doc.data();
      if (data != null &&
          data['brand'] != null &&
          (data['brand'] as String).isNotEmpty &&
          data['variant'] != null &&
          (data['variant'] as String).isNotEmpty) {
        if (mounted) setState(() => _profileCompleted = true);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileSetupDialog();
        });
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showProfileSetupDialog();
      });
    }
  }

  Future<void> _showProfileSetupDialog() async {
    if (_setupDialogOpen || !mounted) return;
    _setupDialogOpen = true;

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: EVUserSetup(email: _email ?? widget.email),
        ),
      ),
    );
    _setupDialogOpen = false;

    if (completed == true && mounted) {
      setState(() => _profileCompleted = true);
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EVUserProfile()),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('EV Smart Charge', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: (_email ?? widget.email).isEmpty
          ? const Center(child: Text("Loading user..."))
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}