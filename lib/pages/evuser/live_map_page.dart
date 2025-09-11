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
  Marker? _userCarMarker;
  Polyline? _routePolyline;
  bool _isLoadingRoute = false;
  // --- NEW: Track if the map has been centered on the car yet ---
  bool _hasCenteredOnCar = false;

  @override
  void initState() {
    super.initState();
    _fetchStations();
    _subscribeToVehicleLocation();
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  Future<void> _fetchStations() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stations').get();
      final List<Marker> markers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'];
        final lng = data['longitude'];
        final name = data['name'] ?? 'Unnamed Station';
        if (lat != null && lng != null) {
          markers.add(Marker(
            width: 80.0, height: 80.0,
            point: LatLng(lat, lng),
            child: Tooltip(
              message: name,
              child: Icon(Icons.ev_station, color: Colors.green.shade700, size: 40),
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
    final vehicleRtdbRef =
        FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

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
        if (widget.destination != null && _routePolyline == null && !_isLoadingRoute) {
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

    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

        if (mounted) {
          setState(() {
            _routePolyline = Polyline(points: routePoints, color: Colors.blueAccent, strokeWidth: 5);
            _isLoadingRoute = false;
          });

          // Wait for the map to be ready before fitting bounds
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // The bounds should now include the user's car and the destination.
            final bounds = LatLngBounds.fromPoints([start, end]);
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
            );
          });
        }
      } else {
        throw Exception('Failed to load route from OSRM');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate route: $e')));
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destination == null ? "Live Vehicle Map" : "Navigation"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
              if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
              MarkerLayer(markers: _stationMarkers),
              if (_userCarMarker != null) MarkerLayer(markers: [_userCarMarker!]),
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
                      _isLoadingRoute ? 'Generating Route...' : "Waiting for vehicle's live location...",
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