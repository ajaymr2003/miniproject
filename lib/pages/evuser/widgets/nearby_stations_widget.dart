import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

// Helper class to hold both station data and its calculated distance
class StationWithDistance {
  final QueryDocumentSnapshot stationDoc;
  final double distanceInMeters;

  StationWithDistance({required this.stationDoc, required this.distanceInMeters});

  Map<String, dynamic> get data => stationDoc.data() as Map<String, dynamic>;
}

class NearbyStationsWidget extends StatefulWidget {
  final String email;
  // Callback function to pass the sorted list back to the parent
  final Function(List<StationWithDistance>) onStationsSorted;

  const NearbyStationsWidget({
    super.key, 
    required this.email,
    required this.onStationsSorted,
  });

  @override
  State<NearbyStationsWidget> createState() => _NearbyStationsWidgetState();
}

class _NearbyStationsWidgetState extends State<NearbyStationsWidget> {
  List<QueryDocumentSnapshot> _allStations = [];
  bool _isLoadingStations = true;
  String? _stationError;

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  // --- FULL FUNCTION DEFINITIONS ---

  Future<void> _fetchStations() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stations').get();
      if (mounted) {
        setState(() {
          _allStations = snapshot.docs;
          _isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stationError = "Failed to load stations.";
          _isLoadingStations = false;
        });
      }
    }
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  List<StationWithDistance> _calculateAndSortStations(double userLat, double userLng) {
    if (_allStations.isEmpty) return [];
    List<StationWithDistance> stationsWithDistances = [];
    for (var stationDoc in _allStations) {
      final data = stationDoc.data() as Map<String, dynamic>;
      final stationLat = data['latitude'];
      final stationLng = data['longitude'];
      if (stationLat != null && stationLng != null) {
        final distance = Geolocator.distanceBetween(userLat, userLng, stationLat, stationLng);
        stationsWithDistances.add(StationWithDistance(stationDoc: stationDoc, distanceInMeters: distance));
      }
    }
    stationsWithDistances.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return stationsWithDistances;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleRtdbRef = FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');

    return StreamBuilder<DatabaseEvent>(
      stream: vehicleRtdbRef.onValue,
      builder: (context, snapshot) {
        if (_isLoadingStations) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (_stationError != null) {
          return SizedBox(height: 150, child: Center(child: Text(_stationError!, style: const TextStyle(color: Colors.red))));
        }
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox(height: 150, child: Center(child: Text("Waiting for live location...")));
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final userLat = data['latitude'];
        final userLng = data['longitude'];

        if (userLat == null || userLng == null) {
          return const SizedBox(height: 150, child: Center(child: Text("Simulator has no location data.")));
        }

        final sortedStations = _calculateAndSortStations(userLat, userLng);
        
        // Use the callback to notify the parent of the newly sorted list
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onStationsSorted(sortedStations);
        });
        
        if (sortedStations.isEmpty) {
          return const SizedBox(height: 150, child: Center(child: Text("No stations found.")));
        }

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sortedStations.length,
            itemBuilder: (context, index) {
              final station = sortedStations[index];
              return _buildStationCard(
                station.data['name'] ?? 'Unknown',
                '${_formatDistance(station.distanceInMeters)} - ${station.data['availableSlots'] ?? '?'} slots',
                Colors.primaries[index % Colors.primaries.length].shade700,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStationCard(String name, String details, Color color) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Navigating to $name...'))),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.ev_station, color: Colors.white, size: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(details, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}