import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/features/home/menu/my_usages/screen/usage_detail_screen.dart';
import 'package:jimiker/features/home/menu/my_usages/services/my_usages_provider.dart';

enum UsageStatus { active, endingSoon }

class UsageCard extends StatelessWidget {
  final Usage usage;
  final Storage storage;
  final VoidCallback? onExtendTap;

  /// 카드 윗부분(창고 정보)을 누르면 이용 상세로 이동한다.
  /// 아래 연장 버튼은 따로 동작이 있어서 제외한다.
  final VoidCallback? onTap;

  const UsageCard({
    super.key,
    required this.usage,
    required this.storage,
    this.onExtendTap,
    this.onTap,
  });

  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  int _calculateDDay() {
    final now = DateTime.now();
    final endDate = DateTime(
      usage.endAt.year,
      usage.endAt.month,
      usage.endAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return endDate.difference(today).inDays;
  }

  UsageStatus _statusFromDDay(int dDay) {
    if (dDay <= 3) return UsageStatus.endingSoon;
    return UsageStatus.active;
  }

  @override
  Widget build(BuildContext context) {
    final dDay = _calculateDDay();
    final status = _statusFromDDay(dDay);

    Color statusColor;
    String statusText;
    String dDayText;

    if (status == UsageStatus.endingSoon) {
      statusColor = const Color(0xFFFF9800);
      statusText = "종료 임박";
      dDayText = "D-$dDay";
    } else {
      statusColor = const Color(0xFF6B7AF5);
      statusText = "이용 중";
      dDayText = "D-$dDay";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
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
                              size: 32,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            dDayText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${usage.containerIndex} 구역 · ~${_formatDate(usage.endAt)}",
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
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          InkWell(
            onTap: onExtendTap,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.update_rounded,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "이용 연장",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UsageListScreen extends ConsumerStatefulWidget {
  const UsageListScreen({super.key});

  @override
  ConsumerState<UsageListScreen> createState() =>
      _UsageListScreenState();
}

class _UsageListScreenState extends ConsumerState<UsageListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(myUsagesProvider.notifier).loadMyUsages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myUsagesProvider);
    final items = state.items;

    ref.listen(myUsagesProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message.isEmpty) return;
      if (message == previous?.errorMessage) return;
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(myUsagesProvider.notifier).loadMyUsages(),
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
                    return UsageCard(
                      usage: item.usage,
                      storage: item.storage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UsageDetailScreen(
                            usage: item.usage,
                            storage: item.storage,
                          ),
                        ),
                      ),
                      // 연장은 아직 화면이 없다. 실제로 되는 것처럼
                      // 보이지 않게 안내만 하고, 주인과 이야기하도록 넘긴다.
                      onExtendTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '연장은 준비 중이에요. 창고 주인에게 1:1 문의로 요청해주세요.',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ListView라야 빈 화면에서도 당겨서 새로고침이 된다.
  Widget _buildEmptyView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.inventory_2_outlined,
          size: 56,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          '이용 중인 창고가 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
