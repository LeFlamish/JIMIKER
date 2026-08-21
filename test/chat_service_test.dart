import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';

/// 정렬 테스트용 가짜 메시지.
class _Msg {
  const _Msg(this.text, this.createdAt);

  final String text;
  final Timestamp? createdAt;
}

void main() {
  group('ChatService.sortNewestFirst', () {
    List<String> order(List<_Msg> messages) => ChatService.sortNewestFirst(
      messages,
      (m) => m.createdAt,
    ).map((m) => m.text).toList();

    Timestamp at(int minute) =>
        Timestamp.fromDate(DateTime.utc(2026, 8, 15, 10, minute));

    test('최신이 앞에 온다', () {
      // reverse: true인 목록에 넣으므로 index 0이 화면 맨 아래(가장 최신)다.
      expect(
        order([
          _Msg('처음', at(0)),
          _Msg('나중', at(5)),
          _Msg('중간', at(3)),
        ]),
        ['나중', '중간', '처음'],
      );
    });

    test('방금 보내 시각이 안 찍힌 메시지가 가장 최신으로 간다', () {
      // serverTimestamp는 서버에 닿기 전까지 null이다. 그동안 내가 쓴 말이
      // 대화 맨 끝으로 밀려나 보이면 안 된다.
      expect(
        order([
          _Msg('이전', at(0)),
          _Msg('방금 보냄', null),
          _Msg('직전', at(9)),
        ]),
        ['방금 보냄', '직전', '이전'],
      );
    });

    test('원본 목록을 건드리지 않는다', () {
      // Firestore가 준 스냅샷 목록은 수정하면 안 된다.
      final messages = [_Msg('a', at(0)), _Msg('b', at(1))];
      ChatService.sortNewestFirst(messages, (m) => m.createdAt);
      expect(messages.map((m) => m.text), ['a', 'b']);
    });

    test('빈 목록도 처리한다', () {
      expect(order(const []), isEmpty);
    });
  });

  group('ChatService.directRoomId', () {
    test('누가 먼저 말을 걸든 같은 방 id가 나온다', () {
      expect(
        ChatService.directRoomId('userA', 'userB'),
        ChatService.directRoomId('userB', 'userA'),
      );
    });

    test('상대가 다르면 방 id도 다르다', () {
      expect(
        ChatService.directRoomId('userA', 'userB'),
        isNot(ChatService.directRoomId('userA', 'userC')),
      );
    });

    test('두 uid를 정렬해 만든다', () {
      expect(
        ChatService.directRoomId('zzz', 'aaa'),
        'dm_aaa_zzz',
      );
    });
  });

  group('ChatService.participantsFromRoomId', () {
    test('dm 방 id에서 두 참여자를 복원한다', () {
      expect(
        ChatService.participantsFromRoomId('dm_aaa_zzz'),
        ['aaa', 'zzz'],
      );
      // directRoomId와 왕복이 된다.
      final roomId = ChatService.directRoomId('userB', 'userA');
      expect(
        ChatService.participantsFromRoomId(roomId),
        ['userA', 'userB'],
      );
    });

    test('dm 방이 아니거나 형태가 다르면 빈 목록', () {
      expect(
        ChatService.participantsFromRoomId('system_userA'),
        isEmpty,
      );
      expect(ChatService.participantsFromRoomId('dm_only'), isEmpty);
      expect(ChatService.participantsFromRoomId('dm__zzz'), isEmpty);
      expect(
        ChatService.participantsFromRoomId('dm_a_b_c'),
        isEmpty,
      );
    });
  });

  group('ChatService.mergeParticipants', () {
    test('방을 나간 사람은 남이 메시지를 보내도 되살아나지 않는다', () {
      // zzz가 방을 나간 상태에서 aaa가 메시지를 보낸다.
      // 호출자가 상대 uid를 넘겨도, 방 id에 상대가 박혀 있어도 안 된다.
      expect(
        ChatService.mergeParticipants(
          roomId: 'dm_aaa_zzz',
          existing: ['aaa'],
          requested: ['zzz'],
          left: ['zzz'],
          senderUid: 'aaa',
        ),
        ['aaa'],
      );
    });

    test('나갔던 사람이 직접 말을 걸면 그 순간 복귀한다', () {
      expect(
        ChatService.mergeParticipants(
          roomId: 'dm_aaa_zzz',
          existing: ['aaa'],
          requested: [],
          left: ['zzz'],
          senderUid: 'zzz',
        ).toSet(),
        {'aaa', 'zzz'},
      );
    });

    test('참여자가 한 명뿐인 옛 방은 방 id로 복구된다', () {
      // 예전 버그로 만들어진 방: 아무도 나간 적이 없는데 상대가 빠져 있다.
      expect(
        ChatService.mergeParticipants(
          roomId: 'dm_aaa_zzz',
          existing: ['aaa'],
          requested: [],
          left: [],
          senderUid: 'aaa',
        ).toSet(),
        {'aaa', 'zzz'},
      );
    });

    test('빈 uid는 끼어들지 못한다', () {
      expect(
        ChatService.mergeParticipants(
          roomId: 'system_aaa',
          existing: ['aaa', ''],
          requested: [''],
          left: [],
          senderUid: 'aaa',
        ),
        ['aaa'],
      );
    });
  });

  group('ChatService.opponentMissing', () {
    test('dm 방 참여자에 나만 남으면 상대가 나간 것', () {
      expect(
        ChatService.opponentMissing(
          roomId: 'dm_aaa_zzz',
          participants: ['aaa'],
          myUid: 'aaa',
        ),
        isTrue,
      );
    });

    test('상대가 남아 있으면 정상', () {
      expect(
        ChatService.opponentMissing(
          roomId: 'dm_aaa_zzz',
          participants: ['aaa', 'zzz'],
          myUid: 'aaa',
        ),
        isFalse,
      );
    });

    test('내가 나갔던 방을 다시 열면 상대는 그대로 보인다', () {
      // 참여자 목록에 상대만 남은 상태를 "상대가 나감"으로 착각하면 안 된다.
      expect(
        ChatService.opponentMissing(
          roomId: 'dm_aaa_zzz',
          participants: ['zzz'],
          myUid: 'aaa',
        ),
        isFalse,
      );
    });

    test('시스템 방에는 적용하지 않는다', () {
      expect(
        ChatService.opponentMissing(
          roomId: 'system_aaa',
          participants: ['aaa'],
          myUid: 'aaa',
        ),
        isFalse,
      );
    });
  });
}
