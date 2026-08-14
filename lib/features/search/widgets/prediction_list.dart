import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/core/config/app_config.dart';

class PredictionList extends StatelessWidget {
  const PredictionList({super.key, required this.predictions});

  final List<Prediction> predictions;

  static final GoogleMapsPlaces _places = GoogleMapsPlaces(
    apiKey: googleMapsApiKey,
  );

  /// 후보 하나를 고르고 좌표와 함께 이전 화면으로 돌아간다.
  ///
  /// 부르는 쪽(지도, 창고 등록)이 pop 결과의 latLng으로 화면을 옮긴다.
  /// 목록 탭과 키보드 '검색' 둘 다 이 경로를 쓴다.
  static Future<void> selectPrediction(
    BuildContext context,
    Prediction prediction,
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

  static Future<LatLng?> _latLngOf(Prediction prediction) async {
    final placeId = prediction.placeId;
    if (placeId == null) return null;

    try {
      final detail = await _places.getDetailsByPlaceId(placeId);
      if (!detail.isOkay) return null;

      final location = detail.result.geometry?.location;
      if (location == null) return null;

      return LatLng(location.lat, location.lng);
    } catch (_) {
      // 네트워크가 끊겼거나 키 제한에 걸린 경우. 좌표 없이 돌려보낸다.
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
            title: Text(prediction.description ?? ""),
            onTap: () => selectPrediction(context, prediction),
          );
        },
      ),
    );
  }
}
