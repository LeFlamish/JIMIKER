import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final touchCounterNotifier = NotifierProvider(
  () => TouchCounterNotifier(),
);

class TouchCounterNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  bool get canDraw => state == 1;
  void onPointerDown() {
    state++;
  }

  void onPointerUp() {
    state = (state - 1).clamp(0, 10);
  }

  void onPointerCancel() {
    state = 0;
  }

  void reset() {
    state = 0;
  }
}
