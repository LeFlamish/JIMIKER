import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_room_screen.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_screen.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';

/// 상대와의 1:1 채팅방을 연다.
///
/// 이미 상대와의 방이 있으면 그 방을 그대로 열고, 없으면 새 방 id만 만들어 들어간다.
/// 이 시점에는 Firestore에 아무것도 쓰지 않기 때문에, 아무 말도 안 하고 나오면
/// 방은 저장되지 않는다. (첫 메시지를 보내는 순간 방이 만들어진다.)
///
/// 화면이 사라진 뒤에도 이동할 수 있도록 [BuildContext] 대신
/// [NavigatorState]를 미리 받아둔다.
Future<void> openDirectChatRoom({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required String uid,
  required String opponentUid,
}) async {
  final chatService = ChatService(firestore);

  final roomId = await chatService.resolveDirectRoomId(
    uid: uid,
    opponentUid: opponentUid,
  );

  final opponentSnapshot = await firestore
      .collection('users')
      .doc(opponentUid)
      .get();
  final opponentName = opponentSnapshot
      .data()?['nickName']
      ?.toString()
      .trim();
  final roomName = (opponentName == null || opponentName.isEmpty)
      ? '지미커'
      : opponentName;

  // 뒤로 가면 채팅 목록이 보이도록 목록 → 방 순서로 쌓는다.
  navigator.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        roomId: roomId,
        roomName: roomName,
        opponentUid: opponentUid,
      ),
    ),
  );
}
