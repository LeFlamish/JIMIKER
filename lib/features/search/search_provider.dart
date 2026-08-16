import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/search/places_service.dart';

class SearchProviderData {
  List<PlacePrediction> predictions;
  List<Map<String, dynamic>> nearbyPlaces;

  SearchProviderData({
    this.predictions = const [],
    this.nearbyPlaces = const [],
  });
  SearchProviderData copyWith({
    List<PlacePrediction>? predictions,
    List<Map<String, dynamic>>? nearbyPlaces,
  }) {
    return SearchProviderData(
      predictions: predictions ?? this.predictions,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
    );
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchProviderData>(
      () => SearchNotifier(),
    );

class SearchNotifier extends Notifier<SearchProviderData> {
  @override
  SearchProviderData build() {
    return SearchProviderData();
  }

  Timer? _debounce;

  void onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = value.trim();

      // 너무 짧은 입력은 호출하지 않는다. (서버·Places 요금 절약)
      if (query.length < 2) {
        state = state.copyWith(predictions: []);
        return;
      }

      try {
        final predictions = await ref
            .read(placesServiceProvider)
            .autocomplete(query);
        state = state.copyWith(predictions: predictions);
      } catch (error) {
        // 네트워크가 끊겼거나 서버 함수가 아직 배포되지 않은 경우.
        // 이전 결과를 그대로 두고, 원인은 로그로만 남긴다.
        debugPrint('searchPlaces failed: $error');
      }
    });
  }
}
