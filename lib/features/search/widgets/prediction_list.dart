import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PredictionList extends StatelessWidget {
  final List<Prediction> predictions;
  final GoogleMapsPlaces _places = GoogleMapsPlaces(
    apiKey: "AIzaSyAuhd1aQTSgjtgnydP3_wgD3SDD2QD-VGU",
  );
  PredictionList({super.key, required this.predictions});

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
            onTap: () async {
              final navigator = Navigator.of(context);
              LatLng? latLng = await getLatLngFromPrediction(
                prediction,
              );

              navigator.pop({
                'placeId': prediction.placeId,
                'address': prediction.description,
                'latLng': latLng,
              });
            },
          );
        },
      ),
    );
  }

  Future<LatLng?> getLatLngFromPrediction(
    Prediction prediction,
  ) async {
    final detail = await _places.getDetailsByPlaceId(
      prediction.placeId!,
    );
    if (detail.isOkay) {
      final location = detail.result.geometry?.location;
      if (location != null) {
        return LatLng(location.lat, location.lng);
      }
    }
    return null;
  }
}
