// lib/pages/evuser/history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserEmail();
  }

  Future<void> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getString('email');
      _isLoading = false;
    });
  }

  // --- MODIFIED: This method now just handles the deletion and snackbar ---
  void _performDelete(DocumentSnapshot sessionDoc) {
    final docId = sessionDoc.id;
    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    final stationName = sessionData['stationName'] ?? 'Session';

    FirebaseFirestore.instance
        .collection('navigation_history')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$stationName history deleted.'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('navigation_history')
                  .doc(docId)
                  .set(sessionData);
            },
          ),
        ),
      );
    }
  }

  // --- NEW METHOD: To show confirmation dialog before deleting ---
  Future<void> _confirmAndDelete(DocumentSnapshot sessionDoc) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this history record? This action cannot be undone immediately.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _performDelete(sessionDoc);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No History Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed charging sessions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Timestamp? startTime, Timestamp? endTime) {
    if (startTime == null || endTime == null) {
      return 'N/A';
    }
    final duration = endTime.toDate().difference(startTime.toDate());
    if (duration.inMinutes < 1) {
      return '< 1 min';
    }
    return '${duration.inMinutes} min';
  }

  String _formatChargeAmount(num? start, num? end) {
    if (start == null || end == null) {
      return 'N/A';
    }
    return '${start.toInt()}% → ${end.toInt()}%';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_email == null) {
      return const Center(child: Text('Could not identify user.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('navigation_history')
          .where('email', isEqualTo: _email)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final sessions = snapshot.data!.docs;

        sessions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp? aTimestamp = aData['endedAt'];
          final Timestamp? bTimestamp = bData['endedAt'];

          if (bTimestamp == null) return -1;
          if (aTimestamp == null) return 1;

          return bTimestamp.compareTo(aTimestamp);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final sessionDoc = sessions[index];
            final session = sessionDoc.data() as Map<String, dynamic>;
            final stationName = session['stationName'] ?? 'Unknown Station';
            final endedAt = (session['endedAt'] as Timestamp?)?.toDate();

            final chargingStartedAt =
                session['chargingStartedAt'] as Timestamp?;
            final chargingEndedAt = session['chargingEndedAt'] as Timestamp?;
            final batteryStart = session['batteryLevelAtStart'] as num?;
            final batteryEnd = session['batteryLevelAtEnd'] as num?;
            final chargeAmount = (batteryEnd ?? 0) - (batteryStart ?? 0);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.ev_station, color: Colors.blue.shade800),
                ),
                title: Text(
                  stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endedAt != null
                          ? DateFormat.yMMMd().add_jm().format(endedAt)
                          : 'Date unknown',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.power,
                            color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatChargeAmount(batteryStart, batteryEnd),
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87),
                        ),
                        if (chargeAmount > 0)
                          Text(
                            ' (+${chargeAmount.toInt()}%)',
                            style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        const Spacer(),
                        Icon(Icons.timer_outlined,
                            color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(chargingStartedAt, chargingEndedAt),
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
                // --- MODIFICATION: Replaced trailing icon with a delete button ---
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  tooltip: 'Delete',
                  onPressed: () => _confirmAndDelete(sessionDoc),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Viewing details for $stationName')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
