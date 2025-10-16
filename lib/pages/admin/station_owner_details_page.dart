// lib/pages/admin/station_owner_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'owner_stations_page.dart';

class StationOwnerDetailsPage extends StatelessWidget {
  const StationOwnerDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar is now provided by the AdminDashboard, so we can remove it here
      // to avoid a double AppBar when used in the IndexedStack.
      // If this page were to be used standalone, you would keep the AppBar.
      backgroundColor: Colors.grey.shade100, // A lighter background for better card contrast
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Station Owner')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No station owners found.'),
            );
          }

          final owners = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: owners.length,
            itemBuilder: (context, index) {
              final ownerDoc = owners[index];
              // Use the new, styled, and data-rich card widget
              return _OwnerCard(ownerDoc: ownerDoc);
            },
          );
        },
      ),
    );
  }
}

// --- NEW WIDGET for a single owner card with station fetching logic ---
class _OwnerCard extends StatefulWidget {
  final DocumentSnapshot ownerDoc;
  const _OwnerCard({required this.ownerDoc});

  @override
  State<_OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends State<_OwnerCard> {
  bool _isLoadingStations = true;
  List<String> _stationNames = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStationNames();
  }

  Future<void> _fetchStationNames() async {
    try {
      final ownerData = widget.ownerDoc.data() as Map<String, dynamic>;
      final ownerEmail = ownerData['email'];
      if (ownerEmail == null) {
        throw Exception("Owner email is missing.");
      }

      final stationQuery = await FirebaseFirestore.instance
          .collection('stations')
          .where('ownerEmail', isEqualTo: ownerEmail)
          .limit(5) // Limit to 5 for preview, to keep it snappy
          .get();
      
      if (mounted) {
        final names = stationQuery.docs
            .map((doc) => (doc.data()['name'] ?? 'Unnamed Station') as String)
            .toList();
        setState(() {
          _stationNames = names;
          _isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not load stations.";
          _isLoadingStations = false;
        });
      }
    }
  }

  Future<void> _deleteOwner(BuildContext context, String ownerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station Owner'),
        content: Text('Are you sure you want to permanently delete "$ownerName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.ownerDoc.reference.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Station owner deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting owner: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _handleMenuSelection(String value, Map<String, dynamic> ownerData) {
    final ownerEmail = ownerData['email'] ?? '';
    final ownerName = ownerData['fullName'] ?? 'Unknown Owner';

    if (value == 'view') {
      if (ownerEmail.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OwnerStationsPage(
              ownerEmail: ownerEmail,
              ownerName: ownerName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot view stations: Owner email is missing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (value == 'delete') {
      _deleteOwner(context, ownerName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.ownerDoc.data() as Map<String, dynamic>;
    final String ownerName = owner['fullName'] ?? 'Unknown Owner';
    final String ownerEmail = owner['email'] ?? 'No Email';
    final String phoneNumber = owner['phoneNumber'] ?? 'Not provided';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Icon(Icons.business_center_outlined, color: Colors.deepPurple.shade800),
            ),
            title: Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            subtitle: Text(ownerEmail, style: TextStyle(color: Colors.grey.shade600)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleMenuSelection(value, owner),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'view',
                  child: ListTile(leading: Icon(Icons.list_alt_outlined), title: Text('View All Stations')),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete Owner', style: TextStyle(color: Colors.red))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: $phoneNumber', style: TextStyle(color: Colors.grey.shade700)),
                const Divider(height: 24),
                Text('Registered Stations:', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
                const SizedBox(height: 8),
                if (_isLoadingStations)
                  const Row(children: [SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Loading stations...')]),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (!_isLoadingStations && _stationNames.isEmpty)
                  const Text('No stations registered for this owner.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                if (!_isLoadingStations && _stationNames.isNotEmpty)
                  ..._stationNames.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Text('• $name', style: const TextStyle(fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}