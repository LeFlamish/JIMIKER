import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 창고 승인 화면. 대기 / 승인됨 / 반려됨을 탭으로 넘긴다.
class StorageReviewScreen extends ConsumerWidget {
  const StorageReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('창고 승인'),
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
          bottom: const TabBar(
            labelColor: Color(0xFF6B7AF5),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF6B7AF5),
            tabs: [
              Tab(text: '대기'),
              Tab(text: '승인됨'),
              Tab(text: '반려됨'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReviewList(status: ReviewStatus.pending),
            _ReviewList(status: ReviewStatus.approved),
            _ReviewList(status: ReviewStatus.rejected),
          ],
        ),
      ),
    );
  }
}

class _ReviewList extends ConsumerWidget {
  const _ReviewList({required this.status});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storagesAsync = ref.watch(
      storagesByReviewProvider(status),
    );

    return storagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '목록을 불러오지 못했어요.\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
        ),
      ),
      data: (storages) {
        if (storages.isEmpty) {
          return Center(
            child: Text(
              switch (status) {
                ReviewStatus.pending => '처리할 신청이 없어요.',
                ReviewStatus.approved => '승인된 창고가 없어요.',
                ReviewStatus.rejected => '반려한 창고가 없어요.',
              },
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          itemCount: storages.length,
          itemBuilder: (context, index) => _StorageRow(
            storage: storages[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    StorageReviewDetailScreen(storage: storages[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.storage, required this.onTap});

  final Storage storage;
  final VoidCallback onTap;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFFF0F0F0),
                  child: storage.images.isNotEmpty
                      ? CachedImage(
                          imageUrl: storage.images.first,
                          width: 64,
                          height: 64,
                        )
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storage.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '구역 ${storage.count}개 · 신청 ${_formatDate(storage.createdAt)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (storage.rejectReason.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '반려 사유: ${storage.rejectReason}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 창고 하나를 자세히 보고 승인/반려한다.
class StorageReviewDetailScreen extends ConsumerStatefulWidget {
  const StorageReviewDetailScreen({super.key, required this.storage});

  final Storage storage;

  @override
  ConsumerState<StorageReviewDetailScreen> createState() =>
      _StorageReviewDetailScreenState();
}

class _StorageReviewDetailScreenState
    extends ConsumerState<StorageReviewDetailScreen> {
  bool _isWorking = false;

  Storage get _storage => widget.storage;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  Future<void> _approve() async {
    final confirmed = await _confirm(
      title: '이 창고를 승인할까요?',
      message: '승인하면 지도와 목록에 바로 노출되고, 등록자에게 알림이 갑니다.',
      actionLabel: '승인',
      actionColor: const Color(0xFF2E7D32),
    );
    if (confirmed != true) return;

    await _run(
      () => ref
          .read(adminActionsProvider)
          .approveStorage(_storage.id ?? ''),
      done: '승인했어요.',
    );
  }

  Future<void> _reject() async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;

    await _run(
      () => ref
          .read(adminActionsProvider)
          .rejectStorage(
            storageId: _storage.id ?? '',
            reason: reason,
          ),
      done: '반려했어요. 등록자에게 사유를 보냈어요.',
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String done,
  }) async {
    setState(() => _isWorking = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      ref.invalidate(adminSummaryProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (mounted) setState(() => _isWorking = false);
      messenger.showSnackBar(
        SnackBar(content: Text('처리하지 못했어요: ${_readableError(error)}')),
      );
    }
  }

  String _readableError(Object error) {
    final text = error.toString();
    // FirebaseFunctionsException의 message만 뽑아 보여준다.
    final match = RegExp(r'message:\s*(.+?)[,)]').firstMatch(text);
    return match?.group(1) ?? text;
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

  Future<String?> _askReason() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('반려 사유'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '적으신 내용이 등록자에게 그대로 전달됩니다.\n무엇을 고쳐야 다시 올릴 수 있는지 적어주세요.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '예) 사진에 창고 내부가 보이지 않습니다.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '닫기',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(controller.text.trim()),
            child: const Text(
              '반려',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerAsync = ref.watch(
      userStreamProvider(_storage.ownerId),
    );
    final zonesAsync = ref.watch(
      storageZonesProvider(_storage.id ?? ''),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('등록 신청 확인'),
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
              DetailPhotoCarousel(images: _storage.images),
              const SizedBox(height: 16),
            ],
            StorageInfoCard(storage: _storage),
            const SizedBox(height: 16),
            // 구역 배치를 봐야 실제로 쓸 수 있는 창고인지 판단이 된다.
            StorageLayoutCard(
              storage: _storage,
              zoneIndex: '',
              description: '등록자가 그린 구역 배치입니다.',
            ),
            const SizedBox(height: 16),
            _buildZonePrices(zonesAsync),
            const SizedBox(height: 16),
            _buildOwnerCard(ownerAsync),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStatusBanner() {
    return switch (_storage.reviewStatus) {
      ReviewStatus.pending => const DetailStatusBanner(
        icon: Icons.hourglass_empty,
        label: '승인 대기',
        description: '아직 심사하지 않은 신청입니다.',
        color: Color(0xFFFF9800),
        background: Color(0xFFFFF3E0),
      ),
      ReviewStatus.approved => DetailStatusBanner(
        icon: Icons.check_circle_outline,
        label: '승인됨',
        description: _storage.reviewedAt == null
            ? '지도와 목록에 노출되고 있습니다.'
            : '${_formatDate(_storage.reviewedAt!)}에 승인했습니다.',
        color: const Color(0xFF2E7D32),
        background: const Color(0xFFE8F5E9),
      ),
      ReviewStatus.rejected => DetailStatusBanner(
        icon: Icons.cancel_outlined,
        label: '반려됨',
        description: _storage.rejectReason.isEmpty
            ? '반려된 신청입니다.'
            : _storage.rejectReason,
        color: const Color(0xFFD32F2F),
        background: const Color(0xFFFFEBEE),
      ),
    };
  }

  Widget _buildZonePrices(AsyncValue<List<dynamic>> zonesAsync) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('구역별 가격'),
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
                  '등록된 구역이 없습니다. 이대로 승인하면 예약할 수 없어요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                );
              }
              return Column(
                children: [
                  for (final zone in zones)
                    DetailInfoRow(
                      label: '${zone.index} 구역',
                      value: '${zone.price}원',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(AsyncValue<dynamic> ownerAsync) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('등록자'),
          const SizedBox(height: 14),
          ownerAsync.when(
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
              '등록자 정보를 불러오지 못했어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            data: (owner) {
              if (owner == null) {
                return Text(
                  '탈퇴했거나 없는 계정입니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                );
              }
              return Column(
                children: [
                  DetailInfoRow(
                    label: '닉네임',
                    value: owner.nickName.isEmpty
                        ? '(없음)'
                        : owner.nickName,
                  ),
                  DetailInfoRow(
                    label: '이메일',
                    value: owner.email.isEmpty ? '(없음)' : owner.email,
                  ),
                  if (owner.createdAt != null)
                    DetailInfoRow(
                      label: '가입일',
                      value: _formatDate(owner.createdAt!),
                    ),
                  if (owner.suspended)
                    const DetailInfoRow(
                      label: '상태',
                      value: '이용 정지된 계정',
                      valueColor: Color(0xFFD32F2F),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isPending = _storage.reviewStatus == ReviewStatus.pending;

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
                child: OutlinedButton(
                  onPressed: _isWorking ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isPending ? '반려' : '반려로 변경',
                    style: const TextStyle(
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
                    disabledBackgroundColor: const Color(0xFFA5C7A7),
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
                      : Text(
                          isPending ? '승인' : '승인으로 변경',
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
}
