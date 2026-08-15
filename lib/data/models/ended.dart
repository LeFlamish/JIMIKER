import 'package:cloud_firestore/cloud_firestore.dart';

class Ended {
  final String id;
  final String userId;
  final String ownerId;
  final String storageId;
  final String containerIndex;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;

  /// 계약한 금액. 예약할 때 그 시점의 구역 가격을 박아둔다.
  ///
  /// 주인이 나중에 가격을 바꿔도 이 값은 그대로다. 없으면(null) 이 필드가
  /// 생기기 전에 만들어진 기록이라, 화면이 구역의 현재 가격을 대신 읽는다.
  final int? monthlyPrice;
  final int? months;
  final int? totalPrice;

  Ended({
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

  factory Ended.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ended(
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
