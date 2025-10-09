import 'package:flutter/material.dart';

// Mock data model for a reported issue.
// In a real app, you would fetch this from an 'issues' collection in Firestore.
class IssueModel {
  final String id;
  final String stationName;
  final String description;
  final String status; // e.g., 'New', 'In Progress', 'Resolved'
  final DateTime reportedAt;

  IssueModel({
    required this.id,
    required this.stationName,
    required this.description,
    required this.status,
    required this.reportedAt,
  });
}

class ViewIssuesPage extends StatefulWidget {
  const ViewIssuesPage({super.key});

  @override
  State<ViewIssuesPage> createState() => _ViewIssuesPageState();
}

class _ViewIssuesPageState extends State<ViewIssuesPage> {
  // In a real app, this list would be populated from a Firestore query.
  // We leave it empty to show the "zero state".
  final List<IssueModel> _issues = [];

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.red.shade400;
      case 'in progress':
        return Colors.orange.shade400;
      case 'resolved':
        return Colors.green.shade400;
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
            Icon(Icons.thumb_up_alt_outlined, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No Issues Reported',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Text(
              'Great job! There are currently no active issues reported for your stations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(IssueModel issue) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
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
                    issue.stationName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    issue.status,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(issue.status),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Description:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              issue.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reported on: ${issue.reportedAt.day}/${issue.reportedAt.month}/${issue.reportedAt.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (issue.status != 'Resolved')
                  OutlinedButton(
                    onPressed: () {
                      // In a real app, this would update the issue's status in Firestore
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marking as resolved... (demo)')),
                      );
                    },
                    child: const Text('Mark as Resolved'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reported Issues'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _issues.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _issues.length,
              itemBuilder: (context, index) {
                return _buildIssueCard(_issues[index]);
              },
            ),
    );
  }
}