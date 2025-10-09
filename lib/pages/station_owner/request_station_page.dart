import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_cropper/image_cropper.dart';

class ChargerSlot {
  String chargerType;
  final TextEditingController powerController;
  ChargerSlot({this.chargerType = 'Type 2', required this.powerController});
}

class RequestStationPage extends StatefulWidget {
  // If this is provided, the page will be in "Edit Mode"
  final DocumentSnapshot? stationToEdit;

  const RequestStationPage({super.key, this.stationToEdit});
  
  @override
  State<RequestStationPage> createState() => _RequestStationPageState();
}

class _RequestStationPageState extends State<RequestStationPage> {
  // --- STATE ---
  final _formKey = GlobalKey<FormState>();
  final _stationNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  final List<ChargerSlot> _chargerSlots = [];
  String _selectedOperatingHours = '24x7';
  final Set<String> _paymentOptions = {};
  bool _parkingAvailable = false;
  bool _restroomAvailable = false;
  bool _foodNearby = false;
  bool _wifiAvailable = false;
  bool _cctvAvailable = false;
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  final LatLng _initialCenter = const LatLng(12.9716, 77.5946);
  Timer? _debounce;
  File? _imageFile;
  String? _imageUrl;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();
  final cloudinary = CloudinaryPublic('dtcsadykn', 'ml_default', cache: false);
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.stationToEdit != null;
    _searchController.addListener(_onSearchChanged);
    
