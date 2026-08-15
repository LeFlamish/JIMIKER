import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/my_storages/screens/reservation_review_screen.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_delete_request.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_edit_config.dart';
import 'package:jimiker/features/home/menu/register_storage/screens/register_storage_screen.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 주인이 자기 창고 하나를 들여다보는 운영 현황판.
///
/// 심사 상태, 구역별로 지금 누가 쓰고 있는지, 들어온 예약 요청까지
/// 한 화면에서 확인하고 편집·삭제 요청으로 이어진다.
class MyStorageDetailScreen extends ConsumerWidget {
  const MyStorageDetailScreen({
    super.key,
    required this.storageId,
    required this.storage,
  });

  final String storageId;

  /// 목록에서 넘겨받은 초기값. 목록 상태가 갱신되면 그쪽을 따라간다.
  final Storage storage;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myStoragesProvider);
    final current = state.storages[storageId] ?? storage;
    final reservations =
        (state.reservationsByStorage[storageId] ?? const [])
            .where((r) => r.status != Status.rejected)
            .toList();
    final zonesAsync = ref.watch(storageZonesProvider(storageId));
    final usagesAsync = ref.watch(storageUsagesProvider(storageId));
    final usages = usagesAsync.value ?? const <Usage>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('내 창고'),
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
            ..._buildBanners(current),
            if (current.images.isNotEmpty) ...[
              DetailPhotoCarousel(images: current.images),
              const SizedBox(height: 16),
            ],
            StorageInfoCard(storage: current),
            const SizedBox(height: 16),
            _buildZoneStatusCard(zonesAsync, reservations, usages),
            const SizedBox(height: 16),
            if (usages.isNotEmpty) ...[
              _buildUsagesCard(usages),
              const SizedBox(height: 16),
            ],
            _buildReservationsCard(context, current, reservations),
            const SizedBox(height: 16),
            StorageLayoutCard(
              storage: current,
              zoneIndex: '',
              description: '등록된 구역 배치입니다.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, ref, current),
    );
  }

  // ==========================
  // 상태 배너
  // ==========================

  List<Widget> _buildBanners(Storage current) {
    final banners = <Widget>[];

    if (current.deleteRequested) {
      banners.add(
        const DetailStatusBanner(
          icon: Icons.delete_outline,
          label: '삭제 요청 검토 중',
          description:
              '운영자가 확인하면 알림으로 알려드려요. 그때까지는 그대로 운영돼요.',
          color: Color(0xFFD32F2F),
          background: Color(0xFFFFEBEE),
        ),
      );
    }

    banners.add(switch (current.reviewStatus) {
      ReviewStatus.pending => const DetailStatusBanner(
        icon: Icons.hourglass_empty,
        label: '심사 대기',
        description: '운영자 승인을 기다리고 있어요. 승인되면 지도에 노출돼요.',
        color: Color(0xFFFF9800),
        background: Color(0xFFFFF3E0),
      ),
      ReviewStatus.approved => const DetailStatusBanner(
        icon: Icons.storefront_outlined,
        label: '운영 중',
        description: '지도와 목록에 노출되고 있어요. 예약을 받을 수 있어요.',
        color: Color(0xFF2E7D32),
        background: Color(0xFFE8F5E9),
      ),
      ReviewStatus.rejected => DetailStatusBanner(
        icon: Icons.cancel_outlined,
        label: '반려됨',
        description: current.rejectReason.isEmpty
            ? '반려된 창고예요. 편집에서 고친 뒤 다시 심사를 요청할 수 있어요.'
            : '사유: ${current.rejectReason}\n편집에서 고친 뒤 다시 심사를 요청할 수 있어요.',
        color: const Color(0xFFD32F2F),
        background: const Color(0xFFFFEBEE),
      ),
    });

    return [
      for (final banner in banners) ...[
        banner,
        const SizedBox(height: 16),
      ],
    ];
  }

  // ==========================
  // 구역별 현황
  // ==========================

  Widget _buildZoneStatusCard(
    AsyncValue<List<Zone>> zonesAsync,
    List<Reservation> reservations,
    List<Usage> usages,
  ) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('구역별 현황'),
          const SizedBox(height: 4),
          Text(
            '구역마다 지금 어떤 상태인지 보여드려요.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          zonesAsync.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              '구역 정보를 불러오지 못했어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            data: (zones) {
              if (zones.isEmpty) {
                return Text(
                  '등록된 구역이 없어요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                );
              }
              return Column(
                children: [
                  for (final zone in zones)
                    _buildZoneRow(zone, reservations, usages),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow(
    Zone zone,
    List<Reservation> reservations,
    List<Usage> usages,
  ) {
    final (label, color, background) = _zoneStatus(
      zone.index,
      reservations,
      usages,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zone.index} 구역 · '
                  '${formatZoneSize(zone.width, zone.height)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '월 ${formatWon(zone.price)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 구역 하나의 현재 상태.
  ///
  /// 이용 중 > 예약 확정 > 요청 대기 > 비어 있음 순서로 본다.
  /// (이용 중인데 다음 예약이 또 잡혀 있어도, 주인에게 급한 건 지금 상태다)
  (String, Color, Color) _zoneStatus(
    String index,
    List<Reservation> reservations,
    List<Usage> usages,
  ) {
    for (final usage in usages) {
      if (usage.containerIndex == index) {
        return (
          '이용 중 · ${_formatDate(usage.endAt)}까지',
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
        );
      }
    }

    Reservation? confirmed;
    var waitingCount = 0;
    for (final reservation in reservations) {
      if (reservation.containerIndex != index) continue;
      if (reservation.status == Status.approved) {
        if (confirmed == null ||
            reservation.startAt.isBefore(confirmed.startAt)) {
          confirmed = reservation;
        }
      } else if (reservation.status == Status.waiting) {
        waitingCount += 1;
      }
    }

    if (confirmed != null) {
      return (
        '예약 확정 · ${_formatDate(confirmed.startAt)} 시작',
        const Color(0xFF1565C0),
        const Color(0xFFE3F2FD),
      );
    }
    if (waitingCount > 0) {
      return (
        '요청 $waitingCount건 대기',
        const Color(0xFFFF9800),
        const Color(0xFFFFF3E0),
      );
    }
    return (
      '비어 있음',
      const Color(0xFF757575),
      const Color(0xFFF0F0F0),
    );
  }

  // ==========================
  // 이용 중인 계약
  // ==========================

  Widget _buildUsagesCard(List<Usage> usages) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('이용 중인 계약'),
          const SizedBox(height: 14),
          for (final usage in usages)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _UserNameText(
                          uid: usage.userId,
                          suffix: '님 · ${usage.containerIndex} 구역',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(usage.startAt)} ~ '
                          '${_formatDate(usage.endAt)}'
                          '${usage.monthlyPrice == null ? '' : ' · 월 ${formatWon(usage.monthlyPrice!)}'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================
  // 예약 요청
  // ==========================

  Widget _buildReservationsCard(
    BuildContext context,
    Storage current,
    List<Reservation> reservations,
  ) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('예약 요청'),
          const SizedBox(height: 14),
          if (reservations.isEmpty)
            Text(
              '들어온 예약 요청이 없어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          else
            Column(
              children: [
                for (final reservation in reservations)
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReservationReviewScreen(
                          storage: current,
                          reservation: reservation,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _UserNameText(
                                  uid: reservation.userId,
                                  suffix:
                                      '님 · ${reservation.containerIndex} 구역',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatDate(reservation.startAt)} ~ '
                                  '${_formatDate(reservation.endAt)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            reservation.status == Status.waiting
                                ? '대기중'
                                : '승인됨',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  reservation.status == Status.waiting
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '탭해서 요청을 검토할 수 있어요.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ==========================
  // 편집 · 삭제 요청
  // ==========================

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    Storage current,
  ) {
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
              flex: 2,
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterStorageScreen(
                        editConfig: StorageEditConfig(
                          storageId: storageId,
                          storage: current,
                        ),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7AF5),
                    side: const BorderSide(color: Color(0xFF6B7AF5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '편집하기',
                    style: TextStyle(
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
                child: OutlinedButton(
                  onPressed: () => showStorageDeleteRequestFlow(
                    context,
                    ref,
                    storageId: storageId,
                    storage: current,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: current.deleteRequested
                          ? Colors.grey
                          : const Color(0xFFD32F2F),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    current.deleteRequested ? '요청 취소' : '삭제 요청',
                    style: TextStyle(
                      color: current.deleteRequested
                          ? Colors.grey[700]
                          : const Color(0xFFD32F2F),
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
}

/// 닉네임을 스트림으로 채워 넣는 한 줄. (로딩 중엔 자리 표시)
class _UserNameText extends ConsumerWidget {
  const _UserNameText({
    required this.uid,
    required this.suffix,
    required this.style,
  });

  final String uid;
  final String suffix;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStreamProvider(uid));
    final name = userAsync.when(
      data: (user) {
        final nickName = user?.nickName.trim() ?? '';
        return nickName.isEmpty ? '알 수 없음' : nickName;
      },
      loading: () => '…',
      error: (_, __) => '알 수 없음',
    );

    return Text(
      '$name$suffix',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
