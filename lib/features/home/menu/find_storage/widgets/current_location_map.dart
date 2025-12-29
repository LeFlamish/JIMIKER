import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/features/search/search_screen.dart';

import '../../../../../data/models/storage.dart';
import '../../../../../data/models/zone.dart';
import '../../../../../services/auth_providers.dart';
import '../../register_storage/screens/draw_screen.dart';
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
    _showStorageBottomSheet(storageId: storageId, storage: storage);
  }

  void _showStorageBottomSheet({
    required String storageId,
    required Storage storage,
  }) {
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

        return _StorageBottomSheet(
          imageUrl: imageUrl,
          storage: storage,
          storageId: storageId,
        );
      },
    );
  }
}

class _StorageBottomSheet extends ConsumerStatefulWidget {
  final String? imageUrl;
  final Storage storage;
  final String storageId;

  const _StorageBottomSheet({
    required this.imageUrl,
    required this.storage,
    required this.storageId,
  });

  @override
  ConsumerState<_StorageBottomSheet> createState() =>
      _StorageBottomSheetState();
}

class _StorageBottomSheetState
    extends ConsumerState<_StorageBottomSheet> {
  static const double _minExtent = 0.2;
  static const double _initialExtent = 0.35;
  static const double _maxExtent = 0.75;
  static const List<double> _snapPoints = <double>[
    _minExtent,
    _initialExtent,
    _maxExtent,
  ];

  double _currentExtent = _initialExtent;
  bool _isDragging = false;
  late Future<List<Zone>> _zonesFuture;

  @override
  void initState() {
    super.initState();
    _zonesFuture = _loadZones();
  }

  Future<List<Zone>> _loadZones() async {
    final firestore = ref.read(firestoreProvider);
    final snapshot = await firestore
        .collection('storages')
        .doc(widget.storageId)
        .collection('zones')
        .get();

    return snapshot.docs.map(Zone.fromDoc).toList();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double dragDelta = (details.primaryDelta ?? 0) * -1;
    final double screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight == 0) return;

    final double deltaExtent = dragDelta / screenHeight;
    setState(() {
      _currentExtent = (_currentExtent + deltaExtent).clamp(
        _minExtent,
        _maxExtent,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    const double snapTolerance = 0.07;
    const double velocityThreshold = 700;
    final double velocity = details.velocity.pixelsPerSecond.dy;

    final bool isNearInitial =
        (_currentExtent - _initialExtent).abs() <= snapTolerance;

    double target;

    if (velocity.abs() >= velocityThreshold) {
      if (velocity < 0) {
        final List<double> higher =
            _snapPoints.where((p) => p > _currentExtent).toList()
              ..sort();
        target = higher.isNotEmpty ? higher.first : _maxExtent;
      } else {
        final List<double> lower =
            _snapPoints.where((p) => p < _currentExtent).toList()
              ..sort();
        target = lower.isNotEmpty ? lower.last : _minExtent;
      }
    } else {
      target = isNearInitial
          ? _initialExtent
          : _snapPoints.reduce(
              (a, b) =>
                  (a - _currentExtent).abs() <
                      (b - _currentExtent).abs()
                  ? a
                  : b,
            );
    }

    setState(() {
      _currentExtent = target;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.storage;

    return AnimatedFractionallySizedBox(
      heightFactor: _currentExtent,
      duration: _isDragging
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            storage.address,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (storage.detailAddress.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            storage.detailAddress,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                        ),
                      if (widget.imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                      color: Colors.grey[200],
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _StorageInfoChip(
                            icon: Icons.meeting_room_outlined,
                            label: '보관구역',
                            value: '${storage.count}개',
                          ),
                          _StorageInfoChip(
                            icon: Icons.straighten,
                            label: '가로',
                            value:
                                '${storage.width.toStringAsFixed(1)}m',
                          ),
                          _StorageInfoChip(
                            icon: Icons.height,
                            label: '세로',
                            value:
                                '${storage.height.toStringAsFixed(1)}m',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StorageLayoutPreview(
                        storage: storage,
                        zonesFuture: _zonesFuture,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StorageInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

class _StorageLayoutPreview extends StatelessWidget {
  const _StorageLayoutPreview({
    required this.storage,
    required this.zonesFuture,
  });

  final Storage storage;
  final Future<List<Zone>> zonesFuture;

  static const double _gridSize = 30.0;
  static const double _maxPreviewHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final layoutLines = storage.layout['lines'];
    final layoutDoors = storage.layout['doors'];
    final lines = layoutLines is List<Line> ? layoutLines : <Line>[];
    final doors = layoutDoors is Set<Offset>
        ? layoutDoors
        : <Offset>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('구조도', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<Zone>>(
          future: zonesFuture,
          builder: (context, snapshot) {
            final zones = snapshot.data ?? const <Zone>[];
            final hasLayout = lines.isNotEmpty || doors.isNotEmpty;
            final hasZones = zones.isNotEmpty;
            final shouldShowPreview = hasLayout || hasZones;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _SkeletonBox(
                height: 200,
                borderRadius: BorderRadius.circular(12),
              );
            }

            if (snapshot.hasError) {
              return _InfoBox(
                message: '구조도를 불러오지 못했어요.',
                icon: Icons.error_outline,
              );
            }

            if (!shouldShowPreview) {
              return _InfoBox(message: '등록된 구조도가 없습니다.');
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _maxPreviewHeight,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final baseSize = Size(
                    storage.width > 0 ? storage.width : 240,
                    storage.height > 0 ? storage.height : 240,
                  );

                  final scaleX =
                      constraints.maxWidth / baseSize.width;
                  final scaleY = _maxPreviewHeight / baseSize.height;
                  final scaleCandidates = <double>[
                    if (scaleX.isFinite && scaleX > 0) scaleX,
                    if (scaleY.isFinite && scaleY > 0) scaleY,
                  ];

                  final scale = scaleCandidates.isNotEmpty
                      ? scaleCandidates.reduce(math.min)
                      : 1.0;

                  final displayHeight = (baseSize.height * scale)
                      .clamp(0.0, _maxPreviewHeight);

                  return Container(
                    width: double.infinity,
                    height: displayHeight,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: baseSize.width,
                        height: baseSize.height,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topLeft,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: baseSize,
                                painter: GridPainter(
                                  gridSize: _gridSize,
                                  width: baseSize.width,
                                  height: baseSize.height,
                                  lines: lines,
                                  doors: doors,
                                  transparent: true,
                                ),
                              ),
                              ...zones.map(
                                (zone) => Positioned(
                                  left: zone.x,
                                  top: zone.y,
                                  child: _ZonePreviewChip(zone: zone),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.message,
    this.icon = Icons.info_outline,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.borderRadius,
  });

  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
    );
  }
}

class _ZonePreviewChip extends StatelessWidget {
  const _ZonePreviewChip({required this.zone});

  final Zone zone;

  static const double _gridSize = 30.0;

  @override
  Widget build(BuildContext context) {
    final zoneWidth = zone.width * _gridSize;
    final zoneHeight = zone.height * _gridSize;

    return Container(
      width: zoneWidth,
      height: zoneHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x336B66FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6B66FF)),
      ),
      child: Text(
        zone.index,
        style: const TextStyle(
          color: Color(0xFF6B66FF),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
