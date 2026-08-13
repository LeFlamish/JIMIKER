import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_layout_view.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

/// 창고 기본 정보 카드 (주소 + 크기)
class StorageInfoCard extends StatelessWidget {
  const StorageInfoCard({super.key, required this.storage});

  final Storage storage;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('창고 정보'),
          const SizedBox(height: 14),
          Text(
            storage.address,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
          if (storage.detailAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              storage.detailAddress,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (storage.deleted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '주인이 내린 창고예요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              DetailStatChip(
                icon: Icons.meeting_room_outlined,
                label: '보관구역',
                value: '${storage.count}개',
              ),
              const SizedBox(width: 10),
              DetailStatChip(
                icon: Icons.straighten,
                label: '가로',
                value: '${storage.width.toStringAsFixed(1)}m',
              ),
              const SizedBox(width: 10),
              DetailStatChip(
                icon: Icons.height,
                label: '세로',
                value: '${storage.height.toStringAsFixed(1)}m',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 창고 지형도 카드. 내가 쓰는 구역을 색으로 채워 보여준다.
class StorageLayoutCard extends ConsumerWidget {
  const StorageLayoutCard({
    super.key,
    required this.storage,
    required this.zoneIndex,
    this.description = '색이 채워진 곳이 내가 사용하는 보관 구역이에요.',
  });

  final Storage storage;
  final String zoneIndex;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(
      storageZonesProvider(storage.id ?? ''),
    );

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('창고 지형도'),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          zonesAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _buildPlaceholder('지형도를 불러오지 못했어요.'),
            data: (zones) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StorageLayoutView(
                  storage: storage,
                  zones: zones,
                  highlightedZoneIndex: zoneIndex,
                ),
                const SizedBox(height: 12),
                StorageLayoutLegend(zoneIndex: zoneIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}
