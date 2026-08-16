import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/features/search/places_service.dart';

class PredictionList extends StatelessWidget {
  const PredictionList({super.key, required this.predictions});

  final List<PlacePrediction> predictions;

  static final PlacesService _places = PlacesService();

  /// 후보 하나를 고르고 좌표와 함께 이전 화면으로 돌아간다.
  ///
  /// 부르는 쪽(지도, 창고 등록)이 pop 결과의 latLng으로 화면을 옮긴다.
  /// 목록 탭과 키보드 '검색' 둘 다 이 경로를 쓴다.
  static Future<void> selectPrediction(
    BuildContext context,
    PlacePrediction prediction,
  ) async {
    final navigator = Navigator.of(context);
    final latLng = await _latLngOf(prediction);

    if (!context.mounted) return;

    navigator.pop({
      'placeId': prediction.placeId,
      'address': prediction.description,
      'latLng': latLng,
    });
  }

  static Future<LatLng?> _latLngOf(PlacePrediction prediction) async {
    try {
      final location = await _places.location(prediction.placeId);
      if (location == null) return null;

      return LatLng(location.lat, location.lng);
    } catch (error) {
      // 네트워크가 끊겼거나 서버 함수가 아직 배포되지 않은 경우.
      // 좌표 없이 돌려보내고, 원인은 로그로만 남긴다.
      debugPrint('getPlaceDetail failed: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.separated(
        itemCount: predictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final prediction = predictions[index];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(prediction.description),
            onTap: () => selectPrediction(context, prediction),
          );
        },
      ),
    );
  }
}
