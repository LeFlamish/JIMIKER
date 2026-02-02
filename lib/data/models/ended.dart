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

  Ended({
    required this.id,
    required this.userId,
    required this.ownerId,
    required this.storageId,
    required this.containerIndex,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
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
