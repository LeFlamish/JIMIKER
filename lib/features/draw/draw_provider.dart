import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jimiker/data/models/storage.dart';

/// 도면 상태. **좌표는 전부 미터(m), 원점은 건물 좌상단**이다.
///
/// 예전에는 화면 픽셀을 그대로 들고 있어서 "한 칸이 몇 m인지"가 어디에도
/// 없었고, 저장된 도면이 에디터 캔버스 크기에 묶여 있었다. 이제 화면 변환은
/// 그리는 쪽(위젯)이 ppm(픽셀/미터)으로 알아서 한다.
class DrawProviderData {
  final List<Line> lines;
  final Set<Offset> doors;
  final bool isDraw;

  /// 건물 실측 크기(m). 등록 시작 때 주인이 입력한다.
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

  void reset() {
    state = DrawProviderData();
  }

  /// 건물 실측 크기를 정한다. 벽이 하나도 없으면 외곽 네 벽을 만들어준다.
  ///
  /// 창고는 대부분 직사각형이라, 외곽을 자동으로 그려주면 주인은 내부
  /// 칸막이만 그리면 된다. 외곽이 입력값에서 나오므로 시작부터 실측이다.
  void setBuildingSize(double widthM, double heightM) {
    final needOutline = state.lines.isEmpty;

    final outline = needOutline
        ? [
            Line(start: const Offset(0, 0), end: Offset(widthM, 0)),
            Line(
              start: Offset(widthM, 0),
              end: Offset(widthM, heightM),
            ),
            Line(
              start: Offset(widthM, heightM),
              end: Offset(0, heightM),
            ),
            Line(start: Offset(0, heightM), end: const Offset(0, 0)),
          ]
        : state.lines;

    state = state.copyWith(
      width: widthM,
      height: heightM,
      lines: outline,
    );
  }

  void setDrawing({
    required List<Line> lines,
    required Set<Offset> doors,
    required double width,
    required double height,
  }) {
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

  /// 벽 하나를 교체한다. (길이 수정에 쓴다)
  void replaceLine(Line oldLine, Line newLine) {
    state = state.copyWith(
      lines: [
        for (final line in state.lines)
          if (line == oldLine) newLine else line,
      ],
    );
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
}
