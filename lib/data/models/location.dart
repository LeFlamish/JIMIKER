import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Location.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      address: data['address'],
      lat: data['lat'],
      lng: data['lng'],
      storages: List<String>.from(data['storages']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': lat,
      'lng': lng,
      'storages': storages,
    };
  }
}
