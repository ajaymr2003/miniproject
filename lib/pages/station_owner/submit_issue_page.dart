// lib/pages/station_owner/submit_issue_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubmitIssuePage extends StatefulWidget {
  const SubmitIssuePage({super.key});

  @override
  State<SubmitIssuePage> createState() => _SubmitIssuePageState();
}

class _SubmitIssuePageState extends State<SubmitIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _ownerEmail;
  String? _ownerName;

  List<DocumentSnapshot> _stations = [];
  DocumentSnapshot? _selectedStation;
  String? _selectedCategory;

  final List<String> _issueCategories = [
    'Charger Not Working',
    'Payment System Error',
    'Physical Damage',
    'Location Info Incorrect',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _ownerEmail = prefs.getString('email');

    if (_ownerEmail == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch owner's name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_ownerEmail).get();
      _ownerName = userDoc.data()?['fullName'];

      // Fetch owner's stations
      final stationQuery = await FirebaseFirestore.instance
          .collection('stations')
          .where('ownerEmail', isEqualTo: _ownerEmail)
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
        'ownerEmail': _ownerEmail,
        'ownerName': _ownerName ?? 'Unknown Owner',
        'stationId': _selectedStation!.id,
        'stationName': (_selectedStation!.data() as Map<String, dynamic>)['name'],
        'issueCategory': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'New',
        'adminReply': null,
        'resolvedAt': null,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully!'), backgroundColor: Colors.green),
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
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ownerEmail == null
              ? const Center(child: Text('Could not identify user.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_stations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'You must have at least one approved station to submit a report.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          DropdownButtonFormField<DocumentSnapshot>(
                            value: _selectedStation,
                            decoration: const InputDecoration(
                              labelText: 'Select Station',
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
                            validator: (value) => value == null ? 'Please select a station' : null,
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
                          onPressed: _isSubmitting || _stations.isEmpty ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Submit Report', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}