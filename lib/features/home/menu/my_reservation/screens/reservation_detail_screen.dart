import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';
import 'package:jimiker/features/home/menu/my_reservation/services/my_reservation_provider.dart';
import 'package:jimiker/features/home/menu/my_reservation/services/storage_zones_provider.dart';
import 'package:jimiker/features/home/menu/my_reservation/widgets/storage_layout_view.dart';
import 'package:jimiker/services/auth_providers.dart';

/// 예약 카드를 눌렀을 때 나오는 상세 화면.
///
/// 창고 지형도에서 내가 빌린 구역을 색으로 보여주고,
/// 창고 주인과 바로 1:1 문의를 하거나 예약을 취소할 수 있다.
class ReservationDetailScreen extends ConsumerStatefulWidget {
  const ReservationDetailScreen({
    super.key,
    required this.reservation,
    required this.storage,
    required this.price,
  });

  final Reservation reservation;
  final Storage storage;

  /// 월 요금. 구역 정보를 못 읽었으면 null.
  final int? price;

  @override
  ConsumerState<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState
    extends ConsumerState<ReservationDetailScreen> {
  static const Color _primaryColor = Color(0xFF6B7AF5);
  static const Color _inputFillColor = Color(0xFFEEF0F5);
  static const Color _dangerColor = Color(0xFFD32F2F);

  bool _isCancelling = false;
  int _photoIndex = 0;

  Reservation get _reservation => widget.reservation;
  Storage get _storage => widget.storage;

  /// 예약 기간(개월). 예약은 시작일에서 개월 수를 더해 만들기 때문에
  /// 연/월 차이로 계산하면 정확히 떨어진다.
  int get _months {
    final months =
        (_reservation.endAt.year - _reservation.startAt.year) * 12 +
        (_reservation.endAt.month - _reservation.startAt.month);
    return months <= 0 ? 1 : months;
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}'
        '.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatWon(int value) {
    return '${NumberFormat('###,###,###,###').format(value)}원';
  }

  ({String label, Color color, Color background, String description})
  get _statusStyle {
    switch (_reservation.status) {
      case Status.approved:
        return (
          label: '예약 확정',
          color: const Color(0xFF2E7D32),
          background: const Color(0xFFE8F5E9),
          description: '창고 주인이 예약을 승인했어요.',
        );
      case Status.waiting:
        return (
          label: '승인 대기',
          color: const Color(0xFFFF9800),
          background: const Color(0xFFFFF3E0),
          description: '창고 주인의 승인을 기다리는 중이에요.',
        );
      case Status.rejected:
        return (
          label: '거절됨',
          color: _dangerColor,
          background: const Color(0xFFFFEBEE),
          description: '창고 주인이 예약을 거절했어요.',
        );
    }
  }

  /// 확정된 예약은 사용자가 마음대로 무를 수 없다.
  /// 창고 주인이 이미 그 기간을 비워둔 상태라 서로 합의가 필요하기 때문에,
  /// 취소는 문의로 요청하고 주인이 처리하도록 한다.
  bool get _canCancelDirectly =>
      _reservation.status != Status.approved;

  Future<void> _openInquiry({String? initialMessage}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showMessage('로그인 후 이용해주세요.');
      return;
    }

    final ownerId = _storage.ownerId;
    if (ownerId.isEmpty) {
      _showMessage('창고 주인 정보를 찾을 수 없어요.');
      return;
    }

