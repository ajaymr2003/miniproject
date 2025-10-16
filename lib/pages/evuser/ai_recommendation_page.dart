// lib/pages/evuser/ai_recommendation_page.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// --- MODIFICATION: Import Firebase Realtime Database ---
import 'package:firebase_database/firebase_database.dart'; 
import 'widgets/nearby_stations_widget.dart';
import 'live_map_page.dart';
import 'evuser_dashboard.dart';

String formatDistance(double? meters) {
  if (meters == null) return 'N/A';
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class AiRecommendationPage extends StatelessWidget {
  final String reason;
  final List<StationWithDistance> recommendedStations;
  final String email;

  const AiRecommendationPage({
    super.key,
    required this.reason,
    required this.recommendedStations,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('AI Recommendations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: recommendedStations.isEmpty 
        ? _buildNoResults()
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: recommendedStations.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader();
              }
              final station = recommendedStations[index - 1];
              return _buildStationCard(context, station, index);
            },
          ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 50),
          const SizedBox(height: 16),
          const Text(
            "Here are your top stations",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 80),
            const SizedBox(height: 16),
            const Text(
              "No Recommendations Found",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "The AI couldn't find a suitable station based on the current data. This could be due to a network issue or no nearby stations matching the criteria.",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- MAJOR MODIFICATION: This card now uses a StreamBuilder for live data ---
  Widget _buildStationCard(BuildContext context, StationWithDistance stationDetails, int rank) {
    final data = stationDetails.data;
    final stationName = data['name'] ?? 'Unknown Station';
    final address = data['address'] ?? 'No address provided';
    final stationId = stationDetails.stationDoc.id;
    final stationStatusRef = FirebaseDatabase.instance.ref('station_status/$stationId');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank.',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Use a StreamBuilder to get and display live slot availability
            StreamBuilder<DatabaseEvent>(
              stream: stationStatusRef.onValue,
              builder: (context, snapshot) {
                // Fallback values from Firestore
                int totalSlots = (data['totalSlots'] as num?)?.toInt() ?? 0;
                int availableSlots = (data['availableSlots'] as num?)?.toInt() ?? 0;
                String slotsText = '$availableSlots / $totalSlots free';

                // If stream is loading, show a placeholder
                if (snapshot.connectionState == ConnectionState.waiting) {
                  slotsText = 'Loading...';
                }

                // If stream has active data, parse it
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  final rtdbData = snapshot.data!.snapshot.value;
                  if (rtdbData is List) {
                    totalSlots = rtdbData.length;
                    availableSlots = rtdbData.where((s) => s == true).length;
                    slotsText = '$availableSlots / $totalSlots free';
                  }
                }
                
                // Build the info row with the latest data
                return _buildStationInfoRow(stationDetails, slotsText);
              },
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions_outlined, size: 20),
                  label: const Text("Directions"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final lat = data['latitude'];
                    final lng = data['longitude'];
                    if (lat != null && lng != null) {
                      // Navigate using the dashboard's main map tab
                      final dashboardState = EVUserDashboard.of(context);
                      dashboardState?.navigateToMapWithDestination(
                        LatLng(lat, lng),
                        stationId,
                      );
                      // Pop this recommendation page
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- MODIFICATION: This helper now accepts the final slots text ---
  Widget _buildStationInfoRow(StationWithDistance stationDetails, String slotsText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Chip(
          avatar: Icon(Icons.social_distance_outlined, size: 16, color: Colors.blue.shade800),
          label: Text(formatDistance(stationDetails.distanceInMeters)),
          backgroundColor: Colors.blue.withOpacity(0.1),
          side: BorderSide.none,
        ),
        const SizedBox(width: 12),
        Chip(
          avatar: Icon(Icons.electric_bolt_outlined, size: 16, color: Colors.green.shade800),
          label: Text(slotsText), // Use the live text passed in
          backgroundColor: Colors.green.withOpacity(0.1),
          side: BorderSide.none,
        ),
      ],
    );
  }
}