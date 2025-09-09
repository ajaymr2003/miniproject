import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStationPage extends StatefulWidget {
  final DocumentReference stationRef;

  const EditStationPage({super.key, required this.stationRef});

  @override
  State<EditStationPage> createState() => _EditStationPageState();
}

class _EditStationPageState extends State<EditStationPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _stationNameController;
  late TextEditingController _addressController;

  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';
  Map<String, dynamic>? _stationData;

  @override
  void initState() {
    super.initState();
    _stationNameController = TextEditingController();
    _addressController = TextEditingController();
    _loadStationData();
  }

  Future<void> _loadStationData() async {
    try {
      final doc = await widget.stationRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _stationData = data;
          _stationNameController.text = data['name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Station not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load station data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        await widget.stationRef.update({
          'name': _stationNameController.text.trim(),
          'address': _addressController.text.trim(),
          // Note: Editing slots would require a more complex UI here.
          // This is a starting point for basic edits.
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Station updated successfully!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Station'),
        backgroundColor: Colors.deepPurple.shade400,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Editing: ${_stationData?['name'] ?? 'Station'}', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _stationNameController,
                          decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Station name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                           validator: (v) => v!.isEmpty ? 'Address is required' : null,
                           maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        // Placeholder for more complex slot editing UI
                        const Text('Note: Slot editing is not yet implemented in this form.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}