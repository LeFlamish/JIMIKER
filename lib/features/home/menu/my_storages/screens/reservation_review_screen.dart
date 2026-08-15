import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 주인이 들어온 예약 요청을 검토하는 화면.
///
/// 승인·거절은 사람(신청자)과 조건(구역·기간·금액)을 보고 내리는 판단이라,
/// 목록의 바텀시트 버튼만으로는 부족하다. 여기서 신청자가 누구인지 보고,
/// 궁금한 건 1:1 대화로 물어본 뒤 결정한다.
class ReservationReviewScreen extends ConsumerStatefulWidget {
  const ReservationReviewScreen({
    super.key,
    required this.storage,
    required this.reservation,
  });

  final Storage storage;
  final Reservation reservation;

  @override
  ConsumerState<ReservationReviewScreen> createState() =>
      _ReservationReviewScreenState();
}

class _ReservationReviewScreenState
    extends ConsumerState<ReservationReviewScreen> {
  static const Color _primary = Color(0xFF6B7AF5);

  /// 승인·거절 후 화면이 바로 새 상태를 보여주기 위한 로컬 상태.
  late Status _status = widget.reservation.status;
  bool _isWorking = false;

  Reservation get _reservation => widget.reservation;
  Storage get _storage => widget.storage;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  /// 이용 개월. 예약에 박힌 값을 먼저 쓰고, 없으면 기간에서 어림한다.
  int get _months {
    final saved = _reservation.months;
    if (saved != null && saved > 0) return saved;

    final days = _reservation.endAt
        .difference(_reservation.startAt)
        .inDays;
    return (days / 30).round().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final requesterAsync = ref.watch(
      userStreamProvider(_reservation.userId),
    );
    final zonesAsync = ref.watch(
      storageZonesProvider(_storage.id ?? ''),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('예약 요청 검토'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _buildStatusBanner(),
            const SizedBox(height: 16),
            _buildRequesterCard(requesterAsync),
            const SizedBox(height: 16),
            _buildReservationCard(zonesAsync),
            const SizedBox(height: 16),
            StorageLayoutCard(
              storage: _storage,
              zoneIndex: _reservation.containerIndex,
              description: '색칠된 곳이 신청자가 고른 구역입니다.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStatusBanner() {
    return switch (_status) {
      Status.waiting => const DetailStatusBanner(
        icon: Icons.hourglass_empty,
        label: '승인 대기',
        description: '신청자가 답을 기다리고 있어요. 검토 후 승인하거나 거절해주세요.',
        color: Color(0xFFFF9800),
        background: Color(0xFFFFF3E0),
      ),
      Status.approved => const DetailStatusBanner(
        icon: Icons.check_circle_outline,
        label: '승인됨',
        description: '확정된 예약입니다. 시작일이 되면 이용 중으로 바뀝니다.',
        color: Color(0xFF2E7D32),
        background: Color(0xFFE8F5E9),
      ),
      Status.rejected => const DetailStatusBanner(
        icon: Icons.cancel_outlined,
        label: '거절됨',
        description: '거절한 요청입니다. 신청자가 내역에서 정리할 수 있어요.',
        color: Color(0xFFD32F2F),
        background: Color(0xFFFFEBEE),
      ),
    };
  }

  // ==========================
  // 신청자
  // ==========================

  Widget _buildRequesterCard(AsyncValue<AppUser?> requesterAsync) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('신청자'),
          const SizedBox(height: 14),
          requesterAsync.when(
            loading: () => const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              '신청자 정보를 불러오지 못했어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            data: (requester) {
              if (requester == null) {
                return Text(
                  '탈퇴했거나 없는 계정입니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                );
              }

              final name = requester.nickName.trim().isEmpty
                  ? '이름 없음'
                  : requester.nickName.trim();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CachedAvatar(
                        photoUrl: requester.photoURL,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (requester.createdAt != null)
                              Text(
                                '${_formatDate(requester.createdAt!)} 가입',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (requester.suspended) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '이용이 정지된 계정입니다. 승인 전에 확인해주세요.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        size: 17,
                      ),
                      label: const Text('1:1 채팅으로 물어보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openChat() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    await openDirectChatRoom(
      navigator: Navigator.of(context),
      firestore: ref.read(firestoreProvider),
      uid: uid,
      opponentUid: _reservation.userId,
    );
  }

  // ==========================
  // 예약 조건
  // ==========================

  Widget _buildReservationCard(AsyncValue<List<Zone>> zonesAsync) {
    Zone? zone;
    for (final candidate in zonesAsync.value ?? const <Zone>[]) {
      if (candidate.index == _reservation.containerIndex) {
        zone = candidate;
        break;
      }
    }

    // 계약 금액 스냅샷이 있으면 그것이 정답. 없는 예전 기록만 현재 가격을
    // 대신 읽고, 라벨로 구분한다. (금액이 바뀌었을 수 있어서)
    final agreedMonthly = _reservation.monthlyPrice;
    final monthly = agreedMonthly ?? zone?.price;

    final total =
        _reservation.totalPrice ??
        (monthly == null ? null : monthly * _months);

    final zoneSize = zone == null
        ? null
        : formatZoneSize(zone.width, zone.height);

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('예약 조건'),
          const SizedBox(height: 14),
          DetailInfoRow(
            label: '보관 구역',
            value:
                '${_reservation.containerIndex} 구역'
                '${zoneSize == null ? '' : ' · $zoneSize'}',
          ),
          DetailInfoRow(
            label: '이용 기간',
            value:
                '${_formatDate(_reservation.startAt)} ~ '
                '${_formatDate(_reservation.endAt)}',
          ),
          DetailInfoRow(label: '이용 개월', value: '$_months개월'),
          DetailInfoRow(
            label: '신청일',
            value: _formatDate(_reservation.createdAt),
          ),
          if (monthly != null)
            DetailInfoRow(
              label: agreedMonthly != null ? '월 요금 (계약)' : '현재 월 요금',
              value: formatWon(monthly),
            ),
          if (total != null)
            DetailInfoRow(
              label: '총 금액',
              value: formatWon(total),
              valueColor: _primary,
            ),
        ],
      ),
    );
  }

  // ==========================
  // 승인 · 거절
  // ==========================

  Widget _buildBottomBar() {
    if (_status == Status.rejected) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: _status == Status.waiting
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isWorking ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFD32F2F),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '거절',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isWorking ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          disabledBackgroundColor: const Color(
                            0xFFA5C7A7,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isWorking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                '승인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isWorking ? null : _cancelApproved,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '예약 취소 (거절로 변경)',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _approve() async {
    final confirmed = await _confirm(
      title: '이 예약을 승인할까요?',
      message:
          '승인하면 예약이 확정되고, 그 기간 동안 이 구역에는 다른 예약이 '
          '들어올 수 없어요. 시작일이 되면 자동으로 이용 중으로 바뀝니다.',
      actionLabel: '승인',
      actionColor: const Color(0xFF2E7D32),
    );
    if (confirmed != true) return;

    await _updateStatus(Status.approved, done: '예약을 승인했어요.');
  }

  Future<void> _reject() async {
    final confirmed = await _confirm(
      title: '이 예약을 거절할까요?',
      message: '거절하면 신청자에게 거절됨으로 표시되고, 해당 기간이 다시 열립니다.',
      actionLabel: '거절',
      actionColor: const Color(0xFFD32F2F),
    );
    if (confirmed != true) return;

    await _updateStatus(Status.rejected, done: '예약을 거절했어요.');
  }

  Future<void> _cancelApproved() async {
    final confirmed = await _confirm(
      title: '확정된 예약을 취소할까요?',
      message:
          '신청자는 이 예약이 확정된 것으로 알고 있어요.\n'
          '취소 전에 1:1 채팅으로 사정을 알리는 것을 권해요.\n'
          '취소하면 해당 기간이 다시 열립니다.',
      actionLabel: '예약 취소',
      actionColor: const Color(0xFFD32F2F),
    );
    if (confirmed != true) return;

    await _updateStatus(Status.rejected, done: '예약을 취소했어요.');
  }

  Future<void> _updateStatus(
    Status status, {
    required String done,
  }) async {
    setState(() => _isWorking = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(myStoragesProvider.notifier)
          .updateReservationStatus(
            reservation: _reservation,
            status: status,
          );

      if (!mounted) return;
      setState(() {
        _status = status;
        _isWorking = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('처리하지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '닫기',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              actionLabel,
              style: TextStyle(
                color: actionColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
