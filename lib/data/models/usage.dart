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

  Usage({
    required this.id,
    required this.userId,
    required this.ownerId,
    required this.storageId,
    required this.containerIndex,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
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
    };
  }
}