    final navigator = Navigator.of(context);
    try {
      await openDirectChatRoom(
        navigator: navigator,
        firestore: ref.read(firestoreProvider),
        uid: user.uid,
        opponentUid: ownerId,
        initialMessage: initialMessage,
      );
    } catch (error) {
      _showMessage('채팅방을 열지 못했어요.');
    }
  }

  /// 확정된 예약의 "취소 요청". 바로 지우지 않고 문의 채팅으로 넘긴다.
  Future<void> _requestCancel() async {
    final wantsInquiry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('확정된 예약이에요'),
        content: const Text(
          '확정된 예약은 바로 취소할 수 없어요.\n'
          '창고 주인에게 문의로 취소를 요청해 주세요.',
          style: TextStyle(height: 1.5),
        ),
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
            child: const Text(
              '문의하기',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (wantsInquiry != true || !mounted) return;

    await _openInquiry(
      initialMessage:
          '예약 취소를 요청드립니다.\n'
          '· 보관 구역: ${_reservation.containerIndex}\n'
          '· 이용 기간: ${_formatDate(_reservation.startAt)} ~ '
          '${_formatDate(_reservation.endAt)}',
    );
  }

  Future<void> _confirmCancel() async {
    final isRejected = _reservation.status == Status.rejected;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(isRejected ? '예약 내역을 삭제할까요?' : '예약을 취소할까요?'),
        content: Text(
          isRejected
              ? '삭제하면 목록에서 사라지고 되돌릴 수 없어요.'
              : '취소하면 되돌릴 수 없어요.\n해당 기간은 다시 예약할 수 있게 됩니다.',
          style: const TextStyle(height: 1.5),
        ),
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
              isRejected ? '삭제' : '예약 취소',
              style: const TextStyle(
                color: _dangerColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(myReservationProvider.notifier)
        .cancelReservation(_reservation.id);

    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (success) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(isRejected ? '예약 내역을 삭제했어요.' : '예약을 취소했어요.'),
        ),
      );
    }
    // 실패하면 provider가 errorMessage를 채우고 목록 화면이 안내한다.
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(
      storageZonesProvider(_storage.id ?? ''),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('예약 상세'),
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
            if (_storage.images.isNotEmpty) ...[
              _buildPhotos(),
              const SizedBox(height: 16),
            ],
            _buildStorageCard(),
            const SizedBox(height: 16),
            _buildLayoutCard(zonesAsync),
            const SizedBox(height: 16),
            _buildReservationCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ------------------------------------------------------------ 상태 배너

  Widget _buildStatusBanner() {
    final style = _statusStyle;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _reservation.status == Status.approved
                  ? Icons.check_circle_outline
                  : _reservation.status == Status.waiting
                  ? Icons.hourglass_empty
                  : Icons.cancel_outlined,
              color: style.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: style.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  style.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: style.color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 사진

  Widget _buildPhotos() {
    final images = _storage.images;

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (index) =>
                    setState(() => _photoIndex = index),
                itemBuilder: (context, index) =>
                    CachedImage(imageUrl: images[index]),
              ),
            ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final isActive = index == _photoIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? _primaryColor
                          : const Color(0xFFD9DCE5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 창고 정보

  Widget _buildStorageCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('창고 정보'),
          const SizedBox(height: 14),
          Text(
            _storage.address,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
          if (_storage.detailAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _storage.detailAddress,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StorageStat(
                icon: Icons.meeting_room_outlined,
                label: '보관구역',
                value: '${_storage.count}개',
              ),
              const SizedBox(width: 10),
              _StorageStat(
                icon: Icons.straighten,
                label: '가로',
                value: '${_storage.width.toStringAsFixed(1)}m',
              ),
              const SizedBox(width: 10),
              _StorageStat(
                icon: Icons.height,
                label: '세로',
                value: '${_storage.height.toStringAsFixed(1)}m',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- 지형도

  Widget _buildLayoutCard(AsyncValue<List<Zone>> zonesAsync) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('창고 지형도'),
          const SizedBox(height: 4),
          Text(
            '색이 채워진 곳이 내가 예약한 보관 구역이에요.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          zonesAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '지형도를 불러오지 못했어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
            data: (zones) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StorageLayoutView(
                  storage: _storage,
                  zones: zones,
                  highlightedZoneIndex: _reservation.containerIndex,
                ),
                const SizedBox(height: 12),
                StorageLayoutLegend(
                  zoneIndex: _reservation.containerIndex,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 예약 정보

  Widget _buildReservationCard() {
    final price = widget.price;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('예약 정보'),
          const SizedBox(height: 14),
          _InfoRow(
            label: '보관 구역',
            value: '${_reservation.containerIndex} 구역',
          ),
          _InfoRow(
            label: '이용 기간',
            value:
                '${_formatDate(_reservation.startAt)} ~ '
                '${_formatDate(_reservation.endAt)}',
          ),
          _InfoRow(label: '이용 개월', value: '$_months개월'),
          _InfoRow(
            label: '월 요금',
            value: price == null ? '정보 없음' : _formatWon(price),
          ),
          _InfoRow(
            label: '신청일',
            value: _formatDate(_reservation.createdAt),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 예상 금액',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              Text(
                price == null ? '-' : _formatWon(price * _months),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- 하단 버튼

  Widget _buildBottomBar() {
    final isRejected = _reservation.status == Status.rejected;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF0F0F0)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: _isCancelling ? null : _openInquiry,
                  style: TextButton.styleFrom(
                    backgroundColor: _inputFillColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: Colors.grey[800],
                  ),
                  label: Text(
                    '1 대 1 문의',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                // 확정된 예약은 바로 지우지 않고 주인에게 취소를 요청한다.
                child: _canCancelDirectly
                    ? _buildCancelButton(
                        label: isRejected ? '내역 삭제' : '예약 취소',
                      )
                    : _buildRequestCancelButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 대기중/거절된 예약: 바로 지운다.
  Widget _buildCancelButton({required String label}) {
    return ElevatedButton(
      onPressed: _isCancelling ? null : _confirmCancel,
      style: ElevatedButton.styleFrom(
        backgroundColor: _dangerColor,
        disabledBackgroundColor: _dangerColor.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isCancelling
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  /// 확정된 예약: 문의로 넘어가기만 한다. 실제로 지우지 않으므로
  /// 채워진 빨간 버튼 대신 테두리만 있는 형태로 약하게 보여준다.
  Widget _buildRequestCancelButton() {
    return OutlinedButton(
      onPressed: _requestCancel,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _dangerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        '취소 요청',
        style: TextStyle(
          color: _dangerColor,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- 공용 조각

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF222222),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  const _StorageStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
