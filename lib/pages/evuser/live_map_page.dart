// lib/pages/evuser/live_map_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import 'evuser_dashboard.dart';

class LiveMapPage extends StatefulWidget {
  final String email;
  final LatLng? destination;
  final bool isEmbedded;
  final String? destinationStationId;
  final VoidCallback? onNavigationComplete;

  const LiveMapPage({
    super.key,
    required this.email,
    this.destination,
    this.isEmbedded = false,
    this.destinationStationId,
    this.onNavigationComplete,
  });

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final MapController _mapController = MapController();
  final List<Marker> _stationMarkers = [];
  StreamSubscription? _vehicleSubscription;
  StreamSubscription? _navigationStatusSubscription;
  Marker? _userCarMarker;
  Polyline? _routePolyline;
  bool _isLoadingRoute = false;
  bool _hasCenteredOnCar = false;
  bool _isNavigating = false;
  bool _isUpdatingNavigation = false;
  bool _hasFittedBounds = false;
  bool _hasShownReachedPopup = false;
  bool _hasShownStationFullPopup = false;
  
  bool _hasArrived = false;
  bool _isCharging = false;
  bool _hasShownChargingCompletePopup = false;
  bool _hasShownChargingStartedPopup = false;
  
  bool _previousChargingCompleteState = false;

  // State variables for live data
  double _currentSpeed = 0.0;
  int _currentBatteryLevel = 0;


  @override
  void initState() {
    super.initState();
    _fetchStations();
    _subscribeToVehicleLocation();
    if (widget.destination != null) {
      _subscribeToNavigationStatus();
    }
  }

