import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
import 'package:jimiker/features/draw/touch_counter.dart';
import 'package:jimiker/features/draw/zone_provider.dart';

/// 도면 에디터.
///
/// 모델 좌표는 전부 미터(m), 원점은 건물 좌상단이다. 화면에는 1m를
/// [kPixelsPerMeter]픽셀로 그리고, 격자 한 칸은 [kGridCellMeters]다.
/// 제스처가 들어오면 곧바로 m로 바꿔서 다루므로, 저장되는 값에는
/// 픽셀이 섞이지 않는다.
const double kGridCellMeters = 0.5;
const double kPixelsPerMeter = 60.0;

class DrawScreen extends ConsumerStatefulWidget {
  const DrawScreen({super.key});

  @override
  ConsumerState<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends ConsumerState<DrawScreen> {
  static const double _cellM = kGridCellMeters;
  static const double _ppm = kPixelsPerMeter;

  /// 건물 둘레 여백(px). 화면 표시용일 뿐 저장 좌표에는 들어가지 않는다.
  static const double _marginPx = 60.0;

  bool _isLayoutEditing = true;

  Offset? _startPointM;
  final ValueNotifier<Offset?> _previewPointM = ValueNotifier(null);
  final TransformationController _transform =
      TransformationController();

  Line? _focusLine;

  // 드래그 시작 기준(포인터/오프셋)을 저장해서 튐·누적 오차를 막는다.
  final Map<String, Offset> _zoneDragStartOffsets = {};
  final Map<String, Offset> _zoneDragStartPointers = {};

  double get _buildingW => ref.read(drawProvider).width;
  double get _buildingH => ref.read(drawProvider).height;

  Size get _canvasSize => Size(
    _buildingW * _ppm + _marginPx * 2,
    _buildingH * _ppm + _marginPx * 2,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvasInViewport();
    });
  }

  @override
  void dispose() {
    _previewPointM.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ==========================
  // 좌표 변환
  // ==========================

  Offset _toMeters(Offset localPx) => Offset(
    (localPx.dx - _marginPx) / _ppm,
    (localPx.dy - _marginPx) / _ppm,
  );

  Offset _toPx(Offset meters) => Offset(
    meters.dx * _ppm + _marginPx,
    meters.dy * _ppm + _marginPx,
  );

  double _snapValue(double m) => (m / _cellM).round() * _cellM;

  /// 격자에 스냅하고 건물 안으로 가둔다.
  Offset _snapM(Offset m) => Offset(
    _snapValue(m.dx).clamp(0.0, _buildingW),
    _snapValue(m.dy).clamp(0.0, _buildingH),
  );

  double get _viewScale => _transform.value.getMaxScaleOnAxis();

  @override
  Widget build(BuildContext context) {
    final fingerCount = ref.watch(touchCounterNotifier);
    final canOneFingerAction = fingerCount <= 1;
    final canPanZoomWithTwoFingers = fingerCount >= 2;

    final drawState = ref.watch(drawProvider);
    final zones = ref.watch(zoneProvider);
    final canvas = _canvasSize;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // 좌표가 처음부터 건물 기준 m라서 예전처럼 나갈 때
        // 좌표계를 재정렬할 일이 없다.
        ref.read(drawProvider.notifier).drawChange(false);
      },
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) =>
              ref.read(touchCounterNotifier.notifier).onPointerDown(),
          onPointerUp: (_) =>
              ref.read(touchCounterNotifier.notifier).onPointerUp(),
          onPointerCancel: (_) => ref
              .read(touchCounterNotifier.notifier)
              .onPointerCancel(),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    panEnabled: canPanZoomWithTwoFingers,
                    scaleEnabled: canPanZoomWithTwoFingers,
                    minScale: 0.2,
                    maxScale: 3.0,
                    constrained: false,
                    // 축소된 캔버스가 화면보다 작아지면 InteractiveViewer가
                    // 경계 보정으로 내용물을 좌상단에 붙여버린다. 터치할 때마다
                    // 도면이 위로 튕기던 원인. 경계 제한을 풀어서 캔버스가
                    // 화면 가운데 그대로 있게 한다.
                    boundaryMargin: const EdgeInsets.all(
                      double.infinity,
                    ),
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: canvas.width,
                      height: canvas.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _isLayoutEditing ? _focus : null,
                        onPanStart:
                            _isLayoutEditing && canOneFingerAction
                            ? _onPanStart
                            : null,
                        onPanUpdate:
                            _isLayoutEditing && canOneFingerAction
                            ? _onPanUpdate
                            : null,
                        onPanEnd:
                            _isLayoutEditing && canOneFingerAction
                            ? _onPanEnd
                            : null,
                        onDoubleTapDown: _isLayoutEditing
                            ? _handleDoubleTap
                            : null,
                        onLongPressStart: _isLayoutEditing
                            ? _handleLongPress
                            : null,
                        child: ValueListenableBuilder<Offset?>(
                          valueListenable: _previewPointM,
                          builder: (context, preview, _) => Stack(
                            children: [
                              CustomPaint(
                                size: canvas,
                                painter: GridPainter(
                                  widthM: drawState.width,
                                  heightM: drawState.height,
                                  originPx: const Offset(
                                    _marginPx,
                                    _marginPx,
                                  ),
                                  lines: drawState.lines,
                                  doors: drawState.doors,
                                  previewStart: _startPointM,
                                  previewEnd: preview,
                                  lineToFocus: _focusLine,
                                  showLengths: true,
                                ),
                              ),
                              if (!_isLayoutEditing)
                                ..._buildZoneOverlays(
                                  zones: zones,
                                  enableDrag: canOneFingerAction,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 축척 안내
              Positioned(
                top: 12,
                left: 16,
                child: SafeArea(
                  child: _InfoChip(
                    text:
                        '건물 ${formatMeters(drawState.width)}×'
                        '${formatMeters(drawState.height)}m · '
                        '한 칸 ${formatMeters(_cellM)}m',
                  ),
                ),
              ),

              // 선택한 벽 조작 패널
              if (_isLayoutEditing && _focusLine != null)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: SafeArea(child: _buildFocusedWallPanel()),
                ),

              // 하단 모드 버튼
              Positioned(
                left: 16,
                bottom: 24,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isLayoutEditing = true);
                  },
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text("도면 수정"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLayoutEditing
                        ? const Color(0xFF6B66FF)
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: ElevatedButton.icon(
                  onPressed: zones.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _isLayoutEditing = false;
                            _focusLine = null;
                          });
                        },
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text("구역 수정"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isLayoutEditing
                        ? const Color(0xFF6B66FF)
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================
  // 화면 초기 위치
  // ==========================

  void _centerCanvasInViewport() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final viewportSize = renderBox?.size;
    if (viewportSize == null) return;

    final canvas = _canvasSize;

    // 건물이 화면보다 크면 한눈에 들어오게 줄여서 시작한다.
    final fitScale = min(
      viewportSize.width / canvas.width,
      viewportSize.height / canvas.height,
    ).clamp(0.2, 1.0);

    final translation = Offset(
      (viewportSize.width - canvas.width * fitScale) / 2,
      (viewportSize.height - canvas.height * fitScale) / 2,
    );

    _transform.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(fitScale, fitScale, 1, 1);
  }

  // ==========================
  // 벽 그리기
  // ==========================

  void _onPanStart(DragStartDetails details) {
    final localM = _toMeters(details.localPosition);
    _startPointM = _snapM(localM);
    _previewPointM.value = localM;

    // 선택한 벽의 끝점에서 다시 그리기 시작하면, 그 벽을 지우고
    // 반대쪽 끝점부터 이어 그린다. (벽을 잡아 늘이는 느낌)
    final focused = _focusLine;
    if (focused != null) {
      const epsilon = 0.01;
      final fromStart =
          (focused.start - _startPointM!).distance < epsilon;
      final fromEnd = (focused.end - _startPointM!).distance < epsilon;

      if (fromStart || fromEnd) {
        final doorsToRemove = _doorsNearLine(focused, 0.15);
        _startPointM = fromStart ? focused.end : focused.start;

        ref.read(drawProvider.notifier).removeLine(focused);
        ref
            .read(drawProvider.notifier)
            .removeAllDoors(doorsToRemove);
        _focusLine = null;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _previewPointM.value = _toMeters(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    final start = _startPointM;
    final previewM = _previewPointM.value;
    if (start != null && previewM != null) {
      final snappedEnd = _snapM(previewM);

      if (start != snappedEnd) {
        ref
            .read(drawProvider.notifier)
            .addLine(Line(start: start, end: snappedEnd));
      }
    }
    _startPointM = null;
    _previewPointM.value = null;
  }

  void _handleDoubleTap(TapDownDetails details) {
    final locationM = _toMeters(details.localPosition);
    final nearbyLine = _findNearestLine(locationM, 0.25);
    if (nearbyLine == null) return;

    final projected = _projectOntoSegment(
      locationM,
      nearbyLine.start,
      nearbyLine.end,
    );
    final clamped = _clampOnSegment(
      projected,
      nearbyLine.start,
      nearbyLine.end,
      0.2,
    );

    final existing = ref
        .read(drawProvider)
        .doors
        .firstWhere(
          (door) => (door - clamped).distance < 0.25,
          orElse: () => Offset.infinite,
        );

    if (existing != Offset.infinite) {
      ref.read(drawProvider.notifier).removeDoor(existing);
    } else {
      ref.read(drawProvider.notifier).addDoor(clamped);
    }
  }

  void _handleLongPress(LongPressStartDetails details) {
    final tapM = _toMeters(details.localPosition);
    final lineToRemove = _findNearestLine(tapM, 0.2);
    if (lineToRemove == null) return;

    ref.read(drawProvider.notifier).removeLine(lineToRemove);
    ref
        .read(drawProvider.notifier)
        .removeAllDoors(_doorsNearLine(lineToRemove, 0.15));

    if (_focusLine == lineToRemove) {
      setState(() => _focusLine = null);
    }
  }

  void _focus(TapUpDetails details) {
    final locationM = _toMeters(details.localPosition);
    setState(() {
      _focusLine = _findNearestLine(locationM, 0.2);
    });
  }

  // ==========================
  // 선택한 벽: 길이 수정
  // ==========================

  Widget _buildFocusedWallPanel() {
    final line = _focusLine!;
    final length = (line.end - line.start).distance;

    return Center(
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '선택한 벽 ${length.toStringAsFixed(1)}m',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              TextButton(
                onPressed: _editFocusedWallLength,
                child: const Text('길이 수정'),
              ),
              TextButton(
                onPressed: () {
                  final target = _focusLine;
                  if (target == null) return;
                  ref.read(drawProvider.notifier).removeLine(target);
                  ref
                      .read(drawProvider.notifier)
                      .removeAllDoors(_doorsNearLine(target, 0.15));
                  setState(() => _focusLine = null);
                },
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Color(0xFFD32F2F)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _focusLine = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editFocusedWallLength() async {
    final line = _focusLine;
    if (line == null) return;

    final oldLength = (line.end - line.start).distance;
    final controller = TextEditingController(
      text: oldLength.toStringAsFixed(1),
    );

    final entered = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('벽 길이'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            suffixText: 'm',
            helperText: '시작점은 그대로 두고 끝점이 이동합니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('취소', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    if (entered == null || entered <= 0 || oldLength == 0) return;

    // 방향을 유지한 채 끝점만 옮긴다. 건물 밖으로는 못 나간다.
    final direction = (line.end - line.start) / oldLength;
    var newEnd = line.start + direction * entered;
    newEnd = Offset(
      newEnd.dx.clamp(0.0, _buildingW),
      newEnd.dy.clamp(0.0, _buildingH),
    );
    // 부동소수 찌꺼기가 좌표에 쌓이지 않게 0.1m로 다듬는다.
    newEnd = Offset(
      (newEnd.dx * 10).roundToDouble() / 10,
      (newEnd.dy * 10).roundToDouble() / 10,
    );

    final newLine = Line(start: line.start, end: newEnd);
    final newLength = (newEnd - line.start).distance;

    // 이 벽에 붙어 있던 문은 시작점에서의 거리를 유지한 채 따라온다.
    // 새 벽이 더 짧아져 밀려나면 벽 끝 안쪽으로 붙인다.
    final oldDoors = _doorsNearLine(line, 0.15);
    final movedDoors = <Offset>{};
    for (final door in oldDoors) {
      final projected = _projectOntoSegment(
        door,
        line.start,
        line.end,
      );
      final distanceFromStart = (projected - line.start).distance;
      final kept = distanceFromStart
          .clamp(0.2, max(newLength - 0.2, 0.1))
          .toDouble();
      movedDoors.add(line.start + direction * kept);
    }

    final notifier = ref.read(drawProvider.notifier);
    notifier.replaceLine(line, newLine);
    notifier.removeAllDoors(oldDoors);
    for (final door in movedDoors) {
      notifier.addDoor(door);
    }

    setState(() => _focusLine = newLine);
  }

  // ==========================
  // 기하 헬퍼 (전부 m 단위)
  // ==========================

  Set<Offset> _doorsNearLine(Line line, double tolerance) {
    return ref
        .read(drawProvider)
        .doors
        .where(
          (door) =>
              _distanceToSegment(door, line.start, line.end) <
              tolerance,
        )
        .toSet();
  }

  Line? _findNearestLine(Offset point, double tolerance) {
    Line? closestLine;
    double minDistance = double.infinity;

    for (final line in ref.read(drawProvider).lines) {
      final distance = _distanceToSegment(
        point,
        line.start,
        line.end,
      );
      if (distance < minDistance && distance <= tolerance) {
        minDistance = distance;
        closestLine = line;
      }
    }
    return closestLine;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return (p - a).distance;

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(
      0.0,
      1.0,
    );
    final projection = a + ab * t;
    return (p - projection).distance;
  }

  Offset _projectOntoSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return a;

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(
      0.0,
      1.0,
    );
    return a + ab * t;
  }

  Offset _clampOnSegment(
    Offset p,
    Offset a,
    Offset b,
    double minMargin,
  ) {
    final ab = b - a;
    final length = ab.distance;
    if (length == 0) return a;

    final t =
        ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (length * length);
    final clampedT = t.clamp(
      minMargin / length,
      1.0 - minMargin / length,
    );
    return a + ab * clampedT;
  }

  // ==========================
  // 구역 오버레이 (이동·복제)
  //
  // 크기 변경은 여기서 하지 않는다. 도면 위에서 구역을 잡아 늘이는 건
  // 이동 드래그와 헷갈리고 실수로 계약 조건(크기)이 바뀔 수 있어서,
  // 크기는 등록 화면의 구역 설정에서만 숫자로 고친다.
  // ==========================

  List<Widget> _buildZoneOverlays({
    required List<Zone> zones,
    required bool enableDrag,
  }) {
    return zones.map((zone) {
      final zonePx = Size(zone.width * _ppm, zone.height * _ppm);
      final positionPx = _toPx(Offset(zone.x, zone.y));

      final content = Container(
        width: zonePx.width,
        height: zonePx.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x336B66FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6B66FF)),
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
            if (zonePx.width >= 56 && zonePx.height >= 44)
              Text(
                formatZoneSize(zone.width, zone.height),
                style: const TextStyle(
                  color: Color(0xFF6B66FF),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      );

      return Positioned(
        left: positionPx.dx,
        top: positionPx.dy,
        child: enableDrag
            ? GestureDetector(
                onLongPress: () => _showZoneMenu(zone),
                onPanStart: (details) {
                  _zoneDragStartOffsets[zone.index] = Offset(
                    zone.x,
                    zone.y,
                  );
                  _zoneDragStartPointers[zone.index] =
                      details.globalPosition;
                },
                onPanUpdate: (details) {
                  final startOffset =
                      _zoneDragStartOffsets[zone.index] ??
                      Offset(zone.x, zone.y);
                  final startPointer =
                      _zoneDragStartPointers[zone.index] ??
                      details.globalPosition;

                  final deltaPx =
                      (details.globalPosition - startPointer) /
                      _viewScale;

                  final updated = _clampZonePosition(
                    startOffset + deltaPx / _ppm,
                    Size(zone.width, zone.height),
                  );

                  ref
                      .read(zoneProvider.notifier)
                      .updateZone(
                        zone.copyWith(x: updated.dx, y: updated.dy),
                      );
                },
                onPanEnd: (_) {
                  _zoneDragStartOffsets.remove(zone.index);
                  _zoneDragStartPointers.remove(zone.index);
                },
                child: content,
              )
            : IgnorePointer(ignoring: true, child: content),
      );
    }).toList();
  }

  void _showZoneMenu(Zone zone) {
    // 예약·이용이 걸린 구역은 상대의 계약이 참조하므로 지울 수 없다.
    final isLocked = ref
        .read(lockedZonesProvider)
        .containsKey(zone.index);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${zone.index} 구역 · '
                '${formatZoneSize(zone.width, zone.height)} · '
                '${formatWon(zone.price)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('같은 크기·가격으로 하나 더'),
              onTap: () {
                Navigator.pop(sheetContext);
                _duplicateZone(zone);
              },
            ),
            if (isLocked)
              const ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: Color(0xFFFF9800),
                ),
                title: Text(
                  '예약·이용이 걸려 있어 삭제할 수 없어요',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF8D6E00),
                  ),
                ),
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFD32F2F),
                ),
                title: const Text(
                  '이 구역 삭제',
                  style: TextStyle(color: Color(0xFFD32F2F)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(zoneProvider.notifier)
                      .removeZone(zone.index);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 같은 건물 안에서는 같은 크기 구역이 반복되는 경우가 많다.
  /// (같은 선반을 여러 줄 놓는 식) 복제로 배치를 빠르게 한다.
  void _duplicateZone(Zone zone) {
    final notifier = ref.read(zoneProvider.notifier);
    final index = notifier.nextIndex();
    final position = _findFreePosition(
      Size(zone.width, zone.height),
      ref.read(zoneProvider),
    );

    notifier.addZone(
      zone.copyWith(index: index, x: position.dx, y: position.dy),
    );
  }

  Offset _clampZonePosition(Offset positionM, Size zoneSizeM) {
    final snapped = Offset(
      _snapValue(positionM.dx),
      _snapValue(positionM.dy),
    );
    final maxX = (_buildingW - zoneSizeM.width).clamp(
      0.0,
      _buildingW,
    );
    final maxY = (_buildingH - zoneSizeM.height).clamp(
      0.0,
      _buildingH,
    );
    return Offset(
      snapped.dx.clamp(0.0, maxX),
      snapped.dy.clamp(0.0, maxY),
    );
  }

  Offset _findFreePosition(Size zoneSizeM, List<Zone> zones) {
    final maxX = (_buildingW - zoneSizeM.width).clamp(
      0.0,
      _buildingW,
    );
    final maxY = (_buildingH - zoneSizeM.height).clamp(
      0.0,
      _buildingH,
    );

    for (double y = 0; y <= maxY; y += _cellM) {
      for (double x = 0; x <= maxX; x += _cellM) {
        final rect = Rect.fromLTWH(
          x,
          y,
          zoneSizeM.width,
          zoneSizeM.height,
        );
        final overlaps = zones.any(
          (other) => rect.overlaps(
            Rect.fromLTWH(other.x, other.y, other.width, other.height),
          ),
        );
        if (!overlaps) return Offset(x, y);
      }
    }
    return Offset.zero;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF444444),
        ),
      ),
    );
  }
}

