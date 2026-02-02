import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/features/home/menu/my_usages/services/my_usages_provider.dart';

enum UsageStatus { active, endingSoon }

class UsageCard extends StatelessWidget {
  final Usage usage;
  final Storage storage;
  final VoidCallback? onSmartKeyTap;
  final VoidCallback? onExtendTap;

  const UsageCard({
    super.key,
    required this.usage,
    required this.storage,
    this.onSmartKeyTap,
    this.onExtendTap,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFF0F0F0),
                    child: storage.images.isNotEmpty
                        ? Image.network(
                            storage.images.first,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) {
                                  return const Icon(
                                    Icons
                                        .image_not_supported_outlined,
                                    color: Colors.grey,
                                    size: 32,
                                  );
                                },
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
                              color: statusColor.withOpacity(0.1),
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
                        "보관함 ${usage.containerIndex} · ~${_formatDate(usage.endAt)}",
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
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSmartKeyTap,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "스마트키",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onExtendTap,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(20),
                  ),
                  child: Container(
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
              ),
            ],
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
                      onSmartKeyTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${item.usage.containerIndex} 보관함 문이 열렸습니다!',
                            ),
                          ),
                        );
                      },
                      onExtendTap: () {
                        debugPrint('연장하기 클릭: ${item.usage.id}');
                      },
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
            '이용 중인 보관함이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
