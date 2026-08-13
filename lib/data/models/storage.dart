import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

class Storage {
  final String? id;
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

  /// 주인이 내린 창고. 이용/예약 내역이 참조하고 있어서 문서는 남겨두되
  /// 목록·지도·검색에는 노출하지 않는다.
  final bool deleted;
  final DateTime? deletedAt;

  Storage({
    this.id,
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
    this.deleted = false,
    this.deletedAt,
  });

  factory Storage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final layoutMap = Map<String, dynamic>.from(data['layout'] ?? {});

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const FormatException('lat/lng is missing or invalid');
    }

    final width = (data['width'] as num?)?.toDouble() ?? 0;
    final height = (data['height'] as num?)?.toDouble() ?? 0;
    final count = (data['count'] as num?)?.toInt() ?? 0;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate().toLocal() ??
        DateTime.now().toLocal();

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
      id: doc.id,
      locationId: data['locationId'],
      lat: lat,
      lng: lng,
      address: data['address'] ?? '',
      detailAddress: data['detailAddress'] ?? '',
      count: count,
      createdAt: createdAt,
      images: List<String>.from(data['images'] ?? const []),
      ownerId: data['ownerId'] ?? '',
      width: width,
      height: height,
      layout: {'lines': lines, 'doors': doors},
      approved: data['approved'] ?? false,
      deleted: data['deleted'] ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate().toLocal(),
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
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'images': images,
      'ownerId': ownerId,
      'width': width,
      'height': height,
      'layout': {
        'lines': (layout['lines'] as List<Line>)
            .map((line) => line.toMap())
            .toList(),
        'doors': (layout['doors'] as Set<Offset>)
            .map((offset) => {'x': offset.dx, 'y': offset.dy})
            .toList(),
      },
      'approved': approved,
      'deleted': deleted,
      if (deletedAt != null)
        'deletedAt': Timestamp.fromDate(deletedAt!.toUtc()),
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
    bool? deleted,
    DateTime? deletedAt,
  }) {
    return Storage(
      id: id,
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
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
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
      start: Offset(
        (map['start']['x'] as num).toDouble(),
        (map['start']['y'] as num).toDouble(),
      ),
      end: Offset(
        (map['end']['x'] as num).toDouble(),
        (map['end']['y'] as num).toDouble(),
      ),
    );
  }
}