/// 도면을 그리는 페인터. 에디터·미리보기·보기 전용 화면이 같이 쓴다.
///
/// 입력 좌표는 전부 미터고, [kPixelsPerMeter]를 곱해 픽셀로 바꾼다.
/// [originPx]는 캔버스 안에서 건물 좌상단이 놓일 픽셀 위치다.
class GridPainter extends CustomPainter {
  /// 건물 크기(m)
  final double widthM;
  final double heightM;

  final Offset originPx;
  final List<Line> lines;
  final Set<Offset> doors;
  final Offset? previewStart;
  final Offset? previewEnd;
  final Line? lineToFocus;

  /// true면 격자를 생략한다. (보기 전용 화면)
  final bool transparent;

  /// 벽 길이 라벨 표시 여부
  final bool showLengths;

  GridPainter({
    required this.widthM,
    required this.heightM,
    required this.lines,
    required this.doors,
    this.originPx = Offset.zero,
    this.previewStart,
    this.previewEnd,
    this.lineToFocus,
    this.transparent = false,
    this.showLengths = false,
  });

  static const double _ppm = kPixelsPerMeter;
  static const double _cellM = kGridCellMeters;

  Offset _px(Offset meters) => Offset(
    meters.dx * _ppm + originPx.dx,
    meters.dy * _ppm + originPx.dy,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final buildingRect = Rect.fromLTWH(
      originPx.dx,
      originPx.dy,
      widthM * _ppm,
      heightM * _ppm,
    );

    // 건물 바닥과 외곽. 이 사각형이 곧 실측 크기다.
    canvas.drawRect(
      buildingRect,
      Paint()..color = Colors.white,
    );

    if (!transparent) {
      final gridPaint = Paint()
        ..color = Colors.grey[300]!
        ..strokeWidth = 1.0;

      for (double x = 0; x <= widthM + 0.001; x += _cellM) {
        canvas.drawLine(
          _px(Offset(x, 0)),
          _px(Offset(x, heightM)),
          gridPaint,
        );
      }
      for (double y = 0; y <= heightM + 0.001; y += _cellM) {
        canvas.drawLine(
          _px(Offset(0, y)),
          _px(Offset(widthM, y)),
          gridPaint,
        );
      }
    }

    canvas.drawRect(
      buildingRect,
      Paint()
        ..color = Colors.grey[500]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0;

    for (final line in lines) {
      canvas.drawLine(_px(line.start), _px(line.end), linePaint);
    }

    if (showLengths) {
      for (final line in lines) {
        _drawLengthLabel(canvas, line.start, line.end);
      }
    }

    final start = previewStart;
    final end = previewEnd;
    if (start != null && end != null) {
      final previewPaint = Paint()
        ..color = Colors.blue.withAlpha(75)
        ..strokeWidth = 2.0;
      canvas.drawCircle(_px(start), 5, Paint()..color = Colors.red);
      canvas.drawLine(_px(start), _px(end), previewPaint);
      // 끌고 있는 선의 길이를 실시간으로 보여준다.
      _drawLengthLabel(canvas, start, end, emphasized: true);
    }

    final doorPaint = Paint()..color = Colors.brown;
    for (final door in doors) {
      Line? nearestLine;
      double minDistance = double.infinity;

      for (final line in lines) {
        final distance = _distanceToSegment(
          door,
          line.start,
          line.end,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestLine = line;
        }
      }
      if (nearestLine == null) continue;

      final direction = nearestLine.end - nearestLine.start;
      final angle = atan2(direction.dy, direction.dx);
      final doorPx = _px(door);

      canvas.save();
      canvas.translate(doorPx.dx, doorPx.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: _cellM * _ppm * 0.8,
          height: _cellM * _ppm * 0.3,
        ),
        doorPaint,
      );
      canvas.restore();
    }

    final focused = lineToFocus;
    if (focused != null) {
      final focusPaint = Paint()..color = Colors.red;
      canvas.drawCircle(_px(focused.start), 5, focusPaint);
      canvas.drawCircle(_px(focused.end), 5, focusPaint);
    }
  }

  /// 벽 중앙에 "4.5m" 라벨을 붙인다. 너무 짧은 벽은 생략한다.
  void _drawLengthLabel(
    Canvas canvas,
    Offset startM,
    Offset endM, {
    bool emphasized = false,
  }) {
    final lengthM = (endM - startM).distance;
    if (lengthM < _cellM * 1.5) return;

    final text = '${lengthM.toStringAsFixed(1)}m';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: emphasized ? 13 : 11,
          fontWeight: FontWeight.w600,
          color: emphasized
              ? const Color(0xFFD32F2F)
              : const Color(0xFF5A5F6E),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 벽 중앙에서 법선 방향으로 살짝 띄운다.
    final midPx = _px((startM + endM) / 2);
    final direction = (endM - startM) / lengthM;
    final normal = Offset(-direction.dy, direction.dx);
    final at =
        midPx +
        normal * 11 -
        Offset(painter.width / 2, painter.height / 2);

    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        at.dx - 3,
        at.dy - 1,
        painter.width + 6,
        painter.height + 2,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      background,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return (p - a).distance;

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(
      0.0,
      1.0,
    );
    final projection = a + ab * t;
    return (p - projection).distance;
  }
}
