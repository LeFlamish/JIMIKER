import 'dart:async';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/config/app_config.dart';

class SearchProviderData {
  List<Prediction> predictions;
  List<Map<String, dynamic>> nearbyPlaces;

  SearchProviderData({
    this.predictions = const [],
    this.nearbyPlaces = const [],
  });
  SearchProviderData copyWith({
    List<Prediction>? predictions,
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

  final _places = GoogleMapsPlaces(apiKey: googleMapsApiKey);

  void onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().isEmpty) {
        state = state.copyWith(predictions: []);
        return;
      }

      try {
        final response = await _places.autocomplete(
          value,
          language: 'ko',
          components: [Component(Component.country, "kr")],
        );
        if (response.isOkay) {
          state = state.copyWith(predictions: response.predictions);
        }
      } catch (_) {
        // 네트워크가 끊겼거나 키 제한에 걸린 경우.
        // 이전 결과를 그대로 두고 조용히 넘어간다.
      }
    });
  }
}
