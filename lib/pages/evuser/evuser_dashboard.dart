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
import '../../services/notification_service.dart';
import 'live_map_page.dart';
import 'nearby_stations_page.dart'; 
import 'notifications_page.dart';

// --- NEW: Enum to manage the battery trend state ---
enum BatteryTrend { stable, charging, draining }

class HomePage extends StatefulWidget {
  final String email;
  final bool shouldTriggerAi;
  final VoidCallback onAiTriggered;
  final GlobalKey<NavigatorState> navigatorKey;

  const HomePage({
    super.key,
    required this.email,
    required this.shouldTriggerAi,
    required this.onAiTriggered,
    required this.navigatorKey,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _isAiLoading = false;
  bool _showLowBatteryWarning = true;
  List<StationWithDistance> _sortedStations = [];
  late final Stream<DatabaseEvent> _vehicleStream;
  bool _aiTriggerConsumed = false;
  int _previousBatteryLevel = 101;
  String _currentLocationName = 'Determining location...';
  LatLng? _lastKnownPosition;
  bool _isFetchingLocationName = false;
  
  // --- NEW: State variable to hold the persistent trend ---
  BatteryTrend _batteryTrend = BatteryTrend.stable;


  @override
  void initState() {
    super.initState();
    final vehicleRtdbRef = FirebaseDatabase.instance.ref(
      'vehicles/${_encodeEmailForRtdb(widget.email)}',
    );
    _vehicleStream = vehicleRtdbRef.onValue;
  }
  
  void findBestStationPublic(double batteryLevel) {
    _findBestStation(batteryLevel);
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
      if (mounted) {
        setState(() {
          _currentLocationName =
              'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
        });
      }
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

      await _refreshSortedStations();

      final nearbyStations = _sortedStations.take(5).toList();
      if (nearbyStations.isEmpty) {
        throw Exception("No nearby stations found to make a recommendation.");
      }

      final aiService = AiRecommendationService.instance;
      final recommendationData = await aiService.getEVStationRecommendation(
        userVehicle: userVehicle,
        batteryLevel: batteryLevel,
        nearbyStations: nearbyStations,
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
          }
        }

        await widget.navigatorKey.currentState?.push(
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

  Future<void> _refreshSortedStations() async {
    final vehicleSnapshot = await FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}').get();
    if (!vehicleSnapshot.exists || !mounted) return;
    final vehicleData = Map<String, dynamic>.from(vehicleSnapshot.value as Map);
    final userLat = vehicleData['latitude'];
    final userLng = vehicleData['longitude'];
    if (userLat == null || userLng == null) return;
    final stationsSnapshot = await FirebaseFirestore.instance.collection('stations').where('isActive', isEqualTo: true).get();
    final allStations = stationsSnapshot.docs;
    List<StationWithDistance> stationsWithDistances = [];
    for (var stationDoc in allStations) {
        final data = stationDoc.data();
        final stationLat = data['latitude'];
        final stationLng = data['longitude'];
        if (stationLat != null && stationLng != null) {
            final distance = Geolocator.distanceBetween(userLat, userLng, stationLat, stationLng);
            stationsWithDistances.add(StationWithDistance(stationDoc: stationDoc, distanceInMeters: distance));
        }
    }
    stationsWithDistances.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    if (mounted) setState(() => _sortedStations = stationsWithDistances);
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
          final currentBatteryLevel = (data['batteryLevel'] as num?)?.toInt() ?? 100;
          batteryLevel = currentBatteryLevel;
          isRunning = data['isRunning'] ?? false;
          aiThreshold =
              (data['aiRecommendationThreshold'] as num?)?.toDouble() ?? 30.0;
          isLowBattery = currentBatteryLevel <= aiThreshold;
          
          // --- NEW LOGIC: Update the trend state. It only changes if the direction changes. ---
          if (currentBatteryLevel < _previousBatteryLevel) {
            _batteryTrend = BatteryTrend.draining;
          } else if (currentBatteryLevel > _previousBatteryLevel) {
            _batteryTrend = BatteryTrend.charging;
          }
          // If the level is the same, the trend persists from the previous state.

          if (currentBatteryLevel <= aiThreshold && _previousBatteryLevel > aiThreshold) {
            NotificationService.instance.showLowBatteryNotification(currentBatteryLevel);
          }
          _previousBatteryLevel = currentBatteryLevel;

          if (widget.shouldTriggerAi && !_aiTriggerConsumed) {
            _aiTriggerConsumed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onAiTriggered();
              _findBestStation(batteryLevel.toDouble());
            });
          }

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

        // --- NEW LOGIC: Determine color based on the persistent trend state ---
        final Color batteryColor;
        switch (_batteryTrend) {
          case BatteryTrend.charging:
            batteryColor = Colors.green.shade700;
            break;
          case BatteryTrend.draining:
            batteryColor = Colors.red.shade700;
            break;
          default: // stable
            batteryColor = Colors.black;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLowBattery && _showLowBatteryWarning) ...[
                _buildLowBatteryWarning(
                  batteryLevel: batteryLevel.toDouble(),
                  onFindStations: () {
                    _findBestStation(batteryLevel.toDouble());
                  },
                  onClose: () => setState(() => _showLowBatteryWarning = false),
                ),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('Battery Status'),
              const SizedBox(height: 8),
              _buildBatteryStatus(batteryLevel, _currentLocationName, batteryColor),
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
                        widget.navigatorKey.currentState!.push(
                          MaterialPageRoute(
                            builder: (_) => NearbyStationsPage(
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
                navigatorKey: widget.navigatorKey,
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
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

  Widget _buildBatteryStatus(int batteryLevel, String locationName, Color batteryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$batteryLevel%',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: batteryColor,
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('History Page - Coming Soon!',
            style: TextStyle(fontSize: 24)));
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

  static EVUserDashboardState? of(BuildContext context) =>
      context.findAncestorStateOfType<EVUserDashboardState>();

  @override
  State<EVUserDashboard> createState() => EVUserDashboardState();
}

class EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;
  String? _email;
  bool _isLoading = true;
  bool _shouldTriggerAi = false;
  bool _setupDialogOpen = false;
  
  final GlobalKey<HomePageState> homePageStateKey = GlobalKey<HomePageState>();
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final _mapNavigatorKey = GlobalKey<NavigatorState>();
  final _historyNavigatorKey = GlobalKey<NavigatorState>();
  final _profileNavigatorKey = GlobalKey<NavigatorState>();

  LatLng? _mapDestination;
  String? _mapDestinationStationId;

  @override
  void initState() {
    super.initState();
    _shouldTriggerAi = widget.triggerAiRecommendation;
    _initializeAndCheckProfile();
  }

  void navigateToMapWithDestination(LatLng destination, String stationId) {
    setState(() {
      _mapDestination = destination;
      _mapDestinationStationId = stationId;
      _selectedIndex = 1; 
    });
  }
  
  void navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> triggerAiRecommendation() async {
    navigateToTab(0);
    
    final vehicleRef = FirebaseDatabase.instance.ref('vehicles/${widget.email.replaceAll('.', ',')}');
    final snapshot = await vehicleRef.get();
    double batteryLevel = 30.0;
    if(snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      batteryLevel = (data['batteryLevel'] as num?)?.toDouble() ?? 30.0;
    }
    
    homePageStateKey.currentState?.findBestStationPublic(batteryLevel);
  }

  void _clearMapDestination() {
    if (mounted && (_mapDestination != null || _mapDestinationStationId != null)) {
      setState(() {
        _mapDestination = null;
        _mapDestinationStationId = null;
      });
    }
  }

  Future<void> _ensureRtdbVehicleNodeExists(String email) async { 
    try {
      final encodedEmail = email.replaceAll('.', ',');
      final ref = FirebaseDatabase.instance.ref('vehicles/$encodedEmail');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(email).get();
        final userData = userDoc.data() ?? {};
        await ref.set({
          'email': email, 'brand': userData['brand'] ?? '', 'variant': userData['variant'] ?? '',
          'isRunning': false, 'batteryLevel': 100,
          'aiRecommendationThreshold': userData['aiRecommendationThreshold'] ?? 30.0,
          'latitude': null, 'longitude': null,
        });
      }
    } catch (e) {
      print("❌ Failed to ensure RTDB node exists: $e");
    }
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
    _email = emailToUse;
    await _ensureRtdbVehicleNodeExists(emailToUse);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(emailToUse).get();
      final data = doc.data();
      if (!doc.exists || data == null || data['brand'] == null || (data['brand'] as String).isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showProfileSetupDialog(); });
      }
    } catch (e) {
      print("Error checking profile completion: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
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
    if (index == _selectedIndex) {
      switch (index) {
        case 0:
          _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          break;
        case 1:
          _mapNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          break;
        case 2:
          _historyNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          break;
        case 3:
          _profileNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          break;
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text('EV Smart Charge',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      actions: [
        IconButton(
          onPressed: () {
            final navigatorKey = [
              _homeNavigatorKey,
              _mapNavigatorKey,
              _historyNavigatorKey,
              _profileNavigatorKey
            ][_selectedIndex];
            
            navigatorKey.currentState!.push(
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
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    Navigator(
                      key: _homeNavigatorKey,
                      onGenerateRoute: (route) => MaterialPageRoute(
                        settings: route,
                        builder: (context) => HomePage(
                          key: homePageStateKey, 
                          email: _email!,
                          shouldTriggerAi: _shouldTriggerAi,
                          onAiTriggered: () {
                            if (mounted && _shouldTriggerAi) {
                              setState(() => _shouldTriggerAi = false);
                            }
                          },
                          navigatorKey: _homeNavigatorKey,
                        ),
                      ),
                    ),
                    Navigator(
                      key: _mapNavigatorKey,
                      onGenerateRoute: (route) => MaterialPageRoute(
                        settings: route,
                        builder: (context) => LiveMapPage(
                          email: _email!,
                          isEmbedded: true,
                          destination: _mapDestination,
                          destinationStationId: _mapDestinationStationId,
                          onNavigationComplete: _clearMapDestination,
                        ),
                      ),
                    ),
                    Navigator(
                      key: _historyNavigatorKey,
                      onGenerateRoute: (route) => MaterialPageRoute(
                        settings: route,
                        builder: (context) => const HistoryPage(),
                      ),
                    ),
                    Navigator(
                      key: _profileNavigatorKey,
                      onGenerateRoute: (route) => MaterialPageRoute(
                        settings: route,
                        builder: (context) => const EVUserProfile(),
                      ),
                    ),
                  ],
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
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}