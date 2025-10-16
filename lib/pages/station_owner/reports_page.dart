// lib/pages/station_owner/reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? _ownerEmail;
  bool _isLoading = true;
  late Future<List<DocumentSnapshot>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _getOwnerEmailAndStations();
  }

  Future<void> _getOwnerEmailAndStations() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email != null) {
      setState(() {
        _ownerEmail = email;
        _stationsFuture = FirebaseFirestore.instance
            .collection('stations')
            .where('ownerEmail', isEqualTo: _ownerEmail)
            .get()
            .then((snapshot) => snapshot.docs);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ownerEmail == null) {
      return const Center(child: Text('Could not identify user. Please log in again.'));
    }

    return FutureBuilder<List<DocumentSnapshot>>(
      future: _stationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading stations: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'You have no active stations to manage.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final stations = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final stationDoc = stations[index];
            return _StationStatusCard(stationDoc: stationDoc);
          },
        );
      },
    );
  }
}

class _StationStatusCard extends StatelessWidget {
  final DocumentSnapshot stationDoc;

  const _StationStatusCard({required this.stationDoc});

  @override
  Widget build(BuildContext context) {
    final stationData = stationDoc.data() as Map<String, dynamic>;
    final stationId = stationDoc.id;
    final stationName = stationData['name'] ?? 'Unknown Station';
    final address = stationData['address'] ?? 'No address provided';
    final List<dynamic> slotsMetadata = stationData['slots'] ?? [];

    final stationStatusRef = FirebaseDatabase.instance.ref('station_status/$stationId');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stationName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(address, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 24),
            const Text('Live Slot Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (slotsMetadata.isEmpty)
              const Text('No slots configured for this station.'),
            // Use a StreamBuilder to get the live status from RTDB
            StreamBuilder<DatabaseEvent>(
              stream: stationStatusRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Text('Loading slot status...');
                }

                final liveStatuses = snapshot.data!.snapshot.value;
                List<bool> slotStatuses = [];
                if (liveStatuses is List) {
                  slotStatuses = liveStatuses.map((s) => s as bool).toList();
                }

                // Build a list of SwitchListTiles, one for each slot
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: slotsMetadata.length,
                  itemBuilder: (context, index) {
                    final slotInfo = slotsMetadata[index] as Map<String, dynamic>;
                    final chargerType = slotInfo['chargerType'] ?? 'Charger';
                    final powerKw = slotInfo['powerKw'] ?? 0;
                    
                    // The current status from RTDB, defaulting to false if not available
                    final isAvailable = (index < slotStatuses.length) ? slotStatuses[index] : false;

                    return SwitchListTile(
                      title: Text('Slot ${index + 1}: $chargerType'),
                      subtitle: Text('$powerKw kW - ${isAvailable ? "Available" : "In Use / Disabled"}'),
                      value: isAvailable,
                      onChanged: (bool newValue) {
                        // When the switch is toggled, update the value in RTDB at the specific index
                        stationStatusRef.child(index.toString()).set(newValue);
                      },
                      secondary: Icon(
                        Icons.power,
                        color: isAvailable ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}