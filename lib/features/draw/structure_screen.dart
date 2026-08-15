import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/features/draw/zone_provider.dart';

import '../../data/models/zone.dart';
import 'draw_provider.dart';
import 'draw_screen.dart';

/// 도면 미리보기 + 구역 선택. (예약 바텀시트에서 쓴다)
///
/// 좌표는 전부 미터고, 화면에는 [kPixelsPerMeter]로 그린 뒤 FittedBox로
/// 영역에 맞춘다. 큰 건물도 작은 건물도 한눈에 들어온다.
class StructureScreen extends ConsumerWidget {
  const StructureScreen({
    super.key,
    required this.drawState,
    this.onZoneTap,
    this.maxHeight = 300,
  });

  final DrawProviderData drawState;
  final void Function()? onZoneTap;
  final double maxHeight;

  static const double _ppm = kPixelsPerMeter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zoneProvider);
    final selectedZone = ref.watch(selectedZoneProvider);

    final widthPx = drawState.width * _ppm;
    final heightPx = drawState.height * _ppm;

    if (widthPx <= 0 || heightPx <= 0) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '지형도 정보가 없어요.',
          style: TextStyle(fontSize: 13, color: Color(0xFF9AA0AE)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: widthPx,
          height: heightPx,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    transparent: true,
                    showLengths: true,
                    widthM: drawState.width,
                    heightM: drawState.height,
                    lines: drawState.lines,
                    doors: drawState.doors,
                  ),
                ),
              ),
              for (final zone in zones)
                _buildZone(ref, zone, selectedZone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZone(WidgetRef ref, Zone zone, String? selectedZone) {
    final isSelected = zone.index == selectedZone;
    final zoneW = zone.width * _ppm;
    final zoneH = zone.height * _ppm;

    return Positioned(
      left: zone.x * _ppm,
      top: zone.y * _ppm,
      child: GestureDetector(
        onTap: () {
          ref.read(selectedZoneProvider.notifier).state = zone.index;
          onZoneTap?.call();
        },
        child: Container(
          width: zoneW,
          height: zoneH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF48CAE4).withValues(alpha: 0.35)
                : const Color(0x336B66FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF6B66FF),
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                zone.index,
                style: const TextStyle(
                  color: Color(0xFF6B66FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 소비자가 구역을 고르는 화면이라 크기가 바로 보여야 한다.
              if (zoneW >= 56 && zoneH >= 44)
                Text(
                  formatZoneSize(zone.width, zone.height),
                  style: const TextStyle(
                    color: Color(0xFF6B66FF),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
