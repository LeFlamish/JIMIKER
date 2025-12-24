import 'dart:async';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const double _maxDistanceMeters = 10000;
  Timer? _debounce;

  final _places = GoogleMapsPlaces(
    apiKey: 'AIzaSyAuhd1aQTSgjtgnydP3_wgD3SDD2QD-VGU',
  );

  void onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().isEmpty) {
        state = state.copyWith(predictions: []);
        return;
      }

      final response = await _places.autocomplete(
        value,
        language: 'ko',
        components: [Component(Component.country, "kr")],
      );
      if (response.isOkay) {
        state = state.copyWith(predictions: response.predictions);
      }
    });
  }
}
