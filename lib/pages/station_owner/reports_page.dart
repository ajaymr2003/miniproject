// lib/pages/station_owner/reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue.shade600;
      case 'In Progress':
        return Colors.orange.shade600;
      case 'Resolved':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_open_outlined, size: 100, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'No Issues Reported',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Your submitted issue reports will appear here. Tap the + button to create a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _ownerEmail == null
            ? const Center(child: Text('Could not identify user.'))
            : StreamBuilder<QuerySnapshot>(
                // --- FIX: REMOVED .orderBy() TO AVOID THE INDEX ERROR ---
                stream: FirebaseFirestore.instance
                    .collection('issues')
                    .where('ownerEmail', isEqualTo: _ownerEmail)
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

                  // --- FIX: SORT THE RESULTS HERE, IN THE APP'S CODE ---
                  final issues = snapshot.data!.docs;
                  issues.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final Timestamp? aTimestamp = aData['reportedAt'];
                    final Timestamp? bTimestamp = bData['reportedAt'];
                    if (bTimestamp == null) return -1;
                    if (aTimestamp == null) return 1;
                    // Sorts newest first
                    return bTimestamp.compareTo(aTimestamp);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index].data() as Map<String, dynamic>;
                      final reportedAt = (issue['reportedAt'] as Timestamp?)?.toDate();
                      final adminReply = issue['adminReply'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
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
                                      issue['stationName'] ?? 'Unknown Station',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      issue['status'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: _getStatusColor(issue['status'] ?? ''),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                issue['issueCategory'] ?? 'No Category',
                                style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                              ),
                              const Divider(height: 24),
                              Text(
                                issue['description'] ?? 'No description.',
                                style: const TextStyle(fontSize: 15),
                              ),
                              if (adminReply != null && adminReply.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Admin's Reply:", style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(adminReply),
                                    ],
                                  ),
                                )
                              ],
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Reported: ${reportedAt != null ? DateFormat.yMMMd().add_jm().format(reportedAt) : "N/A"}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
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