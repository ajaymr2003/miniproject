// lib/pages/evuser/live_map_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class LiveMapPage extends StatefulWidget {
  final String email;
  final LatLng? destination; // Destination is optional for navigation mode

  const LiveMapPage({
    super.key,
    required this.email,
    this.destination,
  });

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final MapController _mapController = MapController();
  final List<Marker> _stationMarkers = [];
  StreamSubscription? _vehicleSubscription;
  // --- NEW: Subscription for navigation status ---
  StreamSubscription? _navigationStatusSubscription;
  Marker? _userCarMarker;
  Polyline? _routePolyline;
  bool _isLoadingRoute = false;
  // --- NEW: Track if the map has been centered on the car yet ---
  bool _hasCenteredOnCar = false;

  // --- NEW: State for navigation control ---
  bool _isNavigating = false;
  bool _isUpdatingNavigation = false;

  @override
  void initState() {
    super.initState();
    _fetchStations();
    _subscribeToVehicleLocation();
    // --- NEW: Subscribe to navigation status if in navigation mode ---
    if (widget.destination != null) {
      _subscribeToNavigationStatus();
    }
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    // --- NEW: Cancel navigation subscription ---
    _navigationStatusSubscription?.cancel();
    super.dispose();
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  // --- NEW: Listen to the 'navigation' collection in Firestore ---
  void _subscribeToNavigationStatus() {
    _navigationStatusSubscription = FirebaseFirestore.instance
        .collection('navigation')
        .doc(widget.email)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data();
        final isNavigatingNow = data?['isNavigating'] ?? false;
        if (isNavigatingNow != _isNavigating) {
          setState(() {
            _isNavigating = isNavigatingNow;
          });
        }
      } else if (mounted && _isNavigating) {
        // If doc is deleted or doesn't exist, ensure we are not in navigating state
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  // --- NEW: Method to start navigation ---
  Future<void> _startNavigation() async {
    if (_userCarMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Cannot start: User location not available yet.")),
      );
      return;
    }
    setState(() => _isUpdatingNavigation = true);

    try {
      final startPoint = _userCarMarker!.point;
      final endPoint = widget.destination!;
      final userEmail = widget.email;

      // 1. Update Firestore 'navigation' collection
      await FirebaseFirestore.instance
          .collection('navigation')
          .doc(userEmail)
          .set({
        'email': userEmail,
        'start_lat': startPoint.latitude,
        'start_lng': startPoint.longitude,
        'end_lat': endPoint.latitude,
        'end_lng': endPoint.longitude,
        'isNavigating': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update Realtime DB 'isRunning' status
      await FirebaseDatabase.instance
          .ref('vehicles/${_encodeEmailForRtdb(userEmail)}')
          .update({'isRunning': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Navigation started!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to start navigation: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingNavigation = false);
    }
  }

  // --- NEW: Method to stop navigation ---
  Future<void> _stopNavigation() async {
    setState(() => _isUpdatingNavigation = true);
    try {
      final userEmail = widget.email;

      // 1. Update Firestore 'navigation' collection
      await FirebaseFirestore.instance
          .collection('navigation')
          .doc(userEmail)
          .update({'isNavigating': false});

      // 2. Update Realtime DB 'isRunning' status
      await FirebaseDatabase.instance
          .ref('vehicles/${_encodeEmailForRtdb(userEmail)}')
          .update({'isRunning': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Navigation stopped.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to stop navigation: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingNavigation = false);
    }
  }

  Future<void> _fetchStations() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('stations').get();
      final List<Marker> markers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'];
        final lng = data['longitude'];
        final name = data['name'] ?? 'Unnamed Station';
        if (lat != null && lng != null) {
          markers.add(Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(lat, lng),
            child: Tooltip(
              message: name,
              child: Icon(Icons.ev_station,
                  color: Colors.green.shade700, size: 40),
            ),
          ));
        }
      }
      if (mounted) setState(() => _stationMarkers.addAll(markers));
    } catch (e) {
      print("Error fetching stations: $e");
    }
  }

  void _subscribeToVehicleLocation() {
    final vehicleRtdbRef = FirebaseDatabase.instance
        .ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

    _vehicleSubscription = vehicleRtdbRef.onValue.listen((DatabaseEvent event) {
      if (!mounted || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = data['latitude'];
      final lng = data['longitude'];

      if (lat != null && lng != null) {
        final newPosition = LatLng(lat, lng);

        // --- THE FIX IS HERE ---
        // If we are NOT in navigation mode and haven't centered yet, do it now.
        if (widget.destination == null && !_hasCenteredOnCar) {
          _mapController.move(newPosition, 15.0);
          _hasCenteredOnCar = true; // Mark as centered so we don't keep jumping
        }

        // If we ARE in navigation mode, let the fitBounds logic handle centering.
        if (widget.destination != null &&
            _routePolyline == null &&
            !_isLoadingRoute) {
          _fetchAndDrawRoute(newPosition, widget.destination!);
        }

        if (mounted) {
          setState(() {
            _userCarMarker = Marker(
              width: 40.0, height: 40.0,
              point: newPosition,
              // Using a pre-made asset for the car is better for performance.
              // Make sure you have a 'car_marker.png' in an 'assets/images/' folder.
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

    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final routePoints =
            coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

        if (mounted) {
          setState(() {
            _routePolyline = Polyline(
                points: routePoints, color: Colors.blueAccent, strokeWidth: 5);
            _isLoadingRoute = false;
          });

          // Wait for the map to be ready before fitting bounds
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // The bounds should now include the user's car and the destination.
            final bounds = LatLngBounds.fromPoints([start, end]);
            _mapController.fitCamera(
              CameraFit.bounds(
                  bounds: bounds, padding: const EdgeInsets.all(50)),
            );
          });
        }
      } else {
        throw Exception('Failed to load route from OSRM');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate route: $e')));
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.destination == null ? "Live Vehicle Map" : "Navigation"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      // --- NEW: Add a FloatingActionButton for navigation control ---
      floatingActionButton: widget.destination == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isUpdatingNavigation
                  ? null
                  : (_isNavigating ? _stopNavigation : _startNavigation),
              icon: _isUpdatingNavigation
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(_isNavigating
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded),
              label: Text(_isNavigating ? 'Stop' : 'Start'),
              backgroundColor:
                  _isNavigating ? Colors.red.shade600 : Colors.green.shade600,
            ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Start with a generic center, it will be moved once data arrives.
              initialCenter: const LatLng(12.9716, 77.5946),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              MarkerLayer(markers: _stationMarkers),
              if (_userCarMarker != null)
                MarkerLayer(markers: [_userCarMarker!]),
            ],
          ),
          if (_userCarMarker == null || _isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _isLoadingRoute
                          ? 'Generating Route...'
                          : "Waiting for vehicle's live location...",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
