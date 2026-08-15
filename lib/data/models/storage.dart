import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewStatus { pending, approved, rejected }

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

  /// 건물 실측 크기(m). 도면·구역 좌표도 전부 m 단위다.
  ///
  /// 예전 스키마는 화면 픽셀을 저장했고 Firestore 키도 width/height였다.
  /// 새 스키마는 widthM/heightM 키를 쓴다. 예전 문서를 읽으면 이 값이 0이
  /// 되어 지형도가 "정보 없음"으로 표시된다. (픽셀을 m로 오해하는 것보다 낫다)
  final double width;
  final double height;

  /// `{lines: List<Line>, doors: Set<Offset>}` — 좌표는 전부 m,
  /// 원점은 건물 좌상단이다.
  final Map<String, dynamic> layout;
  final bool approved;

  /// 주인이 내린 창고. 이용/예약 내역이 참조하고 있어서 문서는 남겨두되
  /// 목록·지도·검색에는 노출하지 않는다.
  final bool deleted;
  final DateTime? deletedAt;

  /// 주인이 삭제를 요청한 상태. 삭제는 운영자 승인 절차만 할 수 있어서
  /// (보안 규칙이 delete를 막는다) 주인은 이 표시로 요청만 남긴다.
  /// 운영자가 승인하면 서버가 정리하고, 반려하면 이 표시를 되돌린다.
  final bool deleteRequested;
  final DateTime? deleteRequestedAt;
  final String deleteRequestReason;

  /// 관리자 심사 상태.
  ///
  /// [approved] 하나로는 "아직 심사 안 함"과 "반려됨"이 똑같이 false라
  /// 구분되지 않아서 따로 둔다. approved는 지도·목록이 계속 쓰므로 그대로 유지한다.
  final ReviewStatus reviewStatus;
  final DateTime? reviewedAt;
  final String reviewedBy;
  final String rejectReason;

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
    this.deleteRequested = false,
    this.deleteRequestedAt,
    this.deleteRequestReason = '',
    this.reviewStatus = ReviewStatus.pending,
    this.reviewedAt,
    this.reviewedBy = '',
    this.rejectReason = '',
  });

  factory Storage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final layoutMap = Map<String, dynamic>.from(data['layout'] ?? {});

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const FormatException('lat/lng is missing or invalid');
    }

    // 미터 스키마. 예전(픽셀) 문서에는 widthM이 없어 0으로 읽히고,
    // 화면은 0을 보고 지형도를 그리지 않는다.
    final width = (data['widthM'] as num?)?.toDouble() ?? 0;
    final height = (data['heightM'] as num?)?.toDouble() ?? 0;
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
      deleteRequested: data['deleteRequested'] ?? false,
      deleteRequestedAt: (data['deleteRequestedAt'] as Timestamp?)
          ?.toDate()
          .toLocal(),
      deleteRequestReason:
          data['deleteRequestReason']?.toString() ?? '',
      // 예전 문서에는 reviewStatus가 없다. 그때는 approved로 판단한다.
      reviewStatus: _readReviewStatus(data),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate().toLocal(),
      reviewedBy: data['reviewedBy']?.toString() ?? '',
      rejectReason: data['rejectReason']?.toString() ?? '',
    );
  }

  static ReviewStatus _readReviewStatus(Map<String, dynamic> data) {
    final raw = data['reviewStatus']?.toString();
    if (raw != null) {
      for (final status in ReviewStatus.values) {
        if (status.name == raw) return status;
      }
    }
    return (data['approved'] == true)
        ? ReviewStatus.approved
        : ReviewStatus.pending;
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
      'widthM': width,
      'heightM': height,
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
      'reviewStatus': reviewStatus.name,
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
    bool? deleteRequested,
    String? deleteRequestReason,
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
      deleteRequested: deleteRequested ?? this.deleteRequested,
      deleteRequestedAt: deleteRequestedAt,
      deleteRequestReason:
          deleteRequestReason ?? this.deleteRequestReason,
      reviewStatus: reviewStatus,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      rejectReason: rejectReason,
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
