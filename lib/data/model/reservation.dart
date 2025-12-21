// 받은사람도 있고 보낸사람도 있다. - userId, ownerId
// 어떤 창고를 예약했는지에 관한 정보 - storageId,containerIndex
// 어떤 기간동안 사용을 예약했는지 알아야한다 - createdAt, startAt, endAt

// 창고에 들어가면 해당 창고에 관한 예약목록을 보여주는데 거기에서 Status가 rejected인거는 안보여준다.

enum Status { waiting, rejected }

class Reservation {
  final String id;
  final String userId;
  final String ownerId;
  final int storageId;
  final int containerIndex;
  final DateTime createdAt;
  final DateTime startAt;
  final DateTime endAt;
  final Status status;

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
  });
}
