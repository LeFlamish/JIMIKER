import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

class Storage {
  final String locationId;
  final double lat;
  final double lng;
  final String address;
  final String detailAddress;
  final int count;
  final DateTime createdAt;
  final List<String> images;
  final String ownerId;
  final double width;
  final double height;
  final Map<String, dynamic> layout;
  final bool approved;

  Storage({
    required this.locationId,
    required this.lat,
    required this.lng,
    required this.address,
    required this.detailAddress,
    required this.count,
    required this.createdAt,
    required this.images,
    required this.ownerId,
    required this.width,
    required this.height,
    required this.layout,
    required this.approved,
  });

  factory Storage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final layoutMap = Map<String, dynamic>.from(data['layout'] ?? {});

    final lines =
        (layoutMap['lines'] as List<dynamic>?)
            ?.map((e) => Line.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final doors =
        (layoutMap['doors'] as List<dynamic>?)?.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Offset(
            (map['x'] as num).toDouble(),
            (map['y'] as num).toDouble(),
          );
        }).toSet() ??
        {};

    return Storage(
      locationId: data['locationId'],
      lat: data['lat'],
      lng: data['lng'],
      address: data['address'],
      detailAddress: data['detailAddress'],
      count: data['count'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      images: List<String>.from(data['images']),
      ownerId: data['ownerId'],
      width: data['width'],
      height: data['height'],
      layout: {'lines': lines, 'doors': doors},
      approved: data['approved'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'lat': lat,
      'lng': lng,
      'address': address,
      'detailAddress': detailAddress,
      'count': count,
      'createdAt': createdAt,
      'images': images,
      'ownerId': ownerId,
      'layout': {
        'lines': (layout['lines'] as List<Line>)
            .map((line) => line.toMap())
            .toList(),
        'doors': (layout['doors'] as Set<Offset>)
            .map((offset) => {'x': offset.dx, 'y': offset.dy})
            .toList(),
      },
      'approved': approved,
    };
  }

  Storage copyWith({
    String? locationId,
    double? lat,
    double? lng,
    String? address,
    String? detailAddress,
    int? count,
    DateTime? createdAt,
    List<String>? images,
    String? ownerId,
    double? width,
    double? height,
    Map<String, dynamic>? layout,
  }) {
    return Storage(
      locationId: locationId ?? this.locationId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      detailAddress: detailAddress ?? this.detailAddress,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
      ownerId: ownerId ?? this.ownerId,
      width: width ?? this.width,
      height: height ?? this.height,
      layout: layout ?? this.layout,
      approved: approved,
    );
  }
}

class Line {
  final Offset start;
  final Offset end;

  Line({required this.start, required this.end});

  Map<String, dynamic> toMap() {
    return {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
    };
  }

  factory Line.fromMap(Map<String, dynamic> map) {
    return Line(
      start: Offset(map['start']['x'], map['start']['y']),
      end: Offset(map['end']['x'], map['end']['y']),
    );
  }
}
