import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- 1. IMPORT REALTIME DATABASE PACKAGE ---
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EVUserSetup extends StatefulWidget {
  final String email;
  const EVUserSetup({super.key, required this.email});

  @override
  _EVUserSetupState createState() => _EVUserSetupState();
}

class _EVUserSetupState extends State<EVUserSetup> {
  int _step = 0;
  String? selectedBrand;
  String? selectedVariant;

  List<String> brands = [];
  List<String> variants = [];

  bool _loadingBrands = true;
  bool _loadingVariants = false;

  @override
  void initState() {
    super.initState();
    _fetchBrands();
  }

  // --- 2. ADD HELPER FUNCTION (for consistency) ---
  String _encodeEmailForRtdb(String email) {
    return email.replaceAll('.', ',');
  }

  Future<void> _fetchBrands() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('vehicle_models').get();
      if (!mounted) return;
      setState(() {
        brands = snapshot.docs.map((doc) => doc.id).toList();
        _loadingBrands = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBrands = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load brands: $e')));
    }
  }

  Future<void> _fetchVariants(String brand) async {
    setState(() {
      _loadingVariants = true;
      variants = [];
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('vehicle_models')
          .doc(brand)
          .get();

      final data = doc.data();
      final List<dynamic> arr = (data?['variants'] ?? []) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        variants = arr.map((e) => e.toString()).toList();
        _loadingVariants = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVariants = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load variants: $e')));
    }
  }

  // =========================================================================
  // --- 3. MODIFIED FUNCTION: Write to both Firestore and RTDB ---
  // =========================================================================
  Future<void> _completeSetup() async {
    String email = widget.email;
    if (email.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      email = prefs.getString('email') ?? '';
    }
    
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save setup: Email is missing')),
        );
      }
      return;
    }
    try {
      // --- Write to Firestore (permanent user profile) ---
      // This part remains the same.
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'brand': selectedBrand,
        'variant': selectedVariant,
        'setupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // --- Write to Realtime Database (initializes the live data node) ---
      final rtdbRef = FirebaseDatabase.instance
          .ref('vehicles/${_encodeEmailForRtdb(email)}');
      await rtdbRef.set({
        'email': email,
        'brand': selectedBrand,
        'variant': selectedVariant,
        'isRunning': false, // Default "at rest" state
        'batteryLevel': 100,  // Default "at rest" state
      });

      if (mounted) {
        Navigator.of(context).pop(true); // return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save setup: $e')));
      }
    }
  }

  void _nextStep() {
    if (_step == 0 && selectedBrand != null) {
      _fetchVariants(selectedBrand!);
      setState(() => _step = 1);
    } else if (_step == 1 && selectedVariant != null) {
      _completeSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  _step == 0 ? 'Select Brand' : 'Select Variant',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _step == 0 ? _buildBrandStep() : _buildVariantStep(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_step == 0 && selectedBrand != null) ||
                      (_step == 1 && selectedVariant != null)
                  ? _nextStep
                  : null,
              child: Text(_step == 0 ? 'Next' : 'Finish'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandStep() {
    if (_loadingBrands) {
      return const Center(child: CircularProgressIndicator());
    }
    if (brands.isEmpty) {
      return const Center(child: Text('No brands found'));
    }
    return ListView.builder(
      key: const ValueKey('brandStep'),
      itemCount: brands.length,
      itemBuilder: (context, index) {
        final b = brands[index];
        final selected = selectedBrand == b;
        return ListTile(
          title: Text(b),
          trailing: selected ? const Icon(Icons.check_circle) : null,
          selected: selected,
          onTap: () => setState(() => selectedBrand = b),
        );
      },
    );
  }

  Widget _buildVariantStep() {
    if (_loadingVariants) {
      return const Center(child: CircularProgressIndicator());
    }
    if (variants.isEmpty) {
      return const Center(child: Text('No variants found for this brand'));
    }
    return ListView.builder(
      key: const ValueKey('variantStep'),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final v = variants[index];
        final selected = selectedVariant == v;
        return ListTile(
          title: Text(v),
          trailing: selected ? const Icon(Icons.check_circle) : null,
          selected: selected,
          onTap: () => setState(() => selectedVariant = v),
        );
      },
    );
  }
}