    if (_isEditMode) {
      _populateFieldsForEdit();
    } else {
      _addChargerSlot(); // Add one default slot for new stations
    }
  }

  void _populateFieldsForEdit() {
    final data = widget.stationToEdit!.data() as Map<String, dynamic>;

    _stationNameController.text = data['name'] ?? '';
    _addressController.text = data['address'] ?? '';
    if (data['latitude'] != null && data['longitude'] != null) {
      _selectedLocation = LatLng(data['latitude'], data['longitude']);
    }
    _imageUrl = data['imageUrl']; // Existing image
    
    // Operating Hours logic
    final hours = data['operatingHours'] ?? '24x7';
    const standardHours = ['24x7', '6 AM - 11 PM', '9 AM - 6 PM'];
    if (standardHours.contains(hours)) {
      _selectedOperatingHours = hours;
    } else {
      _selectedOperatingHours = 'Other (Specify)';
      _operatingHoursController.text = hours;
    }
    
    _paymentOptions.addAll(List<String>.from(data['paymentOptions'] ?? []));
    _parkingAvailable = data['parkingAvailable'] ?? false;
    _restroomAvailable = data['restroomAvailable'] ?? false;
    _foodNearby = data['foodNearby'] ?? false;
    _wifiAvailable = data['wifiAvailable'] ?? false;
    _cctvAvailable = data['cctvAvailable'] ?? false;
    
    // Charger Slots
    final List<dynamic> slotsData = data['slots'] ?? [];
    if (slotsData.isNotEmpty) {
      for (var slotMap in slotsData) {
        _chargerSlots.add(ChargerSlot(
          chargerType: slotMap['chargerType'] ?? 'Type 2',
          powerController: TextEditingController(text: (slotMap['powerKw'] ?? '').toString()),
        ));
      }
    } else {
      _addChargerSlot(); // Add a default if none exist
    }

    setState(() {}); // Trigger a rebuild with populated data
  }


  @override
  void dispose() {
    _stationNameController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _operatingHoursController.dispose();
    for (var slot in _chargerSlots) {
      slot.powerController.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      maxWidth: 1200,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop Station Photo', toolbarColor: Colors.blueAccent, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.ratio16x9, lockAspectRatio: true),
        IOSUiSettings(title: 'Crop Station Photo', aspectRatioLockEnabled: true, aspectRatioPickerButtonHidden: true, resetAspectRatioEnabled: false),
      ],
    );

    if (croppedFile == null) return;
    setState(() {
      _imageFile = File(croppedFile.path);
      _isUploadingImage = true;
      _imageUrl = null;
    });

    try {
      CloudinaryResponse response = await cloudinary.uploadFile(CloudinaryFile.fromFile(croppedFile.path, resourceType: CloudinaryResourceType.Image));
      setState(() {
        _imageUrl = response.secureUrl;
        _isUploadingImage = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green));
    } on CloudinaryException catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: ${e.message}'), backgroundColor: Colors.red));
    }
  }

  void _addChargerSlot() {
    setState(() {
      _chargerSlots.add(ChargerSlot(powerController: TextEditingController()));
    });
  }

  void _removeChargerSlot(int index) {
    setState(() {
      _chargerSlots[index].powerController.dispose();
      _chargerSlots.removeAt(index);
    });
  }

  // --- COMBINED SUBMIT FUNCTION ---
  Future<void> _submitForm() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location on the map.'), backgroundColor: Colors.red));
      return;
    }
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a photo.'), backgroundColor: Colors.red));
      return;
    }
    if (_chargerSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one charging slot.'), backgroundColor: Colors.red));
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_isEditMode) {
        await _updateStation();
      } else {
        await _createRequest();
      }
    }
  }

  // --- LOGIC FOR UPDATING AN EXISTING STATION ---
  Future<void> _updateStation() async {
    setState(() => _isSubmitting = true);
    
    final List<Map<String, dynamic>> slotsData = _chargerSlots.map((slot) {
      return {'chargerType': slot.chargerType, 'powerKw': double.tryParse(slot.powerController.text) ?? 0, 'isAvailable': true};
    }).toList();

    try {
      await widget.stationToEdit!.reference.update({
        'name': _stationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'imageUrl': _imageUrl,
        'operatingHours': _selectedOperatingHours == 'Other (Specify)' ? _operatingHoursController.text.trim() : _selectedOperatingHours,
        'paymentOptions': _paymentOptions.toList(),
        'parkingAvailable': _parkingAvailable,
        'restroomAvailable': _restroomAvailable,
        'foodNearby': _foodNearby,
        'wifiAvailable': _wifiAvailable,
        'cctvAvailable': _cctvAvailable,
        'slots': slotsData,
        'totalSlots': slotsData.length,
        // Note: availableSlots might need more complex logic if some are in use
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update station: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- LOGIC FOR CREATING A NEW STATION REQUEST ---
  Future<void> _createRequest() async {
    setState(() => _isSubmitting = true);
      
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerEmail = prefs.getString('email');
      if (ownerEmail == null) throw Exception("User not logged in");

      final List<Map<String, dynamic>> slotsData = _chargerSlots.map((slot) {
        return {'chargerType': slot.chargerType, 'powerKw': double.tryParse(slot.powerController.text) ?? 0, 'isAvailable': true};
      }).toList();

      await FirebaseFirestore.instance.collection('station_requests').add({
        'stationName': _stationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'ownerEmail': ownerEmail,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'imageUrl': _imageUrl,
        'operatingHours': _selectedOperatingHours == 'Other (Specify)' ? _operatingHoursController.text.trim() : _selectedOperatingHours,
        'paymentOptions': _paymentOptions.toList(),
        'parkingAvailable': _parkingAvailable,
        'restroomAvailable': _restroomAvailable,
        'foodNearby': _foodNearby,
        'wifiAvailable': _wifiAvailable,
        'cctvAvailable': _cctvAvailable,
        'slots': slotsData, 
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station request submitted successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  
  // All other helper methods (_getCurrentLocationAndMoveMap, _searchAndMoveMap, etc.) remain unchanged...
  Future<void> _getCurrentLocationAndMoveMap() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text('To use this feature, please enable location services in your device settings.'),
            actions: <Widget>[
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
        setState(() => _isGettingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');
      Position position = await Geolocator.getCurrentPosition();
      final newPoint = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _selectedLocation = newPoint);
        _mapController.move(newPoint, 15.0);
        await _updateAddressFromLocation(newPoint);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () {
      if (_searchController.text.isNotEmpty) _searchAndMoveMap();
    });
  }

  Future<void> _searchAndMoveMap() async {
    try {
      List<Location> locations = await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty && mounted) {
        final foundLocation = locations.first;
        final newPoint = LatLng(foundLocation.latitude, foundLocation.longitude);
        setState(() => _selectedLocation = newPoint);
        _mapController.move(newPoint, 15.0);
        _updateAddressFromLocation(newPoint);
      }
    } catch (e) { print("Geocoding error: $e"); }
  }

  Future<void> _updateAddressFromLocation(LatLng point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [p.name, p.street, p.locality, p.postalCode, p.country].where((e) => e != null && e.isNotEmpty).join(', ');
        _addressController.text = address;
      }
    } catch (e) { print("Error getting address: $e"); }
  }

  void _handleMapTap(LatLng tappedPoint) {
    setState(() => _selectedLocation = tappedPoint);
    _updateAddressFromLocation(tappedPoint);
  }
  
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(top: 24.0, bottom: 16.0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)));

  Widget _buildMultiSelectChip(String title, Set<String> selectedSet, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: options.map((option) {
            final isSelected = selectedSet.contains(option);
            return FilterChip(
              label: Text(option), selected: isSelected,
              onSelected: (selected) {
                setState(() { if (selected) selectedSet.add(option); else selectedSet.remove(option); });
              },
              selectedColor: Colors.blueAccent.withOpacity(0.2), checkmarkColor: Colors.blueAccent,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC UI ---
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Station' : 'Request New Station'),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('1. Location & Photo'),
              TextFormField(controller: _searchController, decoration: const InputDecoration(labelText: 'Search Location', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
              const SizedBox(height: 16),
              Container(
                height: 250,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _selectedLocation ?? _initialCenter, initialZoom: _isEditMode ? 15.0 : 14.0, onTap: (tapPosition, point) => _handleMapTap(point)),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                        if (_selectedLocation != null) MarkerLayer(markers: [Marker(width: 80.0, height: 80.0, point: _selectedLocation!, child: const Icon(Icons.location_on, color: Colors.red, size: 45))]),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10, bottom: 10,
                    child: FloatingActionButton.small(
                      onPressed: _isGettingLocation ? null : _getCurrentLocationAndMoveMap,
                      backgroundColor: Colors.blueAccent,
                      child: _isGettingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)) : const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                height: 150, width: double.infinity, 
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)), 
                child: _imageFile != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(_imageFile!, fit: BoxFit.cover)) 
                  : (_imageUrl != null 
                      ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.network(_imageUrl!, fit: BoxFit.cover))
                      : const Center(child: Text('No image selected.')))
              ),
              const SizedBox(height: 8),
              Center(child: _isUploadingImage ? const CircularProgressIndicator() : ElevatedButton.icon(onPressed: _pickAndUploadImage, icon: const Icon(Icons.camera_alt), label: Text(_imageFile == null && _imageUrl == null ? 'Select Photo' : 'Change Photo'))),
              _buildSectionHeader('2. Basic Information'),
              TextFormField(controller: _stationNameController, decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'This field is required' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Full Address (Auto-filled)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'This field is required' : null, maxLines: 2),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOperatingHours,
                decoration: const InputDecoration(labelText: 'Operating Hours', border: OutlineInputBorder()),
                items: ['24x7', '6 AM - 11 PM', '9 AM - 6 PM', 'Other (Specify)'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (v) { if (v != null) setState(() => _selectedOperatingHours = v); },
              ),
              if (_selectedOperatingHours == 'Other (Specify)')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextFormField(
                    controller: _operatingHoursController,
                    decoration: const InputDecoration(labelText: 'Specify Custom Hours', border: OutlineInputBorder()),
                    validator: (v) => (_selectedOperatingHours == 'Other (Specify)' && (v == null || v.isEmpty)) ? 'Please specify the hours' : null,
                  ),
                ),
              _buildSectionHeader('3. Charger Slots'),
              if (_chargerSlots.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Please add at least one charger slot.'))),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _chargerSlots.length,
                itemBuilder: (context, index) {
                  final slot = _chargerSlots[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Slot ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (_chargerSlots.length > 1) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeChargerSlot(index)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: slot.chargerType,
                            decoration: const InputDecoration(labelText: 'Charger Type', border: OutlineInputBorder()),
                            items: ['Type 2', 'CCS', 'CHAdeMO', 'AC Fast', 'DC Fast', 'Bharat DC-001'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) { if (v != null) setState(() => slot.chargerType = v); },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: slot.powerController,
                            decoration: const InputDecoration(labelText: 'Power Output (kW)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(child: TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add Another Slot'), onPressed: _addChargerSlot)),
              _buildSectionHeader('4. Payment & Facilities'),
              _buildMultiSelectChip('Payment Options', _paymentOptions, ['UPI', 'Card', 'Wallet', 'RFID']),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text('Parking Available'), value: _parkingAvailable, onChanged: (val) => setState(() => _parkingAvailable = val)),
              SwitchListTile(title: const Text('Restroom / Waiting Area'), value: _restroomAvailable, onChanged: (val) => setState(() => _restroomAvailable = val)),
              SwitchListTile(title: const Text('Shops / Food Nearby'), value: _foodNearby, onChanged: (val) => setState(() => _foodNearby = val)),
              SwitchListTile(title: const Text('WiFi Available'), value: _wifiAvailable, onChanged: (val) => setState(() => _wifiAvailable = val)),
              SwitchListTile(title: const Text('CCTV Security'), value: _cctvAvailable, onChanged: (val) => setState(() => _cctvAvailable = val)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isSubmitting ? null : _submitForm, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(_isEditMode ? 'Update Station' : 'Submit Request', style: TextStyle(fontSize: 16)))),
            ],
          ),
        ),
      ),
    );
  }
}