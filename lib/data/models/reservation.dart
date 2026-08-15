// 받은사람도 있고 보낸사람도 있다. - userId, ownerId
// 어떤 창고를 예약했는지에 관한 정보 - storageId,containerIndex
// 어떤 기간동안 사용을 예약했는지 알아야한다 - createdAt, startAt, endAt

// 창고에 들어가면 해당 창고에 관한 예약목록을 보여주는데 거기에서 Status가 rejected인거는 안보여준다.

import 'package:cloud_firestore/cloud_firestore.dart';

enum Status { waiting, approved, rejected }

class Reservation {
  final String id;
  final String userId;
  final String ownerId;
  final String storageId;
  final String containerIndex;
  final DateTime createdAt;
  final DateTime startAt;
  final DateTime endAt;
  final Status status;

  /// 계약한 금액. 예약할 때 그 시점의 구역 가격을 박아둔다.
  ///
  /// 주인이 나중에 가격을 바꿔도 이 값은 그대로다. 없으면(null) 이 필드가
  /// 생기기 전에 만들어진 기록이라, 화면이 구역의 현재 가격을 대신 읽는다.
  final int? monthlyPrice;
  final int? months;
  final int? totalPrice;

  Reservation({
    required this.id,
    required this.userId,
    required this.ownerId,
    required this.storageId,
    required this.containerIndex,
    required this.createdAt,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.monthlyPrice,
    this.months,
    this.totalPrice,
  });

  factory Reservation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final statusName =
        data['status']?.toString() ?? Status.waiting.name;

    return Reservation(
      id: doc.id,
      userId: data['userId'],
      ownerId: data['ownerId'],
      storageId: data['storageId']?.toString() ?? '',
      containerIndex: data['containerIndex']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate().toLocal(),
      startAt: (data['startAt'] as Timestamp).toDate().toLocal(),
      endAt: (data['endAt'] as Timestamp).toDate().toLocal(),
      status: Status.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => Status.waiting,
      ),

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
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'startAt': Timestamp.fromDate(startAt.toUtc()),
      'endAt': Timestamp.fromDate(endAt.toUtc()),
      'status': status.name,

      if (monthlyPrice != null) 'monthlyPrice': monthlyPrice,
      if (months != null) 'months': months,
      if (totalPrice != null) 'totalPrice': totalPrice,
    };
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? ownerId,
    String? storageId,
    String? containerIndex,
    DateTime? createdAt,
    DateTime? startAt,
    DateTime? endAt,
    Status? status,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ownerId: ownerId ?? this.ownerId,
      storageId: storageId ?? this.storageId,
      containerIndex: containerIndex ?? this.containerIndex,
      createdAt: createdAt ?? this.createdAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      monthlyPrice: monthlyPrice,
      months: months,
      totalPrice: totalPrice,
    );
  }
}
