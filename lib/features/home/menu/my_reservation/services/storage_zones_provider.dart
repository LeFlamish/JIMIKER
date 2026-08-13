import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/services/auth_providers.dart';

/// 창고 하나의 구역 목록. 지형도를 그릴 때 쓴다.
///
/// 편집기용 [zoneProvider]와 달리 화면이 사라지면 같이 정리되고,
/// 전역 선택 상태를 건드리지 않는다.
final storageZonesProvider = FutureProvider.family
    .autoDispose<List<Zone>, String>((ref, storageId) async {
      if (storageId.isEmpty) return const [];

      final firestore = ref.read(firestoreProvider);
      final snapshot = await firestore
          .collection('storages')
          .doc(storageId)
          .collection('zones')
          .get();

      return snapshot.docs.map(Zone.fromDoc).toList();
    });
