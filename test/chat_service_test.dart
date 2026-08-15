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
}
