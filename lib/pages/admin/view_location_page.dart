import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ViewLocationPage extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String stationName;

  const ViewLocationPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.stationName,
  });

  @override
  Widget build(BuildContext context) {
    final location = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(stationName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: location,
                child: const Tooltip(
                  message: 'Requested Location',
                  child: Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}