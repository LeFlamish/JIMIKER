import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/draw/zone_provider.dart';

import '../../data/models/zone.dart';
import 'draw_provider.dart';
import 'draw_screen.dart';

// 사용 예:
// StructureEditorArea(drawState: ref.watch(drawProvider), enableDrag: false)

class StructureScreen extends ConsumerWidget {
  const StructureScreen({
    super.key,
    required this.drawState,
    this.enableDrag = false,
    this.gridSize = 30.0,
    this.suspendPreviewZoneClamp = false,
    this.onZoneTap,
  });

  final DrawProviderData drawState;
  final bool enableDrag;
  final double gridSize;
  final void Function()? onZoneTap;

  /// 프리뷰에서 clamp + provider update 때문에 zone이 한 곳에 모이는 현상이 있으면
  /// 해당 순간에 true로 넘겨 clamp/update를 중단할 수 있게 옵션으로 뺐습니다.
  final bool suspendPreviewZoneClamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zoneProvider);
    final selectedZone = ref.watch(selectedZoneProvider);
    final double layoutW = drawState.width.toDouble();
    final double layoutH = drawState.height.toDouble();

    return Container(
      width: double.infinity,
      height: layoutH + 100.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.blueGrey[50],
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: layoutW,
                    height: layoutH,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GridPainter(
                              transparent: true,
                              width: layoutW,
                              height: layoutH,
                              lines: drawState.lines,
                              doors: drawState.doors,
                            ),
                          ),
                        ),
                        ..._buildZoneOverlays(
                          ref: ref,
                          drawState: drawState,
                          zones: zones,
                          selectedZone: selectedZone,
                          enableDrag: enableDrag,
                          gridSize: gridSize,
                          suspendPreviewZoneClamp:
                              suspendPreviewZoneClamp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildZoneOverlays({
    required WidgetRef ref,
    required DrawProviderData drawState,
    required List<Zone> zones,
    required String? selectedZone,
    required bool enableDrag,
    required double gridSize,
    required bool suspendPreviewZoneClamp,
  }) {
    if (zones.isEmpty) return [];

    final layoutSize = Size(
      drawState.width.toDouble(),
      drawState.height.toDouble(),
    );

    return zones.map((zone) {
      final zoneWidth = zone.width.toDouble() * gridSize;
      final zoneHeight = zone.height.toDouble() * gridSize;

      final Offset raw = Offset(zone.x.toDouble(), zone.y.toDouble());

      final Offset position = suspendPreviewZoneClamp
          ? raw
          : _clampZoneOffset(
              raw,
              Size(zoneWidth, zoneHeight),
              layoutSize,
              gridSize,
            );

      // 프리뷰에서 zone이 레이아웃 밖에 있으면 자동 보정 + provider 반영
      if (!suspendPreviewZoneClamp &&
          (position.dx != zone.x || position.dy != zone.y)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(zoneProvider.notifier)
              .updateZone(
                zone.copyWith(x: position.dx, y: position.dy),
              );
        });
      }

      final content = Container(
        width: zoneWidth,
        height: zoneHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: zone.index == selectedZone
              ? const Color(0xFF48CAE4).withOpacity(0.25)
              : const Color(0x336B66FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: zone.index == selectedZone
                ? const Color(0xFF6B66FF)
                : const Color(0xFF6B66FF),
            width: zone.index == selectedZone ? 2 : 1,
          ),
        ),
        child: Text(
          zone.index,
          style: const TextStyle(
            color: Color(0xFF6B66FF),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: GestureDetector(
          onTap: () {
            ref.read(selectedZoneProvider.notifier).state =
                zone.index;
            onZoneTap?.call();
          },
          onPanUpdate: enableDrag
              ? (details) {
                  final updated = _clampZoneOffset(
                    Offset(
                      zone.x.toDouble() + details.delta.dx,
                      zone.y.toDouble() + details.delta.dy,
                    ),
                    Size(zoneWidth, zoneHeight),
                    layoutSize,
                    gridSize,
                  );

                  ref
                      .read(zoneProvider.notifier)
                      .updateZone(
                        zone.copyWith(x: updated.dx, y: updated.dy),
                      );
                }
              : null,
          child: content,
        ),
      );
    }).toList();
  }

  Offset _clampZoneOffset(
    Offset offset,
    Size zoneSize,
    Size layoutSize,
    double gridSize,
  ) {
    final snapped = Offset(
      _snapToGrid(offset.dx, gridSize),
      _snapToGrid(offset.dy, gridSize),
    );

    final double maxX = (layoutSize.width - zoneSize.width)
        .clamp(0.0, layoutSize.width)
        .toDouble();
    final double maxY = (layoutSize.height - zoneSize.height)
        .clamp(0.0, layoutSize.height)
        .toDouble();

    return Offset(
      snapped.dx.clamp(0.0, maxX).toDouble(),
      snapped.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  double _snapToGrid(double value, double gridSize) {
    return (value / gridSize).round() * gridSize;
  }
}
