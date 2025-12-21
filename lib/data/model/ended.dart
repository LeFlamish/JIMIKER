class Ended {
  final String id;

  // 참여자
  final String userId;
  final String ownerId;

  // 대상
  final int storageId;
  final int containerIndex;

  // 기간(계약/합의된 사용 기간)
  final DateTime startAt;
  final DateTime endAt;

  // 승인/생성 메타
  final DateTime createdAt; // 소유자가 승인한 시점(사용중으로 전환된 시점)

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
}
