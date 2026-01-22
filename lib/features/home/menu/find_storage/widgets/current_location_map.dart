import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/reservation_card.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/storage_bottom_sheet.dart';
import 'package:jimiker/features/search/search_screen.dart';

import '../../../../../data/models/storage.dart';
import '../../../../../data/models/zone.dart';
import '../../../../../services/auth_providers.dart';
import '../../../../draw/draw_provider.dart';
import '../../../../draw/structure_screen.dart';
import '../../../../draw/zone_provider.dart';
import '../services/find_storage_provider.dart';
import '../services/location_service.dart';

class CurrentLocationMap extends ConsumerStatefulWidget {
  const CurrentLocationMap({super.key});

  @override
  ConsumerState<CurrentLocationMap> createState() =>
      _CurrentLocationMapState();
}

class _CurrentLocationMapState
    extends ConsumerState<CurrentLocationMap> {
  static const LatLng _fallbackLocation = LatLng(37.5665, 126.9780);

  final LocationService _locationService = const LocationService();
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(findStorageProvider.notifier).loadStorages(),
    );
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
    final findStorageState = ref.watch(findStorageProvider);

    final markers = findStorageState.storages.entries.map((entry) {
      final storage = entry.value;
      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(storage.lat, storage.lng),
        infoWindow: InfoWindow(
          title: storage.address,
          snippet: storage.detailAddress,
        ),
        onTap: () =>
            _onMarkerTap(storageId: entry.key, storage: storage),
      );
    }).toSet();

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _fallbackLocation,
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: markers,
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

  void _onMarkerTap({
    required String storageId,
    required Storage storage,
  }) {
    ref.read(findStorageProvider.notifier).selectStorage(storageId);
    _showStorageBottomSheet(storage);
  }

  void _showStorageBottomSheet(Storage storage) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final zonesSnapshot = await firestore
          .collection('storages')
          .doc(storage.id)
          .collection('zones')
          .get();
      final zones = zonesSnapshot.docs.map(Zone.fromDoc).toList();
      ref.read(zoneProvider.notifier).setZones(zones);
      ref.read(selectedZoneProvider.notifier).state = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역 정보를 불러오지 못했어요: $error')),
      );
    }
    showModalBottomSheet<void>(
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final imageUrl = storage.images.isNotEmpty
            ? storage.images.first
            : null;

        return StorageBottomSheet(
          imageUrl: imageUrl,
          storage: storage,
        );
      },
    );
  }
}
