
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:jimiker/data/models/zone.dart';

final zoneProvider = NotifierProvider<ZoneNotifier, List<Zone>>(
  () => ZoneNotifier(),
);

final selectedZoneProvider = StateProvider<String?>((ref) => null);

/// 수정 중인 창고에서 "예약·이용이 걸려 있는" 구역들. (index → 원래 구역)
///
/// 누가 A구역을 예약해뒀는데 주인이 수정 화면에서 A를 지우거나 크기를
/// 바꾸면 상대의 계약이 공중에 뜬다. 이 목록에 있는 구역은 삭제와
/// 크기 변경이 막히고, 검증 때 원래 크기와 대조한다.
/// 수정 화면에 들어갈 때 채워지고 나올 때 비워진다.
final lockedZonesProvider = StateProvider<Map<String, Zone>>(
  (ref) => {},
);

class ZoneNotifier extends Notifier<List<Zone>> {
  @override
  List<Zone> build() => [];

  void reset() {
    state = [];
  }

  void setZones(List<Zone> zones) {
    state = List<Zone>.from(zones);
  }

  /// 아직 안 쓰인 첫 번째 이름(A, B, …, Z, AA, AB, …)을 준다.
  ///
  /// 개수 기반으로 만들면 A·B·C에서 B를 지운 뒤 추가할 때 다시 C가 나와
  /// 이름이 겹친다. 실제로 비어 있는 이름을 찾아야 한다.
  String nextIndex() {
    final used = state.map((zone) => zone.index).toSet();

    for (var i = 0; ; i++) {
      final String candidate;
      if (i < 26) {
        candidate = String.fromCharCode(65 + i);
      } else {
        final prefix = String.fromCharCode(65 + (i ~/ 26) - 1);
        final suffix = String.fromCharCode(65 + (i % 26));
        candidate = '$prefix$suffix';
      }
      if (!used.contains(candidate)) return candidate;
    }
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
