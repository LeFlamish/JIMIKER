import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/reservation_card.dart';
import 'package:jimiker/services/auth_providers.dart';

import '../../../../../data/models/storage.dart';
import '../../../../../data/models/zone.dart';
import '../../../../draw/draw_provider.dart';
import '../../../../draw/structure_screen.dart';
import '../../../../draw/zone_provider.dart';

/// 지도 마커를 눌렀을 때 뜨는 창고 소개 시트.
///
/// 소비자가 3초 안에 판단할 것: 어디에 있고(주소), 얼마부터고(최저가),
/// 어떤 곳인지(사진). 그다음에 구역을 골라 예약으로 넘어간다.
class StorageBottomSheet extends ConsumerStatefulWidget {
  final String? imageUrl;
  final Storage storage;

  const StorageBottomSheet({
    super.key,
    required this.imageUrl,
    required this.storage,
  });

  @override
  ConsumerState<StorageBottomSheet> createState() =>
      _StorageBottomSheetState();
}

class _StorageBottomSheetState
    extends ConsumerState<StorageBottomSheet> {
  static const double _minExtent = 0.22;
  static const double _initialExtent = 0.48;
  static const double _maxExtent = 0.88;
  static const List<double> _snapPoints = <double>[
    _minExtent,
    _initialExtent,
    _maxExtent,
  ];

  static const Color _primary = Color(0xFF6B66FF);

  double _currentExtent = _initialExtent;
  bool _isDragging = false;
  int _photoIndex = 0;

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double dragDelta = (details.primaryDelta ?? 0) * -1;
    final double screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight == 0) return;

    final double deltaExtent = dragDelta / screenHeight;
    setState(() {
      _currentExtent = (_currentExtent + deltaExtent).clamp(
        _minExtent,
        _maxExtent,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    const double snapTolerance = 0.07;
    const double velocityThreshold = 700;
    final double velocity = details.velocity.pixelsPerSecond.dy;

    final bool isNearInitial =
        (_currentExtent - _initialExtent).abs() <= snapTolerance;

    double target;

    if (velocity.abs() >= velocityThreshold) {
      if (velocity < 0) {
        final List<double> higher =
            _snapPoints.where((p) => p > _currentExtent).toList()
              ..sort();
        target = higher.isNotEmpty ? higher.first : _maxExtent;
      } else {
        final List<double> lower =
            _snapPoints.where((p) => p < _currentExtent).toList()
              ..sort();
        target = lower.isNotEmpty ? lower.last : _minExtent;
      }
    } else {
      target = isNearInitial
          ? _initialExtent
          : _snapPoints.reduce(
              (a, b) =>
                  (a - _currentExtent).abs() <
                      (b - _currentExtent).abs()
                  ? a
                  : b,
            );
    }

    setState(() {
      _currentExtent = target;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.storage;
    final zones = ref.watch(zoneProvider);
    final selectedZone = ref.watch(selectedZoneProvider);

    return AnimatedFractionallySizedBox(
      heightFactor: _currentExtent,
      duration: _isDragging
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(storage, zones),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildPhotoCarousel(storage.images),
                      const SizedBox(height: 14),
                      _buildSummaryBar(storage, zones),
                      const SizedBox(height: 18),
                      _buildOwnerRow(storage.ownerId),
                      const SizedBox(height: 18),
                      _buildSectionTitle('구역 고르기'),
                      const SizedBox(height: 4),
                      Text(
                        '도면이나 아래 목록에서 원하는 구역을 선택하세요.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      StructureScreen(
                        drawState: DrawProviderData(
                          lines: storage.layout['lines'],
                          doors: storage.layout['doors'],
                          width: storage.width,
                          height: storage.height,
                          isDraw: false,
                        ),
                      ),
                      if (zones.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildZoneChips(zones, selectedZone),
                      ],
                      const SizedBox(height: 16),
                      if (selectedZone == null)
                        _buildSelectHint()
                      else
                        ReservationCard(storage: storage),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================
  // 머리: 주소 + 최저가 (접혀 있어도 보이는 부분)
  // ==========================

  Widget _buildHeader(Storage storage, List<Zone> zones) {
    final minPrice = _minPrice(zones);
    final hasRange =
        zones.length > 1 &&
        zones.any((zone) => zone.price != zones.first.price);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storage.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    if (storage.detailAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        storage.detailAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (minPrice != null) ...[
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '월 ${formatWon(minPrice)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                            if (hasRange)
                              TextSpan(
                                text: '부터',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int? _minPrice(List<Zone> zones) {
    if (zones.isEmpty) return null;
    return zones
        .map((zone) => zone.price)
        .reduce((a, b) => a < b ? a : b);
  }

  // ==========================
  // 사진: 넘겨볼 수 있는 캐러셀
  // ==========================

  Widget _buildPhotoCarousel(List<String> images) {
    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: const Color(0xFFF0F1F5),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_outlined,
                  size: 32,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 6),
                Text(
                  '등록된 사진이 없어요',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (index) =>
                      setState(() => _photoIndex = index),
                  itemBuilder: (context, index) => CachedImage(
                    imageUrl: images[index],
                    errorWidget: Container(
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_photoIndex + 1}/${images.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _photoIndex ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i == _photoIndex
                        ? _primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ==========================
  // 요약: 구역 수 · 건물 크기 · 총면적
  // ==========================

  Widget _buildSummaryBar(Storage storage, List<Zone> zones) {
    final hasSize = storage.width > 0 && storage.height > 0;
    final area = storage.width * storage.height;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: '보관 구역',
            value: '${zones.isEmpty ? storage.count : zones.length}개',
          ),
          _summaryDivider(),
          _SummaryItem(
            label: '건물 크기',
            value: hasSize
                ? formatZoneSize(storage.width, storage.height)
                : '정보 없음',
          ),
          _summaryDivider(),
          _SummaryItem(
            label: '전체 면적',
            value: hasSize
                ? '${area.toStringAsFixed(0)}㎡'
                : '정보 없음',
            caption: hasSize
                ? '약 ${(area / 3.3058).toStringAsFixed(1)}평'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 30,
      color: const Color(0xFFE3E5EC),
    );
  }

  // ==========================
  // 주인
  // ==========================

  Widget _buildOwnerRow(String ownerId) {
    if (ownerId.isEmpty) return const SizedBox.shrink();

    final ownerAsync = ref.watch(userStreamProvider(ownerId));
    final owner = ownerAsync.value;
    if (owner == null) return const SizedBox.shrink();

    final name = owner.nickName.trim().isEmpty
        ? '창고 주인'
        : owner.nickName.trim();

    return Row(
      children: [
        CachedAvatar(photoUrl: owner.photoURL, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$name님의 창고',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
        ),
        Text(
          '예약하면 1:1 대화가 열려요',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ==========================
  // 구역 목록: 가격 비교용 가로 스크롤
  // ==========================

  Widget _buildZoneChips(List<Zone> zones, String? selectedZone) {
    final sorted = [...zones]
      ..sort((a, b) => a.index.compareTo(b.index));

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final zone = sorted[index];
          final isSelected = zone.index == selectedZone;

          return GestureDetector(
            onTap: () {
              ref.read(selectedZoneProvider.notifier).state =
                  zone.index;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 118,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFEEFF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _primary
                      : const Color(0xFFE3E5EC),
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        zone.index,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? _primary
                              : const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatZoneSize(zone.width, zone.height),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '월 ${formatWon(zone.price)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? _primary
                          : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    formatPricePerSqm(
                      zone.price,
                      zone.width * zone.height,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 18, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '구역을 선택하면 날짜를 골라 예약할 수 있어요.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF222222),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }
}
