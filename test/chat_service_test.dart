import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';

void main() {
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
