import 'package:flutter/material.dart';
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
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(37.5665, 126.9780),
        zoom: 14,
      ),
    );
  }
}
