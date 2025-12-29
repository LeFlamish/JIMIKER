import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
import 'package:jimiker/features/draw/touch_counter.dart';
import 'package:jimiker/features/draw/zone_provider.dart';

class DrawScreen extends ConsumerStatefulWidget {
  const DrawScreen({super.key});

  @override
  ConsumerState<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends ConsumerState<DrawScreen> {
  static const double _gridSize = 30.0;
  static const double _canvasSize = 1000.0;

  bool _isLayoutEditing = true;

  Offset? _startPoint;
  final ValueNotifier<Offset?> _previewPoint = ValueNotifier(null);
  final TransformationController _transform =
      TransformationController();

  Line? _focusLine;
  bool checkBoolChange = false;

  // ✅ 드래그 시작 기준(포인터/오프셋) 저장해서 튐/누적 오차 방지
  final Map<String, Offset> _zoneDragStartOffsets = {};
  final Map<String, Offset> _zoneDragStartPointers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerDrawingOnCanvas();
    });
  }

  @override
  void dispose() {
    _previewPoint.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fingerCount = ref.watch(touchCounterNotifier);

    // ✅ 1손가락: 그리기/구역 드래그
    final canOneFingerAction = fingerCount <= 1;

    // ✅ 2손가락: 이동/확대(InteractiveViewer)
    final canPanZoomWithTwoFingers = fingerCount >= 2;

    final scale = _transform.value.getMaxScaleOnAxis();
    final scaledSize = _canvasSize / scale;

    final zones = ref.watch(zoneProvider);

    return WillPopScope(
      onWillPop: () async {
        final offset = ref
            .read(drawProvider.notifier)
            .getTransformedDataWithMargin(_gridSize);
        ref.read(zoneProvider.notifier).shiftZones(offset);
        ref.read(drawProvider.notifier).drawChange(false);
        return true;
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
              Center(
                child: SizedBox(
                  width: _canvasSize,
                  height: _canvasSize,
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _transform,

                      // ✅ 핵심: 구역 수정 모드에서도 2손가락이면 pan/zoom 허용
                      panEnabled: canPanZoomWithTwoFingers,
                      scaleEnabled: canPanZoomWithTwoFingers,

                      minScale: 0.5,
                      maxScale: 3.0,
                      constrained: false,
                      clipBehavior: Clip.none,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _isLayoutEditing ? _focus : null,

                        // ✅ 도면 수정 모드 + 1손가락일 때만 선 그리기
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
                          valueListenable: _previewPoint,
                          builder: (context, preview, _) => Stack(
                            children: [
                              CustomPaint(
                                size: Size(scaledSize, scaledSize),
                                painter: GridPainter(
                                  width: _canvasSize,
                                  height: _canvasSize,
                                  gridSize: _gridSize,
                                  lines: ref.read(drawProvider).lines,
                                  previewStart: _startPoint,
                                  previewEnd: preview,
                                  doors: ref.read(drawProvider).doors,
                                  lineToFocus: _focusLine,
                                ),
                              ),

                              // ✅ 구역 수정 모드에서만 구역 표시
                              if (!_isLayoutEditing)
                                ..._buildZoneOverlays(
                                  zones: zones,
                                  // ✅ 핵심: 1손가락일 때만 드래그 가능
                                  // 2손가락이면 IgnorePointer로 터치 통과 -> InteractiveViewer가 받음
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

              // 하단 버튼들
              Positioned(
                left: 16,
                bottom: 24,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLayoutEditing = true;
                    });
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
  // Layout draw handlers
  // ==========================

  void _centerDrawingOnCanvas() {
    final drawState = ref.read(drawProvider);
    if (drawState.lines.isEmpty) {
      return;
    }

    final zones = ref.read(zoneProvider);
    final points = <Offset>[
      ...drawState.lines.expand((line) => [line.start, line.end]),
      ...drawState.doors,
      ...zones.expand(
        (zone) => [
          Offset(zone.x, zone.y),
          Offset(
            zone.x + (zone.width * _gridSize),
            zone.y + (zone.height * _gridSize),
          ),
        ],
      ),
    ];

    final minX = points.map((point) => point.dx).reduce(min);
    final minY = points.map((point) => point.dy).reduce(min);
    final maxX = points.map((point) => point.dx).reduce(max);
    final maxY = points.map((point) => point.dy).reduce(max);

    final contentCenter = Offset(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
    );
    final canvasCenter = const Offset(
      _canvasSize / 2,
      _canvasSize / 2,
    );
    final rawTranslation = canvasCenter - contentCenter;
    final translation = Offset(
      (rawTranslation.dx / _gridSize).round() * _gridSize,
      (rawTranslation.dy / _gridSize).round() * _gridSize,
    );

    ref.read(drawProvider.notifier).shiftDrawing(translation);
    ref.read(zoneProvider.notifier).shiftZones(translation);
    if (!mounted) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    final viewportSize = renderBox?.size;
    if (viewportSize == null) {
      _transform.value = Matrix4.identity();
      return;
    }

    final viewportCenter = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );
    final viewportTranslation = viewportCenter - canvasCenter;
    _transform.value = Matrix4.identity()
      ..translate(viewportTranslation.dx, viewportTranslation.dy);
  }

  void _onPanStart(DragStartDetails details) {
    final local = details.localPosition;
    _startPoint = snapToGrid(local);
    _previewPoint.value = local;

    Set<Offset>? doorsToRemove;
    if (_focusLine != null) {
      if (_focusLine!.start == _startPoint ||
          _focusLine!.end == _startPoint) {
        doorsToRemove = ref.read(drawProvider).doors.where((door) {
          return distanceToSegment(
                door,
                _focusLine!.start,
                _focusLine!.end,
              ) <
              5.0;
        }).toSet();

        if (_focusLine!.start == _startPoint) {
          _startPoint = _focusLine!.end;
        } else {
          _startPoint = _focusLine!.start;
        }

        // NOTE: 원 코드 유지(직접 remove). 가능하면 notifier로 통일 권장.
        ref.read(drawProvider).lines.remove(_focusLine);
        _focusLine = null;
      }
    }

    checkBoolChange = !checkBoolChange;
    if (doorsToRemove != null) {
      ref.read(drawProvider).doors.removeAll(doorsToRemove);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _previewPoint.value = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startPoint != null && _previewPoint.value != null) {
      final snappedEnd = snapToGrid(_previewPoint.value!);
      final newLine = Line(start: _startPoint!, end: snappedEnd);

      if (_startPoint! != snappedEnd) {
        ref.read(drawProvider.notifier).addLine(newLine);
      }

      _startPoint = null;
      _previewPoint.value = null;
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final location = details.localPosition;
    final nearbyLine = findNearestLine(location, 15.0);
    if (nearbyLine == null) return;

    final projected = projectPointOntoSegment(
      location,
      nearbyLine.start,
      nearbyLine.end,
    );
    final clamped = clampPointOnLineSegment(
      projected,
      nearbyLine.start,
      nearbyLine.end,
      10.0,
    );

    final existing = ref
        .read(drawProvider)
        .doors
        .firstWhere(
          (door) => (door - clamped).distance < 15.0,
          orElse: () => Offset.infinite,
        );

    checkBoolChange = !checkBoolChange;
    if (existing != Offset.infinite) {
      ref.read(drawProvider.notifier).removeDoor(existing);
    } else {
      ref.read(drawProvider.notifier).addDoor(clamped);
    }
  }

  void _handleLongPress(LongPressStartDetails details) {
    _focusLine = null;
    final sceneTap = details.localPosition;

    final lineToRemove = ref
        .read(drawProvider)
        .lines
        .firstWhere(
          (line) =>
              distanceToSegment(sceneTap, line.start, line.end) <
              10.0,
          orElse: () => Line(start: Offset.zero, end: Offset.zero),
        );

    if (lineToRemove.start == Offset.zero &&
        lineToRemove.end == Offset.zero) {
      return;
    }

    final doorsToRemove = ref.read(drawProvider).doors.where((door) {
      return distanceToSegment(
            door,
            lineToRemove.start,
            lineToRemove.end,
          ) <
          5.0;
    }).toSet();

    ref.read(drawProvider.notifier).removeLine(lineToRemove);
    ref.read(drawProvider.notifier).removeAllDoors(doorsToRemove);
    checkBoolChange = !checkBoolChange;
  }

  // ==========================
  // Geometry helpers
  // ==========================

  Offset snapToGrid(Offset point) {
    final x = (point.dx / _gridSize).round() * _gridSize;
    final y = (point.dy / _gridSize).round() * _gridSize;
    return Offset(x, y);
  }

  Line? findNearestLine(Offset point, double tolerance) {
    Line? closestLine;
    double minDistance = double.infinity;

    for (final line in ref.read(drawProvider).lines) {
      final distance = distanceToSegment(point, line.start, line.end);
      if (distance < minDistance && distance <= tolerance) {
        minDistance = distance;
        closestLine = line;
      }
    }
    return closestLine;
  }

  double distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return (p - a).distance;

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = a + ab * clampedT;
    return (p - projection).distance;
  }

  Offset projectPointOntoSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return a;

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    return a + ab * clampedT;
  }

  Offset clampPointOnLineSegment(
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

  Offset? getIntersectionPoint(
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
  ) {
    final a1 = p2.dy - p1.dy;
    final b1 = p1.dx - p2.dx;
    final c1 = a1 * p1.dx + b1 * p1.dy;

    final a2 = p4.dy - p3.dy;
    final b2 = p3.dx - p4.dx;
    final c2 = a2 * p3.dx + b2 * p3.dy;

    final delta = a1 * b2 - a2 * b1;
    if (delta.abs() < 1e-6) return null;

    final x = (b2 * c1 - b1 * c2) / delta;
    final y = (a1 * c2 - a2 * c1) / delta;
    return Offset(x, y);
  }

  void _focus(TapUpDetails details) {
    final location = details.localPosition;

    final lineToFocus = ref
        .read(drawProvider)
        .lines
        .firstWhere(
          (line) =>
              distanceToSegment(location, line.start, line.end) <
              10.0,
          orElse: () => Line(start: Offset.zero, end: Offset.zero),
        );

    setState(() {
      _focusLine = lineToFocus;
    });
  }

  // ==========================
  // Zone overlays
  // ==========================

  List<Widget> _buildZoneOverlays({
    required List<Zone> zones,
    required bool enableDrag,
  }) {
    if (zones.isEmpty) return [];

    const layoutSize = Size(_canvasSize, _canvasSize);

    return zones.map((zone) {
      final zoneWidth = zone.width * _gridSize;
      final zoneHeight = zone.height * _gridSize;

      final position = _clampZoneOffset(
        Offset(zone.x, zone.y),
        Size(zoneWidth, zoneHeight),
        layoutSize,
      );

      if (position.dx != zone.x || position.dy != zone.y) {
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

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: enableDrag
            ? GestureDetector(
                // ✅ globalPosition 기준으로 드래그(줌/팬 상태에서도 안정적)
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

                  final delta = details.globalPosition - startPointer;

                  final updated = _clampZoneOffset(
                    Offset(
                      startOffset.dx + delta.dx,
                      startOffset.dy + delta.dy,
                    ),
                    Size(zoneWidth, zoneHeight),
                    layoutSize,
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
            // ✅ 핵심: 2손가락이면 구역이 터치를 먹지 않게 통과시켜서 InteractiveViewer가 받게 함
            : IgnorePointer(ignoring: true, child: content),
      );
    }).toList();
  }

  Offset _clampZoneOffset(
    Offset offset,
    Size zoneSize,
    Size layoutSize,
  ) {
    final snapped = Offset(
      _snapToGrid(offset.dx),
      _snapToGrid(offset.dy),
    );

    final maxX = (layoutSize.width - zoneSize.width).clamp(
      0.0,
      layoutSize.width,
    );
    final maxY = (layoutSize.height - zoneSize.height).clamp(
      0.0,
      layoutSize.height,
    );

    return Offset(
      snapped.dx.clamp(0.0, maxX),
      snapped.dy.clamp(0.0, maxY),
    );
  }

  double _snapToGrid(double value) {
    return (value / _gridSize).round() * _gridSize;
  }
}

class GridPainter extends CustomPainter {
  final double gridSize;
  final double width;
  final double height;
  final List<Line> lines;
  final Offset? previewStart;
  final Offset? previewEnd;
  final Set<Offset> doors;
  final Line? lineToFocus;
  final bool transparent;

  GridPainter({
    this.gridSize = 30.0,
    required this.doors,
    required this.lines,
    required this.width,
    required this.height,
    this.previewStart,
    this.previewEnd,
    this.lineToFocus,
    this.transparent = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1.0;

    if (!transparent) {
      for (double x = 0; x <= width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
      }
      for (double y = 0; y <= height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
      }
      final double lastX = (width / gridSize).floor() * gridSize;
      canvas.drawLine(
        Offset(lastX, 0),
        Offset(lastX, height),
        gridPaint,
      );

      final double lastY = (height / gridSize).floor() * gridSize;
      canvas.drawLine(
        Offset(0, lastY),
        Offset(width, lastY),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0;

    final dotPaint = Paint()..color = Colors.transparent;

    for (final line in lines) {
      canvas.drawLine(line.start, line.end, linePaint);
      canvas.drawCircle(line.start, 5, dotPaint);
      canvas.drawCircle(line.end, 5, dotPaint);
    }

    if (previewStart != null && previewEnd != null) {
      final previewPaint = Paint()
        ..color = Colors.blue.withAlpha(75)
        ..strokeWidth = 2.0;
      canvas.drawCircle(
        previewStart!,
        5,
        Paint()..color = Colors.red,
      );
      canvas.drawLine(previewStart!, previewEnd!, previewPaint);
    }

    final doorPaint = Paint()..color = Colors.brown;

    for (final door in doors) {
      Line? nearestLine;
      double minDistance = double.infinity;

      for (final line in lines) {
        final distance = distanceToSegment(
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

      final dx = nearestLine.end.dx - nearestLine.start.dx;
      final dy = nearestLine.end.dy - nearestLine.start.dy;
      final angle = atan2(dy, dx);

      canvas.save();
      canvas.translate(door.dx, door.dy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: gridSize * 0.8,
        height: gridSize * 0.3,
      );
      canvas.drawRect(rect, doorPaint);
      canvas.restore();
    }

    if (lineToFocus != null) {
      canvas.drawCircle(
        lineToFocus!.start,
        5,
        Paint()..color = Colors.red,
      );
      canvas.drawCircle(
        lineToFocus!.end,
        5,
        Paint()..color = Colors.red,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;

  double distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0.0) return (p - a).distance;

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = a + ab * clampedT;
    return (p - projection).distance;
  }
}
