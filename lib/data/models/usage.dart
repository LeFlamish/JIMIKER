import 'package:cloud_firestore/cloud_firestore.dart';

class Usage {
  final String id;
  // 참여자
  final String userId;
  final String ownerId;
  // 대상
  final String storageId;
  final String containerIndex;
  // 기간(계약/합의된 사용 기간)
  final DateTime startAt;
  final DateTime endAt;
  // 예약을 신청한 시점. 예약 문서에서 그대로 물려받는다.
  // (이용 중으로 전환된 시점은 Functions가 activatedAt에 따로 남긴다.)
  final DateTime createdAt;

  /// 계약한 금액. 예약할 때 그 시점의 구역 가격을 박아둔다.
  ///
  /// 주인이 나중에 가격을 바꿔도 이 값은 그대로다. 없으면(null) 이 필드가
  /// 생기기 전에 만들어진 기록이라, 화면이 구역의 현재 가격을 대신 읽는다.
  final int? monthlyPrice;
  final int? months;
  final int? totalPrice;

  Usage({
    required this.id,
    required this.userId,
    required this.ownerId,
    required this.storageId,
    required this.containerIndex,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.monthlyPrice,
    this.months,
    this.totalPrice,
  });

  factory Usage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Usage(
      id: doc.id,
      userId: data['userId'],
      ownerId: data['ownerId'],
      storageId: data['storageId'],
      containerIndex: data['containerIndex'],
      startAt: (data['startAt'] as Timestamp).toDate().toLocal(),
      endAt: (data['endAt'] as Timestamp).toDate().toLocal(),
      createdAt: (data['createdAt'] as Timestamp).toDate().toLocal(),

      monthlyPrice: (data['monthlyPrice'] as num?)?.toInt(),
      months: (data['months'] as num?)?.toInt(),
      totalPrice: (data['totalPrice'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ownerId': ownerId,
      'storageId': storageId,
      'containerIndex': containerIndex,
      'startAt': Timestamp.fromDate(startAt.toUtc()),
      'endAt': Timestamp.fromDate(endAt.toUtc()),
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),

      if (monthlyPrice != null) 'monthlyPrice': monthlyPrice,
      if (months != null) 'months': months,
      if (totalPrice != null) 'totalPrice': totalPrice,
    };
  }
}
