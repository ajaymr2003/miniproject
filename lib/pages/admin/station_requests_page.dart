import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_location_page.dart';
import 'full_screen_image_page.dart';

class StationRequestsPage extends StatefulWidget {
  const StationRequestsPage({super.key});

  @override
  State<StationRequestsPage> createState() => _StationRequestsPageState();
}

class _StationRequestsPageState extends State<StationRequestsPage> {
  // --- CORE LOGIC ---

  /// Approves a station request, creating a new document in the 'stations' collection.
  Future<void> _approveRequest(DocumentSnapshot requestDoc) async {
    final requestData = requestDoc.data() as Map<String, dynamic>;
    
    // Read the slots array from the request
    final List<dynamic> slots = requestData['slots'] ?? [];
    final int totalSlots = slots.length;
    // When a station is first approved, all its slots are considered available.
    final int availableSlots = totalSlots;

    await FirebaseFirestore.instance.collection('stations').add({
      'name': requestData['stationName'],
      'address': requestData['address'],
      'latitude': requestData['latitude'],
      'longitude': requestData['longitude'],
      'ownerEmail': requestData['ownerEmail'],
      'imageUrl': requestData['imageUrl'],
      'totalRevenue': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'operatingHours': requestData['operatingHours'],
      'paymentOptions': requestData['paymentOptions'],
      'parkingAvailable': requestData['parkingAvailable'],
      'restroomAvailable': requestData['restroomAvailable'],
      'foodNearby': requestData['foodNearby'],
      'wifiAvailable': requestData['wifiAvailable'],
      'cctvAvailable': requestData['cctvAvailable'],
      // Add the new slots data structure
      'slots': requestData['slots'], 
      'totalSlots': totalSlots,
      'availableSlots': availableSlots,
    });

    // Update the request's status to 'approved'
    await requestDoc.reference.update({'status': 'approved'});
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Station approved and added!'), backgroundColor: Colors.green),
    );
  }

  /// Rejects a station request by updating its status.
  Future<void> _rejectRequest(DocumentSnapshot requestDoc) async {
    await requestDoc.reference.update({'status': 'rejected'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request rejected.'), backgroundColor: Colors.red),
    );
  }
  
  /// Navigates to a map view showing the station's location.
  void _viewOnMap(Map<String, dynamic> data) {
    final lat = data['latitude'];
    final lng = data['longitude'];
    final name = data['stationName'] ?? 'Station Location';
    if (lat != null && lng != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ViewLocationPage(latitude: lat, longitude: lng, stationName: name)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location coordinates are missing.')));
    }
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChipList(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: items.map((item) => Chip(
              avatar: Icon(Icons.payment_outlined, size: 16, color: Colors.indigo),
              label: Text(item.toString()),
              backgroundColor: Colors.indigo.withOpacity(0.1),
              side: BorderSide.none,
            )).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFacilitiesGrid(Map<String, bool> facilities) {
    final availableFacilities = facilities.entries.where((e) => e.value == true).toList();
    if (availableFacilities.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Available Facilities"),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: availableFacilities.map((entry) {
            return Chip(
              avatar: Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 18),
              label: Text(entry.key),
              backgroundColor: Colors.green.withOpacity(0.1),
              side: BorderSide.none,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Station Requests'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('station_requests').where('status', isEqualTo: 'pending').orderBy('requestedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An unexpected error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending requests found.', style: TextStyle(fontSize: 18, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final requestDoc = snapshot.data!.docs[index];
              final data = requestDoc.data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'];
              final facilities = <String, bool>{
                'Parking': (data['parkingAvailable'] ?? false) as bool,
                'Restroom': (data['restroomAvailable'] ?? false) as bool,
                'Food Nearby': (data['foodNearby'] ?? false) as bool,
                'WiFi': (data['wifiAvailable'] ?? false) as bool,
                'CCTV': (data['cctvAvailable'] ?? false) as bool,
              };
              final List<dynamic> slots = data['slots'] ?? [];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null)
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImagePage(imageUrl: imageUrl))),
                        child: Hero(
                          tag: imageUrl,
                          child: Image.network(
                            imageUrl.toString().replaceFirst('/upload/', '/upload/w_600,h_300,c_fill/'),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                            errorBuilder: (context, error, stack) => const SizedBox(height: 180, child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['stationName'] ?? 'No Name', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Submitted by: ${data['ownerEmail'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          const Divider(height: 24),
                          _buildSectionHeader("Details"),
                          _buildInfoRow(Icons.location_on_outlined, "Address", data['address'] ?? 'N/A'),
                          _buildInfoRow(Icons.access_time_outlined, "Operating Hours", data['operatingHours'] ?? 'N/A'),
                          _buildSectionHeader("Charger Slots (${slots.length} total)"),
                          if (slots.isEmpty) const Text('No slots specified.'),
                          ...slots.map((slot) => _buildInfoRow(Icons.power_outlined, slot['chargerType'] ?? 'N/A', '${slot['powerKw'] ?? 0} kW')).toList(),
                          _buildChipList("Payment Options", data['paymentOptions']),
                          _buildFacilitiesGrid(facilities),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(onPressed: () => _viewOnMap(data), icon: const Icon(Icons.map_outlined), label: const Text('View Map')),
                              Row(
                                children: [
                                  TextButton(onPressed: () => _rejectRequest(requestDoc), child: const Text('Reject', style: TextStyle(color: Colors.red))),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(onPressed: () => _approveRequest(requestDoc), icon: const Icon(Icons.check), label: const Text('Approve'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}