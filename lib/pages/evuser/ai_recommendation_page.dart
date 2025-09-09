import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'widgets/nearby_stations_widget.dart';
import 'live_map_page.dart';

// Helper function to format distance
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
  final StationWithDistance stationDetails;
  // This is required to find the user's car on the map
  final String email;

  const AiRecommendationPage({
    super.key,
    required this.reason,
    required this.stationDetails,
    required this.email,
  });

  // Helper widget to create consistent detail rows
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = stationDetails.data;
    final stationName = data['name'] ?? 'Unknown Station';
    final availableSlots = (data['availableSlots'] as num?)?.toInt() ?? 0;
    final totalSlots = (data['totalSlots'] as num?)?.toInt() ?? 0;
    final chargerSpeed = (data['chargerSpeed'] as num?)?.toInt() ?? 50;

    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.electric_bolt_rounded,
                color: Colors.yellowAccent,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'AI Recommendation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                stationName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      '"$reason"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const Divider(color: Colors.white30, height: 32),
                    _buildDetailRow(
                      Icons.social_distance_outlined,
                      "Distance",
                      formatDistance(stationDetails.distanceInMeters),
                    ),
                    _buildDetailRow(
                      Icons.electric_bolt_outlined,
                      "Available Slots",
                      "$availableSlots / $totalSlots",
                    ),
                    _buildDetailRow(
                      Icons.speed_outlined,
                      "Charger Speed",
                      "$chargerSpeed kW (est.)",
                    ),
                    _buildDetailRow(
                      Icons.location_on_outlined,
                      "Address",
                      data['address'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined),
                label: const Text("Start In-App Navigation"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellowAccent,
                  foregroundColor: Colors.indigo.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final lat = data['latitude'];
                  final lng = data['longitude'];

                  if (lat != null && lng != null) {
                    final destination = LatLng(lat, lng);
                    // Navigate to the live map page, providing the destination
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveMapPage(
                          email: email,
                          destination: destination,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Station location not available for navigation.")),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}