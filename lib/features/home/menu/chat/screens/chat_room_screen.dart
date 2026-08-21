import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/core/utils/image_pick.dart';
import 'package:jimiker/core/utils/kst_time.dart';
import 'package:jimiker/services/notification_service.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';
import 'package:jimiker/features/home/menu/chat/widgets/chat_message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  /// 상대 uid. 아직 Firestore에 없는 방일 때, 첫 메시지와 함께 방을 만들면서
  /// 참여자로 넣어주기 위해 필요하다. (시스템 방처럼 상대가 없으면 null)
  final String? opponentUid;

  /// 입력창에 미리 채워둘 문구. 자동으로 보내지는 않고,
  /// 사용자가 고쳐서 보낼 수 있게 초안만 넣어준다.
  final String? initialMessage;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.opponentUid,
    this.initialMessage,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  /// 목록이 바닥에 붙어 있는지. 붙어 있을 때만 새 메시지를 따라 내려간다.
  /// 옛 대화를 읽으러 위로 올라가 있으면 방해하지 않는다. (카톡과 같은 동작)
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();

    // 보고 있는 방의 메시지는 알림으로 또 띄우지 않는다.
    NotificationService.currentChatRoomId = widget.roomId;
    _scrollController.addListener(_onScroll);

    final draft = widget.initialMessage?.trim();
    if (draft != null && draft.isNotEmpty) {
      _messageController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
  }

  @override
  void dispose() {
    if (NotificationService.currentChatRoomId == widget.roomId) {
      NotificationService.currentChatRoomId = null;
    }
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _stickToBottom = position.maxScrollExtent - position.pixels < 80;
  }

  /// 프레임이 그려진 뒤 목록을 바닥(최신 메시지)으로 내린다.
  void _scrollToBottomIfNeeded() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _sendMessage(ChatService chatService) async {
    if (_isSending) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    await _send(chatService, message: message);
  }

  /// 갤러리에서 사진을 골라 Storage에 올린 뒤 메시지로 보낸다.
  Future<void> _sendPhoto(ChatService chatService) async {
    if (_isSending) return;

    final picked = await pickPhoto();
    if (picked == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('로그인 후 이용해주세요.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final imageUrl = await ChatService.uploadChatImage(
        storage: FirebaseStorage.instance,
        roomId: widget.roomId,
        uid: user.uid,
        file: File(picked.path),
      );

      await _send(
        chatService,
        message: '',
        imageUrl: imageUrl,
        keepSendingFlag: true,
      );
    } catch (error) {
      _showMessage('사진을 보내지 못했어요.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _send(
    ChatService chatService, {
    required String message,
    String? imageUrl,
    bool keepSendingFlag = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('로그인 후 이용해주세요.');
      return;
    }

    if (!keepSendingFlag) setState(() => _isSending = true);
    try {
      // 방이 아직 없으면 여기서 처음 만들어진다.
      // 상대 uid를 같이 넘겨야 상대 목록에도 채팅방이 새로 뜬다.
      await chatService.sendMessage(
        roomId: widget.roomId,
        message: message,
        user: user,
        imageUrl: imageUrl,
        participantUids: [if (widget.opponentUid != null) widget.opponentUid!],
      );

      // 내가 보낸 메시지는 옛 대화를 읽던 중이었어도 바닥으로 따라 내려간다.
      _stickToBottom = true;

      if (message.isNotEmpty) {
        _messageController.clear();
        _focusNode.requestFocus();
      }
    } catch (error) {
      _showMessage('메시지를 보내지 못했어요.');
    } finally {
      if (!keepSendingFlag && mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// 보고 있는 동안 도착한 메시지를 읽음으로 바꾼다.
  ///
  /// 화면을 그리는 도중이라 바로 쓰기를 걸면 안 되고, 프레임이 끝난 뒤에
  /// 보낸다. 실패해도 대화에는 지장이 없으므로 조용히 넘어간다.
  void _markAsRead(
    ChatService chatService,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? uid,
  ) {
    if (uid == null || _isMarkingRead) return;

    final hasUnread = docs.any((doc) {
      final data = doc.data();
      return data['uid'] != uid && data['read'] != true;
    });
    if (!hasUnread) return;

    _isMarkingRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await chatService.markRoomAsRead(
          roomId: widget.roomId,
          uid: uid,
          messages: docs,
        );
      } catch (_) {
        // 네트워크 문제 등. 다음 스냅샷에서 다시 시도된다.
      } finally {
        _isMarkingRead = false;
      }
    });
  }

  bool _isMarkingRead = false;

  /// dm 방인데 참여자 목록에 나 말고 아무도 없으면 상대가 나간 것이다.
  bool _isOpponentMissing(DocumentSnapshot<Map<String, dynamic>>? room) {
    if (room == null || !room.exists) return false;
    final participants =
        (room.data()?['participantUids'] as List<dynamic>?)?.cast<String>() ??
        [];
    return ChatService.opponentMissing(
      roomId: widget.roomId,
      participants: participants,
      myUid: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService(FirebaseFirestore.instance);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatService.streamRoom(widget.roomId),
      builder: (context, roomSnapshot) {
        // 상대가 방을 나갔으면 제목과 말풍선 이름을 「알 수 없음」으로 보여준다.
        final opponentMissing = _isOpponentMissing(roomSnapshot.data);

        return Scaffold(
          appBar: AppBar(
            title: Text(opponentMissing ? '알 수 없음' : widget.roomName),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: chatService.streamMessages(widget.roomId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data?.docs;
                    if (messages == null || messages.isEmpty) {
                      return const Center(child: Text('첫 메시지를 남겨보세요.'));
                    }

                    final docs = ChatService.sortNewestFirst(
                      messages,
                      (doc) => doc.data()['createdAt'] as Timestamp?,
                    );

                    final currentUser = FirebaseAuth.instance.currentUser;
                    _markAsRead(chatService, docs, currentUser?.uid);

                    // 화면은 시간순으로 흐른다: 위가 옛 대화, 아래가 최신.
                    // 방을 열거나 새 메시지가 오면 바닥으로 따라 내려간다.
                    final ordered = docs.reversed.toList();
                    _scrollToBottomIfNeeded();

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: ordered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = ordered[index].data();
                        final isMine = data['uid'] == currentUser?.uid;

                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ChatMessageBubble(
                            isMine: isMine,
                            displayName: !isMine && opponentMissing
                                ? '알 수 없음'
                                : data['displayName']?.toString() ?? '사용자',
                            message: data['message']?.toString() ?? '',
                            imageUrl: data['imageUrl']?.toString(),
                            timeLabel: formatKstTimeOfDay(
                              data['createdAt'] as Timestamp?,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSending
                            ? null
                            : () => _sendPhoto(chatService),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: '사진 보내기',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(chatService),
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending
                            ? null
                            : () => _sendMessage(chatService),
                        icon: const Icon(Icons.send),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
