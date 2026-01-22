import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/reservation_card.dart';

import '../../../../../data/models/storage.dart';
import '../../../../draw/draw_provider.dart';
import '../../../../draw/structure_screen.dart';
import '../../../../draw/zone_provider.dart';

class StorageBottomSheet extends ConsumerStatefulWidget {
  final String? imageUrl;
  final Storage storage;

  const StorageBottomSheet({
    required this.imageUrl,
    required this.storage,
  });

  @override
  ConsumerState<StorageBottomSheet> createState() =>
      _StorageBottomSheetState();
}

class _StorageBottomSheetState
    extends ConsumerState<StorageBottomSheet> {
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
    final selectedZone = ref.watch(selectedZoneProvider);
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
                      StructureScreen(
                        drawState: DrawProviderData(
                          lines: storage.layout['lines'],
                          doors: storage.layout['doors'],
                          width: storage.width,
                          height: storage.height,
                          isDraw: false,
                        ),
                        onZoneTap: () {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      if (selectedZone == null)
                        const Text(
                          '예약할 구역을 선택해주세요.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ReservationCard(storage: storage),
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
