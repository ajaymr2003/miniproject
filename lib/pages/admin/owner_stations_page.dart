import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_station_page.dart';

class OwnerStationsPage extends StatelessWidget {
  final String ownerEmail;
  final String ownerName;

  const OwnerStationsPage({
    super.key,
    required this.ownerEmail,
    required this.ownerName,
  });

  Widget _buildStationDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 12),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _deleteStation(BuildContext context, DocumentReference stationRef, String stationName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete "$stationName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await stationRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$stationName" has been deleted.'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting station: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$ownerName's Stations"), backgroundColor: Colors.deepPurple.shade400, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stations').where('ownerEmail', isEqualTo: ownerEmail).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ev_station, color: Colors.grey.shade400, size: 80),
                  const SizedBox(height: 16),
                  Text('No Stations Found', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text('$ownerName has not registered any stations yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            );
          }

          final stations = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final stationDoc = stations[index];
              final station = stationDoc.data() as Map<String, dynamic>;
              final String stationName = station['name'] ?? 'Unnamed Station';
              final String address = station['address'] ?? 'No Address';
              final String? imageUrl = station['imageUrl'];
              final List<dynamic> slots = station['slots'] ?? [];
              final int totalSlots = station['totalSlots'] ?? slots.length;
              final int availableSlots = station['availableSlots'] ?? slots.where((s) => s['isAvailable'] == true).length;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                        loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (c, e, s) => const SizedBox(height: 150, child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stationName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(height: 20),
                          _buildStationDetailRow(Icons.location_on_outlined, "Address", address),
                          _buildStationDetailRow(Icons.power_settings_new_rounded, "Availability", "$availableSlots / $totalSlots slots free"),
                          const SizedBox(height: 8),
                          const Text('Chargers:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...slots.map((slot) => Padding(padding: const EdgeInsets.only(left: 8.0, top: 4.0), child: Text('• ${slot['chargerType']} (${slot['powerKw']} kW)'))).toList(),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                                style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditStationPage(stationRef: stationDoc.reference)));
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () => _deleteStation(context, stationDoc.reference, stationName),
                              ),
                            ],
                          )
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