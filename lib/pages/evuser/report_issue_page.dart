// lib/pages/evuser/report_issue_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _userEmail;
  String? _userName;

  List<DocumentSnapshot> _stations = [];
  DocumentSnapshot? _selectedStation;
  String? _selectedCategory;

  final List<String> _issueCategories = [
    'Charger Not Working',
    'Payment System Error',
    'Station is Closed/Inaccessible',
    'Incorrect Location or Details',
    'App Not Working Correctly',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = prefs.getString('email');

    if (_userEmail == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch user's name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userEmail).get();
      if(mounted) {
         _userName = userDoc.data()?['fullName'];
      }
     
      final stationQuery = await FirebaseFirestore.instance
          .collection('stations')
          .where('isActive', isEqualTo: true)
          .limit(20) // Limit the list to a reasonable number
          .get();
      
      if (mounted) {
        setState(() {
          _stations = stationQuery.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('issues').add({
        'reportedByEmail': _userEmail,
        'reportedByName': _userName ?? 'Unknown User',
        'stationId': _selectedStation?.id, // Optional, can be null
        'stationName': (_selectedStation?.data() as Map<String, dynamic>?)?['name'] ?? 'N/A',
        'issueCategory': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'New',
        'userType': 'EV User', // To differentiate from station owner reports
        'adminReply': null,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully! Thank you.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userEmail == null
              ? const Center(child: Text('Could not identify user.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<DocumentSnapshot>(
                          value: _selectedStation,
                          decoration: const InputDecoration(
                            labelText: 'Select Station (if applicable)',
                            border: OutlineInputBorder(),
                          ),
                          items: _stations.map((stationDoc) {
                            final stationData = stationDoc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: stationDoc,
                              child: Text(stationData['name'] ?? 'Unnamed Station'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedStation = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Issue Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _issueCategories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCategory = value);
                          },
                          validator: (value) => value == null ? 'Please select a category' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Detailed Description',
                            hintText: 'Please provide as much detail as possible...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white)
                                )
                              : const Text('Submit Report', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}