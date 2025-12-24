import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/zone.dart';

final zoneProvider = NotifierProvider<ZoneNotifier, List<Zone>>(
      () => ZoneNotifier(),
);

class ZoneNotifier extends Notifier<List<Zone>> {
  @override
  List<Zone> build() => [];

  void reset() {
    state = [];
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
}