import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'evuser_profile.dart';
import 'ev_user_setup.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Home Page', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting to EV...')),
              );
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
  String? _email; // <-- Add this

  final List<Widget> _pages = const [
    HomePage(),
    MapPage(),
    HistoryPage(),
    // The Profile tab navigates to EVUserProfile, so we can use a placeholder here
    Center(child: Text('Profile Page', style: TextStyle(fontSize: 24))),
  ];

  @override
  void initState() {
    super.initState();
    _initEmail(); // <-- Add this
  }

  Future<void> _initEmail() async {
    // If widget.email is empty, get from SharedPreferences
    if (widget.email.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email') ?? '';
      setState(() {
        _email = savedEmail;
      });
    } else {
      _email = widget.email;
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
    if (emailToUse.isEmpty) {
      // Try to get from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email') ?? '';
      if (savedEmail.isEmpty) return;
      setState(() {
        _email = savedEmail;
      });
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_email ?? widget.email)
          .get();
      final data = doc.data();
      if (data != null &&
          data['brand'] != null &&
          data['variant'] != null &&
          (data['brand'] is String) &&
          (data['variant'] is String) &&
          (data['brand'] as String).isNotEmpty &&
          (data['variant'] as String).isNotEmpty) {
        if (mounted) {
          setState(() {
            _profileCompleted = true;
          });
        }
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
    if (_setupDialogOpen) return;
    _setupDialogOpen = true;

    // Defer dialog opening until after build phase
    await Future.delayed(Duration.zero);

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: EVUserSetup(
              email: widget.email,
            ), // pass email as document ID
          ),
        );
      },
    );
    _setupDialogOpen = false;

    if (completed == true && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _profileCompleted = true;
          });
        }
      });
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
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleUserInteraction([_]) {
    _checkProfileCompletion();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _handleUserInteraction,
      onPanDown: _handleUserInteraction,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'EV Smart Charge',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            _handleUserInteraction();
            _onItemTapped(index);
          },
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
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
      ),
    );
  }
}
