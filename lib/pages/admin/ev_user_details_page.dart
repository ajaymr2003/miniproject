import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class EvUserDetailsPage extends StatelessWidget {
  const EvUserDetailsPage({super.key});

  // Function to toggle user status
  Future<void> _toggleUserStatus(BuildContext context, DocumentReference userRef, bool newStatus, String userName) async {
    try {
      await userRef.update({'isActive': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? '$userName has been activated.' : '$userName has been deactivated.'),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EV User Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'EV User')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No EV users found.'));
          }

          final users = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final user = userDoc.data() as Map<String, dynamic>;
              
              final String fullName = user['fullName'] ?? 'Unknown User';
              final String email = user['email'] ?? 'No Email';
              final String phone = user['phoneNumber'] ?? 'Not Provided';
              final String vehicleMake = user['brand'] ?? '';
              final String vehicleModel = user['variant'] ?? '';
              final String vehicleInfo = (vehicleMake.isNotEmpty || vehicleModel.isNotEmpty)
                  ? '$vehicleMake $vehicleModel'.trim()
                  : 'Not Provided';
              
              final bool isActive = user['isActive'] ?? true;

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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            tooltip: 'Delete User',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete User'),
                                  content: Text('Are you sure you want to delete "$fullName"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await userDoc.reference.delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User deleted')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.email_outlined, "Email", email),
                      _buildDetailRow(Icons.phone_outlined, "Phone", phone),
                      _buildDetailRow(Icons.directions_car_outlined, "Vehicle", vehicleInfo),
                      const Divider(height: 24, thickness: 1),
                      _LiveVehicleData(email: email),
                      const Divider(height: 24, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Account Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (newValue) {
                              _toggleUserStatus(context, userDoc.reference, newValue, fullName);
                            },
                            activeColor: Colors.blueAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LiveVehicleData extends StatefulWidget {
  final String email;
  const _LiveVehicleData({required this.email});

  @override
  State<_LiveVehicleData> createState() => _LiveVehicleDataState();
}

class _LiveVehicleDataState extends State<_LiveVehicleData> {
  int? _batteryLevel;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVehicleData();
  }

  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  Future<void> _fetchVehicleData() async {
    try {
      final ref = FirebaseDatabase.instance.ref('vehicles/${_encodeEmailForRtdb(widget.email)}');
      final snapshot = await ref.get();

      if (mounted) {
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            _batteryLevel = data['batteryLevel'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = "No live data available.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load live data.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Row(
        children: [
          SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text("Loading live status...", style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_error != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Text(_error!, style: TextStyle(color: Colors.orange.shade800)),
        ],
      );
    }
    
    IconData batteryIcon = Icons.battery_std;
    Color batteryColor = Colors.grey;
    if (_batteryLevel != null) {
      if (_batteryLevel! > 80) {
        batteryIcon = Icons.battery_full;
        batteryColor = Colors.green.shade600;
      } else if (_batteryLevel! > 30) {
        batteryIcon = Icons.battery_5_bar;
        batteryColor = Colors.blueAccent;
      } else {
        batteryIcon = Icons.battery_alert;
        batteryColor = Colors.redAccent;
      }
    }

    return Row(
      children: [
        Icon(batteryIcon, color: batteryColor, size: 20),
        const SizedBox(width: 12),
        const Text(
          'Battery: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        Text(
          '${_batteryLevel ?? 'N/A'}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: batteryColor,
          ),
        ),
      ],
    );
  }
}