import 'package:flutter/material.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';

class MyStorageCard extends StatelessWidget {
  final Storage storage;
  final List<Reservation> reservations;
  final VoidCallback onEdit;
  final void Function(Reservation reservation, Status status) onReservationAction;

  const MyStorageCard({
    super.key,
    required this.storage,
    required this.reservations,
    required this.onEdit,
    required this.onReservationAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storage.address,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        storage.detailAddress.isEmpty
                            ? '상세 주소 없음'
                            : storage.detailAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(label: '보관함', value: '${storage.count}개'),
                          _InfoChip(
                            label: '가로',
                            value: '${storage.width.toStringAsFixed(1)}m',
                          ),
                          _InfoChip(
                            label: '세로',
                            value: '${storage.height.toStringAsFixed(1)}m',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _StatusBadge(isApproved: storage.approved),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onEdit,
                      child: const Text('편집'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '예약 요청',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (reservations.isEmpty)
              Text(
                '아직 들어온 예약이 없어요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              )
            else
              Column(
                children: reservations
                    .map(
                      (reservation) => _ReservationTile(
                    reservation: reservation,
                    onAction: onReservationAction,
                  ),
                )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isApproved;

  const _StatusBadge({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final color = isApproved ? Colors.green : Colors.orange;
    final label = isApproved ? '승인 완료' : '승인 대기';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final Reservation reservation;
  final void Function(Reservation reservation, Status status) onAction;

  const _ReservationTile({
    required this.reservation,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel(reservation.status);
    final statusColor = _statusColor(reservation.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '보관함 ${reservation.zoneIndex + 1}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(reservation.startAt)} ~ ${_formatDate(reservation.endAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (reservation.status == Status.waiting)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onAction(reservation, Status.rejected),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAction(reservation, Status.approved),
                    child: const Text('승인'),
                  ),
                ),
              ],
            )
          else
            Text(
              '처리 완료',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  String _statusLabel(Status status) {
    switch (status) {
      case Status.waiting:
        return '대기중';
      case Status.approved:
        return '승인됨';
      case Status.rejected:
        return '거절됨';
    }
  }

  Color _statusColor(Status status) {
    switch (status) {
      case Status.waiting:
        return Colors.orange;
      case Status.approved:
        return Colors.green;
      case Status.rejected:
        return Colors.redAccent;
    }
  }
}