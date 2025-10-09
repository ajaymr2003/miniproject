// lib/pages/station_owner/manage_stations_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'request_station_page.dart';

class ManageStationsPage extends StatefulWidget {
  const ManageStationsPage({super.key});

  @override
  State<ManageStationsPage> createState() => _ManageStationsPageState();
}

class _ManageStationsPageState extends State<ManageStationsPage> {
  String? _ownerEmail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getOwnerEmail();
  }

  Future<void> _getOwnerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownerEmail = prefs.getString('email');
      _isLoading = false;
    });
  }

  Future<void> _toggleStationStatus(DocumentReference stationRef, bool currentStatus) async {
    try {
      await stationRef.update({'isActive': !currentStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Station status updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteStation(DocumentReference stationRef, String stationName) async {
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
    // --- MODIFICATION: Removed the Scaffold and AppBar from this widget ---
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _ownerEmail == null
            ? const Center(child: Text('Could not identify user. Please log in again.'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('stations').where('ownerEmail', isEqualTo: _ownerEmail).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ev_station, color: Colors.grey.shade400, size: 80),
                          const SizedBox(height: 16),
                          Text('No Stations Found', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          const Text('You have not added any stations yet.', style: TextStyle(color: Color.fromARGB(255, 109, 80, 80), fontSize: 16)),
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
                      final bool isActive = station['isActive'] ?? true;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      station['name'] ?? 'Unnamed Station',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => RequestStationPage(stationToEdit: stationDoc)),
                                        );
                                      } else if (value == 'delete') {
                                        _deleteStation(stationDoc.reference, station['name'] ?? 'this station');
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit')),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red))),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                station['address'] ?? 'No address provided',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Icon(
                                    Icons.power_settings_new_rounded,
                                    color: isActive ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${station['availableSlots'] ?? 0} / ${station['totalSlots'] ?? 0} slots available',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                title: const Text('Station is Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: Text(isActive ? 'Visible to users' : 'Hidden from users (maintenance)', style: const TextStyle(fontSize: 12)),
                                value: isActive,
                                onChanged: (newValue) => _toggleStationStatus(stationDoc.reference, isActive),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
  }
}