import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/features/search/search_screen.dart';

import '../services/location_service.dart';

class CurrentLocationMap extends StatefulWidget {
  const CurrentLocationMap({super.key});

  @override
  State<CurrentLocationMap> createState() =>
      _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  static const LatLng _fallbackLocation = LatLng(37.5665, 126.9780);

  final LocationService _locationService = const LocationService();
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _moveToCurrentLocation() async {
    final location = await _locationService.getForegroundLocation();
    if (!mounted || location == null || _controller == null) return;

    await _animateCameraTo(location);
  }

  Future<void> _animateCameraTo(LatLng target) async {
    if (_controller == null) return;

    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => const SearchScreen(),
          ),
        );

    if (!mounted) return;

    final LatLng? latLng = result?['latLng'] as LatLng?;
    if (latLng != null) {
      await _animateCameraTo(latLng);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _fallbackLocation,
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (controller) {
            _controller = controller;
            _moveToCurrentLocation();
          },
        ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    readOnly: true,
                    onTap: _openSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '장소를 입력해주세요.',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
