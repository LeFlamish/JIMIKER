import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/services/auth_providers.dart';

class MyReservationItem {
  final Reservation reservation;
  final Storage storage;
  final int? price;

  const MyReservationItem({
    required this.reservation,
    required this.storage,
    required this.price,
  });
}

class MyReservationState {
  final List<MyReservationItem> items;
  final bool isLoading;
  final String? errorMessage;

  const MyReservationState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MyReservationState copyWith({
    List<MyReservationItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MyReservationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final myReservationProvider =
    NotifierProvider<MyReservationNotifier, MyReservationState>(
      MyReservationNotifier.new,
    );

class MyReservationNotifier extends Notifier<MyReservationState> {
  @override
  MyReservationState build() => const MyReservationState();

  Future<void> loadMyReservations() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '로그인이 필요합니다.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final firestore = ref.read(firestoreProvider);
      final reservationsSnapshot = await firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .get();

      final reservations = reservationsSnapshot.docs
          .map(Reservation.fromDoc)
          .toList();

      reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final storageIds = reservations
          .map((item) => item.storageId)
          .toSet();
      final storagesById = await _fetchStorages(storageIds);

      final items = await Future.wait(
        reservations.map((reservation) async {
          final storage = storagesById[reservation.storageId];
          if (storage == null) {
            debugPrint(
              'Missing storage for reservation ${reservation.id}',
            );
            return null;
          }

          final price = await _price(reservation);
          return MyReservationItem(
            reservation: reservation,
            storage: storage,
            price: price,
          );
        }),
      );

      state = state.copyWith(
        items: items.whereType<MyReservationItem>().toList(),
        isLoading: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load reservations: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '예약 내역을 불러오지 못했어요.',
      );
    }
  }

  /// 예약을 취소한다.
  ///
  /// 상태만 바꾸지 않고 문서를 지우는 이유: 예약 가능 날짜를 계산할 때
  /// (reservation_card._fetchAllBlockedRanges) 상태를 보지 않고 기간만 보기 때문에,
  /// 문서가 남아 있으면 취소한 기간이 계속 막혀버린다.
  Future<bool> cancelReservation(String reservationId) async {
    if (reservationId.isEmpty) return false;

    try {
      await ref
          .read(firestoreProvider)
          .collection('reservations')
          .doc(reservationId)
          .delete();

      state = state.copyWith(
        items: state.items
            .where((item) => item.reservation.id != reservationId)
            .toList(),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to cancel reservation: $error\n$stackTrace');
      state = state.copyWith(errorMessage: '예약을 취소하지 못했어요.');
      return false;
    }
  }

  Future<Map<String, Storage>> _fetchStorages(
    Set<String> storageIds,
  ) async {
    if (storageIds.isEmpty) return {};

    final firestore = ref.read(firestoreProvider);
    final ids = storageIds.toList();
    const chunkSize = 10;
    final Map<String, Storage> storagesById = {};

    for (var index = 0; index < ids.length; index += chunkSize) {
      final end = min(index + chunkSize, ids.length);
      final chunk = ids.sublist(index, end);

      final snapshot = await firestore
          .collection('storages')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        storagesById[doc.id] = Storage.fromDoc(doc);
      }
    }

    return storagesById;
  }

  Future<int?> _price(Reservation reservation) async {
    final storageId = reservation.storageId;
    final containerIndex = reservation.containerIndex;

    if (storageId.isEmpty || containerIndex.isEmpty) return null;

    try {
      final firestore = ref.read(firestoreProvider);
      final zoneSnapshot = await firestore
          .collection('storages')
          .doc(storageId)
          .collection('zones')
          .doc(containerIndex)
          .get();

      if (!zoneSnapshot.exists) return null;

      final zone = Zone.fromDoc(zoneSnapshot);
      return zone.price;
    } catch (error, stackTrace) {
      debugPrint('Failed to load zone price: $error\n$stackTrace');
      return null;
    }
  }
}
