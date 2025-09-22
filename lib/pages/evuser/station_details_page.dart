import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'widgets/nearby_stations_widget.dart'; // We need StationWithDistance
import 'live_map_page.dart'; // For navigation

// Helper function to format distance
String formatDistance(double? meters) {
  if (meters == null) return 'N/A';
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m away';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }
}

class StationDetailsPage extends StatelessWidget {
  final StationWithDistance station;
  final String email;

  const StationDetailsPage({
    super.key,
    required this.station,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The main content will be a StreamBuilder to get live updates
      body: StreamBuilder<DocumentSnapshot>(
        stream: station.stationDoc.reference.snapshots(),
        builder: (context, snapshot) {
          // While waiting for live data, show the static data we already have
          Map<String, dynamic> displayData = station.data;

          // Once live data arrives, update our display data
          if (snapshot.hasData && snapshot.data!.exists) {
            displayData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final stationName = displayData['name'] ?? 'Unknown Station';
          final imageUrl = displayData['imageUrl'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    stationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 10.0, color: Colors.black54)
                      ],
                    ),
                  ),
                  background: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey, size: 80),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade400,
                          child: const Icon(Icons.ev_station,
                              color: Colors.white, size: 100),
                        ),
                ),
              ),
              // The rest of the content is in a SliverList
              SliverToBoxAdapter(
                child:
                    _buildStationDetailsContent(context, station, displayData),
              ),
            ],
          );
        },
      ),
    );
  }

  // This widget contains all the details below the app bar image
  Widget _buildStationDetailsContent(BuildContext context,
      StationWithDistance station, Map<String, dynamic> liveData) {
    final address = liveData['address'] ?? 'No address provided';
    final availableSlots = (liveData['availableSlots'] as num?)?.toInt() ?? 0;
    final totalSlots = (liveData['totalSlots'] as num?)?.toInt() ?? 0;
    final List<dynamic> slotsInfo = liveData['slots'] ?? [];

    final Color statusColor =
        availableSlots > 0 ? Colors.green.shade700 : Colors.orange.shade800;
    final String statusText = availableSlots > 0 ? "Available" : "Likely Full";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDistance(station.distanceInMeters),
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Chip(
                label: Text(
                  statusText,
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold),
                ),
                backgroundColor: statusColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow(Icons.power_outlined, "Availability",
              "$availableSlots / $totalSlots slots free"),
          const SizedBox(height: 16),
          const Text("Charger Types:",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 8),
          if (slotsInfo.isEmpty) const Text("  • No charger info available"),
          ...slotsInfo.map((slot) => Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text('• ${slot['chargerType']} (${slot['powerKw']} kW)',
                    style: const TextStyle(fontSize: 15)),
              )),
          const Divider(height: 32),
          _buildAmenities(liveData),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation_outlined),
              label: const Text("Get Directions"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final lat = liveData['latitude'];
                final lng = liveData['longitude'];
                if (lat != null && lng != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveMapPage(
                        email: email,
                        destination: LatLng(lat, lng),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenities(Map<String, dynamic> liveData) {
    final amenities = {
      'Parking': liveData['parkingAvailable'] ?? false,
      'Restroom': liveData['restroomAvailable'] ?? false,
      'Food Nearby': liveData['foodNearby'] ?? false,
      'WiFi': liveData['wifiAvailable'] ?? false,
      'CCTV': liveData['cctvAvailable'] ?? false,
    };

    final availableAmenities =
        amenities.entries.where((e) => e.value == true).toList();

    if (availableAmenities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Amenities:",
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12.0,
          runSpacing: 8.0,
          children: availableAmenities.map((amenity) {
            return Chip(
              avatar: Icon(Icons.check_circle_outline,
                  size: 18, color: Colors.green.shade700),
              label: Text(amenity.key),
              backgroundColor: Colors.green.withOpacity(0.1),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(width: 16),
        Text('$title: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
