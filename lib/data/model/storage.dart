import 'dart:ui';

class Storage {
  final String locationId;
  final double lat;
  final double lng;
  final String index;
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
    required this.index,
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
}

class Line {
  final Offset start;
  final Offset end;

  Line({required this.start, required this.end});
}
