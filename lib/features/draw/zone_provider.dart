import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:jimiker/data/models/zone.dart';

final zoneProvider = NotifierProvider<ZoneNotifier, List<Zone>>(
  () => ZoneNotifier(),
);

final selectedZoneProvider = StateProvider<String?>((ref) => null);

class ZoneNotifier extends Notifier<List<Zone>> {
  @override
  List<Zone> build() => [];

  void reset() {
    state = [];
  }

  void setZones(List<Zone> zones) {
    state = List<Zone>.from(zones);
  }

  String nextIndex() {
    final count = state.length;
    if (count < 26) {
      return String.fromCharCode(65 + count);
    }
    final prefix = String.fromCharCode(65 + (count ~/ 26) - 1);
    final suffix = String.fromCharCode(65 + (count % 26));
    return '$prefix$suffix';
  }

  void addZone(Zone zone) {
    state = [...state, zone];
  }

  void updateZone(Zone zone) {
    state = [
      for (final current in state)
        if (current.index == zone.index) zone else current,
    ];
  }

  void removeZone(String index) {
    state = state.where((zone) => zone.index != index).toList();
  }

  void shiftZones(Offset offset) {
    if (offset == Offset.zero) {
      return;
    }

    state = [
      for (final zone in state)
        zone.copyWith(x: zone.x + offset.dx, y: zone.y + offset.dy),
    ];
  }
}
