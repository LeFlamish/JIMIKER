import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 장소 검색 결과 한 줄.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

/// 장소 검색. 서버(Cloud Functions)를 거친다.
///
/// Places API 키를 앱에 넣지 않기 위해서다. 키는 서버 시크릿에만 있고,
/// 서버가 로그인 여부를 확인한 뒤 구글 Places를 대신 호출해
/// 결과만 돌려준다. (searchPlaces / getPlaceDetail 함수)
class PlacesService {
  PlacesService([FirebaseFunctions? functions])
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  /// 검색어 자동완성. 2글자 미만은 서버가 빈 목록을 돌려준다.
  Future<List<PlacePrediction>> autocomplete(String input) async {
    final result = await _functions.httpsCallable('searchPlaces').call({
      'input': input,
    });

    final data = result.data;
    final rawList = (data is Map ? data['predictions'] : null) as List?;

    return (rawList ?? const [])
        .map(
          (item) => PlacePrediction(
            placeId: item['placeId']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
          ),
        )
        .where((prediction) => prediction.placeId.isNotEmpty)
        .toList();
  }

  /// 장소의 좌표. 서버가 못 찾으면 null.
  Future<({double lat, double lng})?> location(String placeId) async {
    final result = await _functions
        .httpsCallable('getPlaceDetail')
        .call({'placeId': placeId});

    final data = result.data;
    final lat = (data is Map ? data['lat'] : null) as num?;
    final lng = (data is Map ? data['lng'] : null) as num?;
    if (lat == null || lng == null) return null;

    return (lat: lat.toDouble(), lng: lng.toDouble());
  }
}
