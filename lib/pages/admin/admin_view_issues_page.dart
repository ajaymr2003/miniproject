// lib/pages/admin/admin_view_issues_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminViewIssuesPage extends StatefulWidget {
  const AdminViewIssuesPage({super.key});

  @override
  State<AdminViewIssuesPage> createState() => _AdminViewIssuesPageState();
}

class _AdminViewIssuesPageState extends State<AdminViewIssuesPage> {
  Future<void> _showReplyDialog(DocumentReference issueRef, String currentReply) async {
    final replyController = TextEditingController(text: currentReply);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Reply'),
        content: TextField(
          controller: replyController,
          decoration: const InputDecoration(
            hintText: 'Type your reply to the station owner...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await issueRef.update({'adminReply': replyController.text.trim()});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateStatus(DocumentReference issueRef, String newStatus) async {
    final updateData = <String, dynamic>{'status': newStatus};
    if (newStatus == 'Resolved') {
      updateData['resolvedAt'] = FieldValue.serverTimestamp();
    }
    await issueRef.update(updateData);
    if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to "$newStatus"')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.blue.shade600;
      case 'In Progress': return Colors.orange.shade600;
      case 'Resolved': return Colors.green.shade600;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // --- FIX: This query now fetches ALL issues without sorting ---
        stream: FirebaseFirestore.instance.collection('issues').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No issues have been reported yet.'));
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
            return bTimestamp.compareTo(aTimestamp);
          });
          
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: issues.length,
            itemBuilder: (context, index) {
              final issueDoc = issues[index];
              final issue = issueDoc.data() as Map<String, dynamic>;
              final reportedAt = (issue['reportedAt'] as Timestamp?)?.toDate();
              final adminReply = issue['adminReply'] as String? ?? '';
              final currentStatus = issue['status'] ?? 'Unknown';

              // --- NEW LOGIC TO HANDLE BOTH USER TYPES ---
              final bool isFromOwner = issue['userType'] != 'EV User';
              final String reporterEmail = isFromOwner ? (issue['ownerEmail'] ?? 'N/A') : (issue['reportedByEmail'] ?? 'N/A');
              final String reporterName = isFromOwner ? (issue['ownerName'] ?? 'Owner') : (issue['reportedByName'] ?? 'EV User');
              final String stationName = issue['stationName'] ?? 'Station not specified';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                              issue['issueCategory'] ?? 'General Issue', 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                          ),
                          Chip(
                            avatar: Icon(isFromOwner ? Icons.business_center : Icons.person),
                            label: Text(isFromOwner ? 'Owner' : 'EV User'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Station: $stationName', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
                      Text('From: $reporterName ($reporterEmail)', style: TextStyle(color: Colors.grey.shade600)),
                      const Divider(height: 24),
                      Text(issue['description'] ?? 'No description.'),
                      if(adminReply.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Your reply: "$adminReply"', style: TextStyle(color: Colors.blue.shade800, fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 16),
                      Text('Reported: ${reportedAt != null ? DateFormat.yMMMd().format(reportedAt) : "N/A"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (newStatus) => _updateStatus(issueDoc.reference, newStatus),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'New', child: Text('Mark as New')),
                              const PopupMenuItem(value: 'In Progress', child: Text('Mark as In Progress')),
                              const PopupMenuItem(value: 'Resolved', child: Text('Mark as Resolved')),
                            ],
                            child: Chip(
                              label: Text(currentStatus, style: const TextStyle(color: Colors.white)),
                              backgroundColor: _getStatusColor(currentStatus),
                              avatar: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showReplyDialog(issueDoc.reference, adminReply),
                            child: const Text('Reply'),
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