import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/kst_time.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 이용 중인 창고 카드를 눌렀을 때 나오는 화면.
///
/// 어느 창고의 어느 구역을 언제까지 쓰고 있는지 보여주고,
/// 창고 주인에게 바로 문의할 수 있다.
class UsageDetailScreen extends ConsumerWidget {
  const UsageDetailScreen({
    super.key,
    required this.usage,
    required this.storage,
  });

  final Usage usage;
  final Storage storage;

  static const Color _primaryColor = Color(0xFF6B7AF5);
  static const Color _inputFillColor = Color(0xFFEEF0F5);

  /// 종료까지 남은 일수. 이미 지났으면 음수.
  int get _daysLeft {
    final today = _dateOnly(nowKst());
    final end = _dateOnly(toKst(usage.endAt));
    return end.difference(today).inDays;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}'
        '.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('이용 정보'),
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
            if (storage.images.isNotEmpty) ...[
              DetailPhotoCarousel(images: storage.images),
              const SizedBox(height: 16),
            ],
            StorageInfoCard(storage: storage),
            const SizedBox(height: 16),
            StorageLayoutCard(
              storage: storage,
              zoneIndex: usage.containerIndex,
            ),
            const SizedBox(height: 16),
            _buildUsageCard(ref),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, ref),
    );
  }

  Widget _buildStatusBanner() {
    final daysLeft = _daysLeft;

    if (daysLeft < 0) {
      return const DetailStatusBanner(
        icon: Icons.event_busy,
        label: '이용 기간 종료',
        description: '이용 기간이 지났어요. 주인과 정리해주세요.',
        color: Color(0xFFD32F2F),
        background: Color(0xFFFFEBEE),
      );
    }

    return DetailStatusBanner(
      icon: Icons.inventory_2_outlined,
      label: '이용 중',
      description: daysLeft == 0
          ? '오늘 이용이 끝나요.'
          : '이용 종료까지 $daysLeft일 남았어요.',
      color: const Color(0xFF2E7D32),
      background: const Color(0xFFE8F5E9),
    );
  }

  Widget _buildUsageCard(WidgetRef ref) {
    final zonesAsync = ref.watch(
      storageZonesProvider(storage.id ?? ''),
    );
    final price = zonesAsync.maybeWhen(
      data: (zones) {
        for (final zone in zones) {
          if (zone.index == usage.containerIndex) return zone.price;
        }
        return null;
      },
      orElse: () => null,
    );

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('이용 정보'),
          const SizedBox(height: 14),
          DetailInfoRow(
            label: '보관 구역',
            value: '${usage.containerIndex} 구역',
          ),
          DetailInfoRow(
            label: '이용 기간',
            value:
                '${_formatDate(usage.startAt)} ~ '
                '${_formatDate(usage.endAt)}',
          ),
          DetailInfoRow(
            label: '신청일',
            value: _formatDate(usage.createdAt),
          ),
          DetailInfoRow(
            label: '월 요금',
            value: price == null ? '정보 없음' : '$price원',
          ),
          DetailInfoRow(
            label: '남은 기간',
            value: _daysLeft < 0 ? '기간 종료' : '$_daysLeft일',
            valueColor: _daysLeft < 0
                ? const Color(0xFFD32F2F)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _openInquiry(context, ref),
            style: TextButton.styleFrom(
              backgroundColor: _inputFillColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: _primaryColor,
            ),
            label: const Text(
              '창고 주인에게 문의',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
