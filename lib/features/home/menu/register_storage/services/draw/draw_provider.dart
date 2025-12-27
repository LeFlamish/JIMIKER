import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_provider.dart';

import 'package:jimiker/data/models/storage.dart';

class DrawProviderData {
  final List<Line> lines;
  final Set<Offset> doors;
  final bool isDraw;
  final double height;
  final double width;

  DrawProviderData({
    this.lines = const [],
    this.doors = const {},
    this.isDraw = false,
    this.height = 0,
    this.width = 0,
  });

  DrawProviderData copyWith({
    List<Line>? lines,
    Set<Offset>? doors,
    bool? isDraw,
    double? height,
    double? width,
  }) {
    return DrawProviderData(
      lines: lines ?? this.lines,
      doors: doors ?? this.doors,
      isDraw: isDraw ?? this.isDraw,
      height: height ?? this.height,
      width: width ?? this.width,
    );
  }
}

final drawProvider = NotifierProvider<DrawNotifier, DrawProviderData>(
      () => DrawNotifier(),
);

class DrawNotifier extends Notifier<DrawProviderData> {
  @override
  DrawProviderData build() {
    return DrawProviderData();
  }

  TransformedData? _transformedData;

  void reset() {
    _transformedData = null;
    state = DrawProviderData();
  }

  void setDrawing({
    required List<Line> lines,
    required Set<Offset> doors,
    required double width,
    required double height,
  }) {
    _transformedData = null;
    state = state.copyWith(
      lines: lines,
      doors: doors,
      width: width,
      height: height,
    );
  }

  void drawChange(bool value) {
    state = state.copyWith(isDraw: value);
  }

  void addLine(Line newLine) {
    state = state.copyWith(lines: [...state.lines, newLine]);
  }

  void removeLine(Line line) {
    state = state.copyWith(lines: state.lines.toList()..remove(line));
  }

  void addDoor(Offset door) {
    state = state.copyWith(doors: {...state.doors, door});
  }

  void removeDoor(Offset door) {
    state = state.copyWith(doors: state.doors.toSet()..remove(door));
  }

  void removeAllDoors(Set<Offset> doors) {
    state = state.copyWith(
      doors: state.doors.toSet()..removeAll(doors),
    );
  }

  void shiftDrawing(Offset offset) {
    if (offset == Offset.zero) {
      return;
    }

    final shiftedLines =
    state.lines
        .map(
          (line) => Line(
        start: line.start + offset,
        end: line.end + offset,
      ),
    )
        .toList();
    final shiftedDoors =
    state.doors.map((door) => door + offset).toSet();

    state = state.copyWith(
      lines: shiftedLines,
      doors: shiftedDoors,
    );
  }

  Offset getTransformedDataWithMargin(double margin) {
    if (state.lines.isEmpty) {
      _transformedData = TransformedData(
        shiftedLines: [],
        shiftedDoors: {},
        width: 0,
        height: 0,
      );
      return Offset.zero;
    }

    // 모든 점 수집
    final allPoints =
        state.lines
            .expand((line) => [line.start, line.end])
            .toList() +
            state.doors.toList();

    // 최소/최대 좌표 계산
    final minX = allPoints
        .map((p) => p.dx)
        .reduce((a, b) => a < b ? a : b);
    final minY = allPoints
        .map((p) => p.dy)
        .reduce((a, b) => a < b ? a : b);
    final maxX = allPoints
        .map((p) => p.dx)
        .reduce((a, b) => a > b ? a : b);
    final maxY = allPoints
        .map((p) => p.dy)
        .reduce((a, b) => a > b ? a : b);

    final dxOffset = 60 - minX;
    final dyOffset = 60 - minY;

    // 이동된 선과 문 생성
    final shiftedLines = state.lines
        .map(
          (line) => Line(
        start: Offset(
          line.start.dx + dxOffset,
          line.start.dy + dyOffset,
        ),
        end: Offset(
          line.end.dx + dxOffset,
          line.end.dy + dyOffset,
        ),
      ),
    )
        .toList();

    final shiftedDoors = state.doors
        .map((door) => Offset(door.dx + dxOffset, door.dy + dyOffset))
        .toSet();

    final width = (maxX - minX) + 120; // 왼쪽 50, 오른쪽 50 마진 포함
    final height = (maxY - minY) + 120;

    _transformedData = TransformedData(
      shiftedLines: shiftedLines,
      shiftedDoors: shiftedDoors,
      width: width,
      height: height,
    );

    state = state.copyWith(
      lines: shiftedLines,
      doors: shiftedDoors,
      width: width,
      height: height,
    );

    return Offset(dxOffset, dyOffset);
  }
}

class TransformedData {
  final List<Line> shiftedLines;
  final Set<Offset> shiftedDoors;
  final double width;
  final double height;

  TransformedData({
    required this.shiftedLines,
    required this.shiftedDoors,
    required this.width,
    required this.height,
  });
}
