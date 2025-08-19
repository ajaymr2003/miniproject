import 'package:flutter/material.dart';
import 'evuser_profile.dart';
import 'evuser_profile_setup.dart'; // Import the setup wizard

// Placeholder pages (replace with your real ones)
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Home Page', style: TextStyle(fontSize: 24)),
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
  const EVUserDashboard({super.key, required this.role});

  @override
  State<EVUserDashboard> createState() => _EVUserDashboardState();
}

class _EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;
  bool _needsProfileSetup = true; // Replace with your actual check

  // A list of pages to display in the body of the Scaffold
  static const List<Widget> _pages = <Widget>[
    HomePage(),
    MapPage(),
    HistoryPage(),
    // Profile is handled separately with navigation
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EVUserProfile()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onProfileSetupComplete(
    String vehicleName,
    String vehicleNumber,
    String mobileNumber,
  ) {
    setState(() {
      _needsProfileSetup = false;
    });
    // Save these details to Firestore or SharedPreferences as needed
    // ...your save logic here...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🚀 removes the back button
        title: const Text(
          'EV Smart Charge',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_needsProfileSetup)
            EVUserProfileSetup(onComplete: _onProfileSetupComplete),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
