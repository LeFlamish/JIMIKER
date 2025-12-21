import 'package:jimiker/data/model/storage.dart';

class Location {
  final String id;
  final String address;
  final double lat;
  final double lng;
  final List<String> storages;

  Location({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
    required this.storages,
  });
}
