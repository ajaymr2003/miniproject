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
import '../../routes/app_routes.dart';

class LiveMapPage extends StatefulWidget {
  final String email;
  final LatLng? destination;
  final bool isEmbedded;

  const LiveMapPage({
    super.key,
    required this.email,
    this.destination,
    this.isEmbedded = false,
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
  void dispose() {
    _vehicleSubscription?.cancel();
    _navigationStatusSubscription?.cancel();
    super.dispose();
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
  
  Future<void> _showDestinationReachedDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 10),
            Text('Destination Reached!'),
          ],
        ),
        content: const Text('You have arrived at your charging station.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.evuserDashboard,
                (route) => false,
                arguments: {'role': 'EV User', 'email': widget.email},
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _subscribeToNavigationStatus() {
    _navigationStatusSubscription = FirebaseFirestore.instance
        .collection('navigation')
        .doc(widget.email)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data();
        final isNavigatingNow = data?['isNavigating'] ?? false;
        // --- FIX: Listen for the correct field name from the database ---
        final hasReached = data?['vehicleReachedStation'] ?? false;

        if (isNavigatingNow != _isNavigating) {
          setState(() {
            _isNavigating = isNavigatingNow;
          });
        }
        
        if (hasReached && !_hasShownReachedPopup) {
            print('✅ Destination reached flag received from backend!');
            
            setState(() => _hasShownReachedPopup = true);
            
            _stopNavigation();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDestinationReachedDialog();
            });
        }

      } else if (mounted && _isNavigating) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  Future<void> _startNavigation() async {
    setState(() {
      _isUpdatingNavigation = true;
      _isNavigating = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception("Could not get latest vehicle location.");
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final lat = data['latitude'];
      final lng = data['longitude'];

      if (lat == null || lng == null) {
        throw Exception("Latest vehicle location is invalid.");
      }
      
      final startPoint = LatLng(lat, lng);
      final endPoint = widget.destination!;
      final userEmail = widget.email;

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
        // --- FIX: Write the correct field name to the database ---
        'vehicleReachedStation': false, 
        'timestamp': FieldValue.serverTimestamp(),
      });

      await ref.update({'isRunning': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Navigation started!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isNavigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to start navigation: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingNavigation = false);
    }
  }

  Future<void> _stopNavigation() async {
    setState(() {
      _isUpdatingNavigation = true;
      _isNavigating = false;
    });

    try {
      final userEmail = widget.email;

      await FirebaseFirestore.instance
          .collection('navigation')
          .doc(userEmail)
          .update({'isNavigating': false});

      await FirebaseDatabase.instance
          .ref('vehicles/${_encodeEmailForRtdb(userEmail)}')
          .update({'isRunning': false});
      
      if (mounted) {
        // Don't show this snackbar if the "reached" popup is about to show
        if (!_hasShownReachedPopup) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Navigation stopped.'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isNavigating = true);
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

        if (!_hasCenteredOnCar) {
          _mapController.move(newPosition, 15.0);
          _hasCenteredOnCar = true;
        }

        if (widget.destination != null && !_hasFittedBounds && !_isLoadingRoute) {
          _fetchAndDrawRoute(newPosition, widget.destination!);
        }

        if (mounted) {
          setState(() {
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final bounds = LatLngBounds.fromPoints([start, end]);
            _mapController.fitCamera(
              CameraFit.bounds(
                  bounds: bounds, padding: const EdgeInsets.all(50)),
            );
            setState(() {
              _hasFittedBounds = true;
            });
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

  Widget _buildZoomControls() {
    return Positioned(
      bottom: widget.destination != null ? 90 : 20,
      right: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: "zoomInButton",
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: _zoomIn,
            child: const Icon(Icons.add, size: 24),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoomOutButton",
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: _zoomOut,
            child: const Icon(Icons.remove, size: 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mapContent = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
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
        _buildZoomControls(),
        if (widget.destination != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Center(
              child: FloatingActionButton.extended(
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
            ),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return mapContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destination == null ? "" : "Navigation"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: mapContent,
    );
  }
}