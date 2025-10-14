// lib/pages/evuser/all_stations_status_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // <-- IMPORT RTDB
import 'package:latlong2/latlong.dart';
import 'widgets/nearby_stations_widget.dart';
import 'live_map_page.dart';

String formatDistance(double? meters) {
  if (meters == null) return 'N/A';
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m away';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }
}

class AllStationsStatusPage extends StatelessWidget {
  final List<StationWithDistance> stations;
  final String email;

  const AllStationsStatusPage({
    super.key,
    required this.stations,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Stations Status'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          // Each card gets its own StreamBuilder to listen for live updates from RTDB
          return _RealTimeStationCard(station: station, email: email);
        },
      ),
    );
  }
}

class _RealTimeStationCard extends StatelessWidget {
  const _RealTimeStationCard({
    required this.station,
    required this.email,
  });

  final StationWithDistance station;
  final String email;

  @override
  Widget build(BuildContext context) {
    final stationData = station.data; // Static data from Firestore
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
            availableSlots = data.where((s) => s == true).length;
          }
        } else if (stationData['totalSlots'] != null) {
           totalSlots = (stationData['totalSlots'] as num).toInt();
        }

        final stationName = stationData['name'] ?? 'Unknown Station';
        final List<dynamic> slotsInfo = stationData['slots'] ?? [];
        
        final Color statusColor = availableSlots > 0 ? Colors.green.shade700 : Colors.orange.shade800;
        final String statusText = availableSlots > 0 ? "Available" : "Likely Full";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        stationName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(
                      label: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: statusColor.withOpacity(0.1),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatDistance(station.distanceInMeters),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const Divider(height: 24),
                _buildInfoRow(Icons.power_outlined, "Availability", "$availableSlots / $totalSlots slots free"),
                const SizedBox(height: 12),
                const Text("Charger Types:", style: TextStyle(fontWeight: FontWeight.w500)),
                if (slotsInfo.isEmpty) const Text("  • No charger info available"),
                ...slotsInfo.map((slot) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Text('• ${slot['chargerType']} (${slot['powerKw']} kW)'),
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text("Get Directions"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final lat = stationData['latitude'];
                      final lng = stationData['longitude'];
                      if (lat != null && lng != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveMapPage(
                              email: email,
                              destination: LatLng(lat, lng),
                              destinationStationId: station.id,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Text('$title: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}