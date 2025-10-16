// lib/pages/evuser/widgets/nearby_stations_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import '../station_details_page.dart';

class StationWithDistance {
  final QueryDocumentSnapshot stationDoc;
  final double distanceInMeters;

  StationWithDistance({
    required this.stationDoc,
    required this.distanceInMeters,
  });

  String get id => stationDoc.id;
  Map<String, dynamic> get data => stationDoc.data() as Map<String, dynamic>;
}

class NearbyStationsWidget extends StatefulWidget {
  final String email;
  final Function(List<StationWithDistance>) onStationsSorted;
  // --- MODIFICATION: Re-add the navigatorKey ---
  final GlobalKey<NavigatorState> navigatorKey;

  const NearbyStationsWidget({
    super.key,
    required this.email,
    required this.onStationsSorted,
    // --- MODIFICATION: Add key to constructor ---
    required this.navigatorKey,
  });

  @override
  State<NearbyStationsWidget> createState() => _NearbyStationsWidgetState();
}

class _NearbyStationsWidgetState extends State<NearbyStationsWidget> {
  StreamSubscription<QuerySnapshot>? _stationSubscription;
  List<QueryDocumentSnapshot> _allStations = [];
  bool _isLoadingStations = true;
  String? _stationError;

  @override
  void initState() {
    super.initState();
    _listenToStations();
  }

  @override
  void dispose() {
    _stationSubscription?.cancel();
    super.dispose();
  }

  void _listenToStations() {
    final stationsQuery = FirebaseFirestore.instance
        .collection('stations')
        .where('isActive', isEqualTo: true)
        .snapshots();

    _stationSubscription = stationsQuery.listen((snapshot) {
      if (mounted) {
        setState(() {
          _allStations = snapshot.docs;
          _isLoadingStations = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _stationError = "Failed to load stations.";
          _isLoadingStations = false;
        });
      }
    });
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  List<StationWithDistance> _calculateAndSortStations(
      double userLat, double userLng) {
    if (_allStations.isEmpty) return [];
    List<StationWithDistance> stationsWithDistances = [];
    for (var stationDoc in _allStations) {
      final data = stationDoc.data() as Map<String, dynamic>;
      final stationLat = data['latitude'];
      final stationLng = data['longitude'];
      if (stationLat != null && stationLng != null) {
        final distance = Geolocator.distanceBetween(
            userLat, userLng, stationLat, stationLng);
        stationsWithDistances.add(StationWithDistance(
            stationDoc: stationDoc, distanceInMeters: distance));
      }
    }
    stationsWithDistances
        .sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return stationsWithDistances;
  }

  @override
  Widget build(BuildContext context) {
    final vehicleRtdbRef = FirebaseDatabase.instance
        .ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

    return StreamBuilder<DatabaseEvent>(
      stream: vehicleRtdbRef.onValue,
      builder: (context, userLocationSnapshot) {
        if (_isLoadingStations) {
          return const SizedBox(
              height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (_stationError != null) {
          return SizedBox(
              height: 150,
              child: Center(
                  child: Text(_stationError!,
                      style: const TextStyle(color: Colors.red))));
        }
        if (!userLocationSnapshot.hasData || userLocationSnapshot.data?.snapshot.value == null) {
          return const SizedBox(
              height: 150,
              child: Center(child: Text("Waiting for live location...")));
        }

        final userData =
            Map<String, dynamic>.from(userLocationSnapshot.data!.snapshot.value as Map);
        final userLat = userData['latitude'];
        final userLng = userData['longitude'];

        if (userLat == null || userLng == null) {
          return const SizedBox(
              height: 150,
              child: Center(child: Text("Simulator has no location data.")));
        }

        final sortedStations = _calculateAndSortStations(userLat, userLng);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            widget.onStationsSorted(sortedStations);
          }
        });

        if (sortedStations.isEmpty) {
          return const SizedBox(
              height: 150, child: Center(child: Text("No stations found.")));
        }

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sortedStations.length,
            itemBuilder: (context, index) {
              final station = sortedStations[index];
              return _StationCard(
                station: station,
                color: Colors.primaries[index % Colors.primaries.length].shade700,
                email: widget.email,
                // --- MODIFICATION: Pass the key to the card ---
                navigatorKey: widget.navigatorKey,
              );
            },
          ),
        );
      },
    );
  }
}


class _StationCard extends StatelessWidget {
  final StationWithDistance station;
  final Color color;
  final String email;
  // --- MODIFICATION: Re-add the navigatorKey ---
  final GlobalKey<NavigatorState> navigatorKey;

  const _StationCard({
    required this.station, 
    required this.color, 
    required this.email,
    // --- MODIFICATION: Add key to constructor ---
    required this.navigatorKey,
  });
  
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final stationStatusRef = FirebaseDatabase.instance.ref('station_status/${station.id}');

    return StreamBuilder<DatabaseEvent>(
      stream: stationStatusRef.onValue,
      builder: (context, snapshot) {
        int availableSlots = 0;
        int totalSlots = 0;

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value;
          if (data is List) {
            totalSlots = data.length;
            availableSlots = data.where((slotStatus) => slotStatus == true).length;
          }
        }
        
        final stationName = station.data['name'] ?? 'Unknown';
        final details = '${_formatDistance(station.distanceInMeters)} - $availableSlots slots';
        
        return GestureDetector(
          // --- MAJOR CHANGE: Use the provided navigatorKey, NOT the rootNavigator ---
          onTap: () {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) =>
                    StationDetailsPage(station: station, email: email),
              ),
            );
          },
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.ev_station, color: Colors.white, size: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stationName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}