  @override
  void didUpdateWidget(covariant LiveMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != null && widget.destination != oldWidget.destination) {
      _resetRouteState();
      _subscribeToNavigationStatus();
      if (_userCarMarker != null) {
         _fetchAndDrawRoute(_userCarMarker!.point, widget.destination!);
      }
    }
    if (widget.destination == null && oldWidget.destination != null) {
      _clearRouteAndNavigation();
    }
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    _navigationStatusSubscription?.cancel();
    super.dispose();
  }

  void _resetRouteState() {
    setState(() {
      _routePolyline = null;
      _hasFittedBounds = false;
      _hasShownReachedPopup = false;
      _hasShownStationFullPopup = false;
      _hasArrived = false;
      _isCharging = false;
      _hasShownChargingCompletePopup = false;
      _hasShownChargingStartedPopup = false;
      _previousChargingCompleteState = false;
    });
  }

  void _clearRouteAndNavigation() {
    setState(() {
      _routePolyline = null;
      _isNavigating = false;
      _hasArrived = false;
      _isCharging = false;
    });
    _navigationStatusSubscription?.cancel();
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }
  
  // --- MODIFIED: On "OK" press, it now records the start details. ---
  Future<void> _showDestinationReachedDialog() async {
    if (!mounted || _hasShownReachedPopup) return;
    setState(() => _hasShownReachedPopup = true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle_outline, color: Colors.green), SizedBox(width: 10), Text('Destination Reached!')]),
        content: const Text('You have arrived at your charging station. Please wait for charging to begin.'),
        actions: [
          TextButton(
            onPressed: () { 
              Navigator.of(dialogContext).pop(); 
              _recordChargingStartDetails(); // Record details on OK press
            }, 
            child: const Text('OK')
          )
        ],
      ),
    );
  }

  Future<void> _showStationFullDialog(String stationName) async {
    if (!mounted || _hasShownStationFullPopup) return;
    setState(() => _hasShownStationFullPopup = true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text('Station Full!')]),
        content: Text('Unfortunately, "$stationName" has become full while you were en route. Let\'s find another one.'),
        actions: [
          TextButton(onPressed: () { Navigator.of(dialogContext).pop(); widget.onNavigationComplete?.call(); }, child: const Text('OK')),
          ElevatedButton(onPressed: () { Navigator.of(dialogContext).pop(); _triggerNewAiRecommendation(); }, child: const Text('Find Another')),
        ],
      ),
    );
  }

  Future<void> _showChargingCompleteDialog() async {
    if (!mounted || _hasShownChargingCompletePopup) return;
    setState(() => _hasShownChargingCompletePopup = true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.electric_bolt, color: Colors.blue), SizedBox(width: 10), Text('Charging Complete')]),
        content: const Text('Your charging session has finished.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _finalizeAndClearSession();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChargingStartedDialog() async {
    if (!mounted || _hasShownChargingStartedPopup) return;
    setState(() => _hasShownChargingStartedPopup = true);
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.power, color: Colors.green), SizedBox(width: 10), Text('Charging Started')]),
        content: const Text('Your vehicle is now charging.'),
        actions: [TextButton(onPressed: () { Navigator.of(dialogContext).pop(); }, child: const Text('OK'))],
      ),
    );
  }

  void _subscribeToNavigationStatus() {
    _navigationStatusSubscription?.cancel();
    _navigationStatusSubscription = FirebaseFirestore.instance.collection('navigation').doc(widget.email).snapshots().listen((snapshot) {
      if (!mounted || !snapshot.exists) {
        if (mounted) setState(() => _isNavigating = false);
        return;
      }

      final data = snapshot.data();
      if (data == null) return;
      
      final isNavigatingNow = data['isNavigating'] ?? false;
      final hasReached = data['vehicleReachedStation'] ?? false;
      final isChargingNow = data['isCharging'] ?? false;
      final isChargingDone = data['chargingComplete'] ?? false; 
      final isStationFull = data['stationIsFull'] ?? false;
      
      if (isStationFull) {
        final stationName = data['cancelledStationName'] ?? 'Your destination';
        _stopNavigation();
        WidgetsBinding.instance.addPostFrameCallback((_) => _showStationFullDialog(stationName));
        return;
      }
      
      // --- MODIFIED: On charging complete, record end details THEN show dialog ---
      if (isChargingDone && !_previousChargingCompleteState) {
        _previousChargingCompleteState = true; // Prevent re-triggering
        _recordChargingEndDetailsAndShowDialog();
      }

      if (hasReached && !_hasArrived) {
        setState(() {
          _hasArrived = true;
          _isNavigating = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _showDestinationReachedDialog());
      }
      
      if (isChargingNow && !_isCharging) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showChargingStartedDialog());
      }

      if (isNavigatingNow != _isNavigating) setState(() => _isNavigating = isNavigatingNow);
      if (isChargingNow != _isCharging) setState(() => _isCharging = isChargingNow);
    });
  }
  
  Future<void> _startNavigation() async {
    if (widget.destination == null) return;
    setState(() => _isUpdatingNavigation = true);
    try {
      final ref = FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) throw Exception("Could not get latest vehicle location.");
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final lat = data['latitude'];
      final lng = data['longitude'];
      if (lat == null || lng == null) throw Exception("Latest vehicle location is invalid.");
      final startPoint = LatLng(lat, lng);
      final navigationData = <String, dynamic>{
        'email': widget.email, 'start_lat': startPoint.latitude, 'start_lng': startPoint.longitude,
        'end_lat': widget.destination!.latitude, 'end_lng': widget.destination!.longitude,
        'isNavigating': true, 'vehicleReachedStation': false, 'timestamp': FieldValue.serverTimestamp(),
        'destinationStationId': widget.destinationStationId, 'stationIsFull': false,
        'isCharging': false, 'chargingComplete': false,
      };
      await FirebaseFirestore.instance.collection('navigation').doc(widget.email).set(navigationData);
      await ref.update({'isRunning': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigation started!'), backgroundColor: Colors.green));
        setState(() => _isNavigating = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start navigation: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdatingNavigation = false);
    }
  }

  Future<void> _stopNavigation() async {
    setState(() => _isUpdatingNavigation = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('navigation').doc(widget.email);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update({
          'isNavigating': false,
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}').update({'isRunning': false});
      
      if (mounted) {
        if (!_hasShownReachedPopup && !_hasShownStationFullPopup && !_hasShownChargingCompletePopup) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigation stopped.'), backgroundColor: Colors.orange));
        }
        widget.onNavigationComplete?.call();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to stop navigation: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdatingNavigation = false);
    }
  }

  Future<void> _finalizeAndClearSession() async {
    setState(() => _isUpdatingNavigation = true);
    try {
      final navDocRef = FirebaseFirestore.instance.collection('navigation').doc(widget.email);
      final navDoc = await navDocRef.get();
      
      if (navDoc.exists) {
        final navData = navDoc.data() as Map<String, dynamic>;
        String stationName = 'Unknown Station';

        if (navData['destinationStationId'] != null) {
          final stationDoc = await FirebaseFirestore.instance.collection('stations').doc(navData['destinationStationId']).get();
          if (stationDoc.exists) {
            stationName = stationDoc.data()?['name'] ?? 'Unknown Station';
          }
        }
        
        await FirebaseFirestore.instance.collection('navigation_history').add({
          'email': navData['email'],
          'stationId': navData['destinationStationId'],
          'stationName': stationName,
          'start_lat': navData['start_lat'],
          'start_lng': navData['start_lng'],
          'end_lat': navData['end_lat'],
          'end_lng': navData['end_lng'],
          'startedAt': navData['timestamp'],
          'endedAt': FieldValue.serverTimestamp(),
          'chargingStartedAt': navData['chargingStartedAt'],
          'chargingEndedAt': navData['chargingEndedAt'],
          'batteryLevelAtStart': navData['batteryLevelAtStart'],
          'batteryLevelAtEnd': navData['batteryLevelAtEnd'],
        });
      }

      await navDocRef.delete();
      await FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}').update({'isRunning': false});
      
      if (mounted) {
        widget.onNavigationComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to finalize session: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingNavigation = false);
      }
    }
  }

  // --- NEW METHOD: Records charging start details ---
  Future<void> _recordChargingStartDetails() async {
    try {
      await FirebaseFirestore.instance.collection('navigation').doc(widget.email).set({
        'chargingStartedAt': FieldValue.serverTimestamp(),
        'batteryLevelAtStart': _currentBatteryLevel,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error recording start details: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  // --- NEW METHOD: Records end details, THEN shows the dialog ---
  Future<void> _recordChargingEndDetailsAndShowDialog() async {
    try {
      // First, save the final details to the database.
      await FirebaseFirestore.instance.collection('navigation').doc(widget.email).set({
        'chargingEndedAt': FieldValue.serverTimestamp(),
        'batteryLevelAtEnd': _currentBatteryLevel,
      }, SetOptions(merge: true));

      // After the save is successful, show the completion dialog.
      if (mounted) {
        _showChargingCompleteDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error recording end details: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }


  void _triggerNewAiRecommendation() {
    widget.onNavigationComplete?.call();
    final dashboardState = EVUserDashboard.of(context);
    dashboardState?.triggerAiRecommendation();
  }

  Future<void> _fetchStations() async { 
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stations').get();
      final List<Marker> markers = snapshot.docs.map((doc) {
        final data = doc.data();
        return Marker(
          width: 80.0, height: 80.0,
          point: LatLng(data['latitude'], data['longitude']),
          child: Tooltip(
            message: data['name'] ?? 'Station',
            child: Icon(Icons.ev_station, color: Colors.green.shade700, size: 40),
          ),
        );
      }).toList();
      if (mounted) setState(() => _stationMarkers.addAll(markers));
    } catch (e) {
      print("Error fetching stations: $e");
    }
  }
  
  void _subscribeToVehicleLocation() {
    final vehicleRtdbRef = FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');
    _vehicleSubscription = vehicleRtdbRef.onValue.listen((DatabaseEvent event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = data['latitude'];
      final lng = data['longitude'];
      final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
      final battery = (data['batteryLevel'] as num?)?.toInt() ?? 0;

      if (lat != null && lng != null) {
        final newPosition = LatLng(lat, lng);
        if (!_hasCenteredOnCar) {
          _mapController.move(newPosition, 15.0);
          _hasCenteredOnCar = true;
        }
        if (widget.destination != null && _routePolyline == null && !_isLoadingRoute) {
          _fetchAndDrawRoute(newPosition, widget.destination!);
        }
        if (mounted) {
          setState(() {
            _currentSpeed = speed;
            _currentBatteryLevel = battery;
            _userCarMarker = Marker(
              width: 40.0, height: 40.0,
              point: newPosition,
              child: Image.asset('assets/images/car_marker.png'),
            );
          });
        }
      }
    }, onError: (error) {
      print("Error listening to vehicle location: $error");
    });
  }

  Future<void> _fetchAndDrawRoute(LatLng start, LatLng end) async { 
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
        if (mounted) {
          setState(() => _routePolyline = Polyline(points: routePoints, color: Colors.blueAccent, strokeWidth: 5));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final bounds = LatLngBounds.fromPoints([start, end]);
            _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
            setState(() => _hasFittedBounds = true);
          });
        }
      } else {
        throw Exception('Failed to load route');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate route: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Widget _buildZoomControls() { 
    return Positioned(
      bottom: widget.destination != null ? 90 : 20,
      right: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton.small(heroTag: "zoomInButton", backgroundColor: Colors.white, foregroundColor: Colors.black, onPressed: _zoomIn, child: const Icon(Icons.add, size: 24)),
          const SizedBox(height: 8),
          FloatingActionButton.small(heroTag: "zoomOutButton", backgroundColor: Colors.white, foregroundColor: Colors.black, onPressed: _zoomOut, child: const Icon(Icons.remove, size: 24)),
        ],
      ),
    );
  }

  Widget _buildSpeedDisplay() {
    return Positioned(
      top: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentSpeed.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryDisplay() {
    Color batteryColor = Colors.greenAccent;
    IconData icon = Icons.battery_full;

    if (_currentBatteryLevel <= 20) {
      batteryColor = Colors.redAccent;
      icon = Icons.battery_alert;
    } else if (_currentBatteryLevel <= 50) {
      batteryColor = Colors.orangeAccent;
      icon = Icons.battery_4_bar;
    }

    return Positioned(
      top: 15,
      left: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: batteryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              '$_currentBatteryLevel%',
              style: TextStyle(
                color: batteryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // --- MODIFIED: Simplified button logic ---
  Widget _buildNavigationControlButton() {
    if (_isUpdatingNavigation) {
      return const FloatingActionButton.extended(
        onPressed: null,
        label: Text('Updating...'),
        icon: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    // If a session is active (navigating, arrived, or charging) show a Stop/Cancel button
    if (_isNavigating || _hasArrived) {
      if (_isCharging) {
        // Charging has started, show a non-interactive status
         return const FloatingActionButton.extended(
          onPressed: null,
          label: Text('Charging...'),
          icon: Icon(Icons.electric_bolt),
          backgroundColor: Colors.blueAccent,
        );
      }
      // If navigating or arrived but not yet charging, allow user to stop the session
      return FloatingActionButton.extended(
        onPressed: _stopNavigation,
        label: const Text('Stop Session'),
        icon: const Icon(Icons.stop_rounded),
        backgroundColor: Colors.red.shade600,
      );
    }
    
    // Default state: no active session, show Start button
    return FloatingActionButton.extended(
      onPressed: _startNavigation,
      label: const Text('Start Navigation'),
      icon: const Icon(Icons.play_arrow_rounded),
      backgroundColor: Colors.green.shade600,
    );
  }


  @override
  Widget build(BuildContext context) { 
    Widget mapContent = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: const LatLng(12.9716, 77.5946), initialZoom: 14.0),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
            MarkerLayer(markers: _stationMarkers),
            if (_userCarMarker != null) MarkerLayer(markers: [_userCarMarker!]),
          ],
        ),
        if (_isLoadingRoute)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Generating Route...', style: TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
        _buildZoomControls(),
        if (_isNavigating || _hasArrived) _buildSpeedDisplay(),
        if (_isNavigating || _hasArrived) _buildBatteryDisplay(),
        if (widget.destination != null && !_hasArrived)
          Positioned(
            top: 90,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: "cancelRouteButton",
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              onPressed: () {
                widget.onNavigationComplete?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Route cancelled.')),
                );
              },
              tooltip: 'Cancel Route',
              child: const Icon(Icons.close),
            ),
          ),
        if (widget.destination != null && !_previousChargingCompleteState)
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Center(child: _buildNavigationControlButton()),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return mapContent;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.destination == null ? "Live Map" : "Navigation"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: mapContent,
    );
  }
}