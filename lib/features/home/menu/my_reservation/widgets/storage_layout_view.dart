import 'package:flutter/material.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/draw_screen.dart' show GridPainter;

/// 창고 지형도를 "보기 전용"으로 그린다.
///
/// [StructureScreen]은 편집기용이라 zoneProvider/selectedZoneProvider 전역 상태를
/// 읽고 구역 위치까지 보정(clamp)한다. 상세 화면에서 그걸 쓰면 예약 화면이 쓰던
/// 선택 상태를 덮어써 버리므로, 여기서는 값만 받아서 그리는 위젯을 따로 둔다.
///
/// [highlightedZoneIndex]에 해당하는 구역만 색을 채워 어디를 빌렸는지 보여준다.
class StorageLayoutView extends StatelessWidget {
  const StorageLayoutView({
    super.key,
    required this.storage,
    required this.zones,
    required this.highlightedZoneIndex,
    this.gridSize = 30.0,
    this.maxHeight = 320,
  });

  final Storage storage;
  final List<Zone> zones;
  final String? highlightedZoneIndex;
  final double gridSize;
  final double maxHeight;

  static const Color _highlightColor = Color(0xFF6B7AF5);
  static const Color _mutedColor = Color(0xFF9AA0AE);

  @override
  Widget build(BuildContext context) {
    final lines =
        (storage.layout['lines'] as List<dynamic>?)?.cast<Line>() ??
        const <Line>[];
    final doors =
        (storage.layout['doors'] as Set<dynamic>?)?.cast<Offset>() ??
        const <Offset>{};

    final layoutWidth = storage.width;
    final layoutHeight = storage.height;

    if (layoutWidth <= 0 || layoutHeight <= 0) {
      return _buildEmpty('지형도 정보가 없어요.');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        color: const Color(0xFFF5F6FA),
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: layoutWidth,
              height: layoutHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(
                        transparent: true,
                        width: layoutWidth,
                        height: layoutHeight,
                        lines: lines,
                        doors: doors,
                      ),
                    ),
                  ),
                  ...zones.map(_buildZone),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZone(Zone zone) {
    final isMine = zone.index == highlightedZoneIndex;
    final color = isMine ? _highlightColor : _mutedColor;

    return Positioned(
      left: zone.x,
      top: zone.y,
      child: Container(
        width: zone.width * gridSize,
        height: zone.height * gridSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMine
              ? _highlightColor.withValues(alpha: 0.85)
              : _mutedColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: isMine ? 2.5 : 1),
        ),
        child: Text(
          zone.index,
          style: TextStyle(
            color: isMine ? Colors.white : _mutedColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Container(
      width: double.infinity,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF9AA0AE),
        ),
      ),
    );
  }
}

/// 지형도 아래에 붙는 색상 범례.
class StorageLayoutLegend extends StatelessWidget {
  const StorageLayoutLegend({super.key, required this.zoneIndex});

  final String zoneIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(
          color: StorageLayoutView._highlightColor.withValues(
            alpha: 0.85,
          ),
          borderColor: StorageLayoutView._highlightColor,
          label: '내 보관 구역 ($zoneIndex)',
        ),
        const SizedBox(width: 16),
        _LegendDot(
          color: StorageLayoutView._mutedColor.withValues(alpha: 0.12),
          borderColor: StorageLayoutView._mutedColor,
          label: '다른 구역',
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
