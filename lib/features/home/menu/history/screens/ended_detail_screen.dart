import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/storage_bottom_sheet.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 이용 내역 카드를 눌렀을 때 나오는 화면.
///
/// 언제 어느 창고의 어느 구역을 썼는지 보여주고,
/// 마음에 들었으면 '다시 이용'으로 곧장 예약 화면을 연다.
class EndedDetailScreen extends ConsumerWidget {
  const EndedDetailScreen({
    super.key,
    required this.ended,
    required this.storage,
  });

  /// 종료된 이용 건. endeds 컬렉션도 usages와 같은 모양이라 Usage로 읽는다.
  final Usage ended;
  final Storage storage;

  static const Color _primaryColor = Color(0xFF6B7AF5);
  static const Color _inputFillColor = Color(0xFFEEF0F5);

  int get _months {
    final months =
        (ended.endAt.year - ended.startAt.year) * 12 +
        (ended.endAt.month - ended.startAt.month);
    return months <= 0 ? 1 : months;
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}'
        '.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('이용 내역'),
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
            DetailStatusBanner(
              icon: Icons.check_circle_outline,
              label: '이용 완료',
              description:
                  '${_formatDate(ended.startAt)}부터 $_months개월 이용했어요.',
              color: Colors.grey.shade700,
              background: const Color(0xFFEEEFF3),
            ),
            const SizedBox(height: 16),
            if (storage.images.isNotEmpty) ...[
              DetailPhotoCarousel(images: storage.images),
              const SizedBox(height: 16),
            ],
            StorageInfoCard(storage: storage),
            const SizedBox(height: 16),
            StorageLayoutCard(
              storage: storage,
              zoneIndex: ended.containerIndex,
              description: '색이 채워진 곳이 그때 사용했던 보관 구역이에요.',
            ),
            const SizedBox(height: 16),
            _buildHistoryCard(ref),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, ref),
    );
  }

  Widget _buildHistoryCard(WidgetRef ref) {
    // 계약할 때 박아둔 금액이 있으면 그것이 정답이다.
    // 없는 건 이 필드가 생기기 전 기록이라, 그때만 구역의 현재 가격을
    // 대신 읽는다. 주인이 그 사이 가격을 바꿨으면 다를 수 있어 표시로 알린다.
    final agreedPrice = ended.monthlyPrice;
    final zonesAsync = agreedPrice != null
        ? null
        : ref.watch(storageZonesProvider(storage.id ?? ''));
    final currentPrice = zonesAsync?.maybeWhen(
      data: (zones) {
        for (final zone in zones) {
          if (zone.index == ended.containerIndex) return zone.price;
        }
        return null;
      },
      orElse: () => null,
    );

    final price = agreedPrice ?? currentPrice;

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('이용 기록'),
          const SizedBox(height: 14),
          DetailInfoRow(
            label: '보관 구역',
            value: '${ended.containerIndex} 구역',
          ),
          DetailInfoRow(
            label: '이용 기간',
            value:
                '${_formatDate(ended.startAt)} ~ '
                '${_formatDate(ended.endAt)}',
          ),
          DetailInfoRow(label: '이용 개월', value: '$_months개월'),
          DetailInfoRow(
            label: agreedPrice != null ? '계약 월 요금' : '현재 월 요금',
            value: price == null ? '정보 없음' : '$price원',
          ),
          if (ended.totalPrice != null)
            DetailInfoRow(
              label: '총 이용 금액',
              value: '${ended.totalPrice}원',
            ),
          if (agreedPrice == null && price != null)
            const DetailInfoRow(
              label: '',
              value: '이 기록에는 계약 금액이 없어 현재 가격을 보여줍니다.',
              valueColor: Color(0xFF888888),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    // 주인이 내린 창고는 더 이상 예약할 수 없다.
    final canReserveAgain = !storage.deleted && storage.approved;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: () => _openInquiry(context, ref),
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
                    '문의',
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
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canReserveAgain
                      ? () => _reserveAgain(context, ref)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: const Color(0xFFC7CCE0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    canReserveAgain ? '다시 이용하기' : '지금은 예약할 수 없어요',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 그 창고의 예약 화면을 연다.
  ///
  /// 예약 UI(StorageBottomSheet)는 지도에서 쓰던 것과 같은 것을 그대로 쓴다.
  /// 구역 정보를 zoneProvider에 올려줘야 지형도와 가격이 뜨기 때문에
  /// 지도에서 하던 것과 동일하게 준비한 뒤 띄운다.
  Future<void> _reserveAgain(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final storageId = storage.id;
    if (storageId == null || storageId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('창고 정보를 찾을 수 없어요.')),
      );
      return;
    }

    List<Zone> zones;
    try {
      zones = await ref.read(storageZonesProvider(storageId).future);
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('구역 정보를 불러오지 못했어요.')),
      );
      return;
    }

    if (!context.mounted) return;

    ref.read(zoneProvider.notifier).setZones(zones);
    // 지난번에 쓰던 구역을 미리 골라둔다. 없으면 선택 없이 시작.
    final hasSameZone = zones.any(
      (zone) => zone.index == ended.containerIndex,
    );
    ref.read(selectedZoneProvider.notifier).state = hasSameZone
        ? ended.containerIndex
        : null;

    showModalBottomSheet<void>(
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StorageBottomSheet(
        imageUrl: storage.images.isNotEmpty
            ? storage.images.first
            : null,
        storage: storage,
      ),
    );
  }

  Future<void> _openInquiry(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    final messenger = ScaffoldMessenger.of(context);

    if (user == null || storage.ownerId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('창고 주인 정보를 찾을 수 없어요.')),
      );
      return;
    }

    try {
      await openDirectChatRoom(
        navigator: Navigator.of(context),
        firestore: ref.read(firestoreProvider),
        uid: user.uid,
        opponentUid: storage.ownerId,
      );
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('채팅방을 열지 못했어요.')),
      );
    }
  }
}
