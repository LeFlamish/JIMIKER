import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Research extends StatelessWidget {
  const Research({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _GoogleMap());
  }
}

class _GoogleMap extends StatelessWidget {
  const _GoogleMap({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CurrentLocationMap();
  }
}

class _CurrentLocationMap extends StatefulWidget {
  const _CurrentLocationMap();

  @override
  State<_CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<_CurrentLocationMap> {
  late final Future<LatLng> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _resolveCurrentLocation();
  }

  Future<LatLng> _resolveCurrentLocation() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      return const LatLng(37.5665, 126.9780);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LatLng(37.5665, 126.9780);
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng>(
      future: _locationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final target = snapshot.data ?? const LatLng(37.5665, 126.9780);

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: 15,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        );
      },
    );
  }
}