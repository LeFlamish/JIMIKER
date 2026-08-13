import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/data/models/usage.dart';

import 'package:jimiker/features/home/menu/history/screens/ended_detail_screen.dart';

import '../services/ended_usages_provider.dart';

class EndedUsageCard extends StatelessWidget {
  final Usage usage;
  final Storage storage;
  final VoidCallback onTap;

  const EndedUsageCard({
    super.key,
    required this.usage,
    required this.storage,
    required this.onTap,
  });

  // 날짜 포맷 (YYYY.MM.DD)
  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  // 총 이용 기간 계산
  int _calculateTotalDays() {
    // 시작일과 종료일의 차이 (최소 1일 보장)
    final diff = usage.endAt.difference(usage.startAt).inDays;
    return diff == 0 ? 1 : diff;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 1. 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFF0F0F0),
                      child: storage.images.isNotEmpty
                          ? CachedImage(
                              imageUrl: storage.images.first,
                              width: 80,
                              height: 80,
                              errorWidget: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.grey,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 2. 주요 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(
                                  6,
                                ),
                              ),
                              child: const Text(
                                "이용 종료",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // 총 일수 표시
                            Text(
                              "총 ${_calculateTotalDays()}일 이용",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          storage.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "보관함 ${usage.containerIndex}번",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. 하단 기간 표시 영역 (티켓 느낌)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "이용 기간",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    "${_formatDate(usage.startAt)} ~ ${_formatDate(usage.endAt)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Screen은 기존과 거의 동일하지만, Card만 교체되었습니다.
// ---------------------------------------------------------

class EndedUsageListScreen extends ConsumerStatefulWidget {
  const EndedUsageListScreen({super.key});

  @override
  ConsumerState<EndedUsageListScreen> createState() =>
      _EndedUsageListScreenState();
}

class _EndedUsageListScreenState
    extends ConsumerState<EndedUsageListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(endedUsagesProvider.notifier).loadEndedUsages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(endedUsagesProvider);
    final items = state.items;

    ref.listen(endedUsagesProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(endedUsagesProvider.notifier)
              .loadEndedUsages(),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? _buildEmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // 수정된 Card 사용
                    return EndedUsageCard(
                      usage: item.usage,
                      storage: item.storage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EndedDetailScreen(
                            ended: item.usage,
                            storage: item.storage,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '이용 기록이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
