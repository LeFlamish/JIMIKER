import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/services/auth_providers.dart';

class MyStoragesState {
  final Map<String, Storage> storages;
  final Map<String, List<Reservation>> reservationsByStorage;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;

  const MyStoragesState({
    this.storages = const {},
    this.reservationsByStorage = const {},
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
  });

  MyStoragesState copyWith({
    Map<String, Storage>? storages,
    Map<String, List<Reservation>>? reservationsByStorage,
    bool? isLoading,
    bool? isUpdating,
    String? errorMessage,
  }) {
    return MyStoragesState(
      storages: storages ?? this.storages,
      reservationsByStorage:
      reservationsByStorage ?? this.reservationsByStorage,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: errorMessage,
    );
  }
}

final myStoragesProvider =
NotifierProvider<MyStoragesNotifier, MyStoragesState>(
  MyStoragesNotifier.new,
);

class MyStoragesNotifier extends Notifier<MyStoragesState> {
  @override
  MyStoragesState build() => const MyStoragesState();

  Future<void> loadMyStorages() async {
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
      final storagesSnapshot = await firestore
          .collection('storages')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final storages = <String, Storage>{};
      for (final doc in storagesSnapshot.docs) {
        storages[doc.id] = Storage.fromDoc(doc);
      }

      final reservationsSnapshot = await firestore
          .collection('reservations')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final reservationsByStorage = <String, List<Reservation>>{};
      for (final doc in reservationsSnapshot.docs) {
        final reservation = Reservation.fromDoc(doc);
        reservationsByStorage
            .putIfAbsent(reservation.storageId, () => [])
            .add(reservation);
      }

      for (final entry in reservationsByStorage.entries) {
        entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      state = state.copyWith(
        storages: storages,
        reservationsByStorage: reservationsByStorage,
        isLoading: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load my storages: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '내 창고 목록을 불러오지 못했어요.',
      );
    }
  }

  Future<void> updateStorage({
    required String storageId,
    required String detailAddress,
    required int count,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('storages').doc(storageId).update({
        'detailAddress': detailAddress,
        'count': count,
      });

      final updatedStorage = state.storages[storageId]?.copyWith(
        detailAddress: detailAddress,
        count: count,
      );

      if (updatedStorage != null) {
        final updatedStorages = Map<String, Storage>.from(state.storages);
        updatedStorages[storageId] = updatedStorage;
        state = state.copyWith(storages: updatedStorages, isUpdating: false);
      } else {
        state = state.copyWith(isUpdating: false);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to update storage: $error\n$stackTrace');
      state = state.copyWith(
        isUpdating: false,
        errorMessage: '창고 정보를 수정하지 못했어요.',
      );
    }
  }

  Future<void> updateReservationStatus({
    required Reservation reservation,
    required Status status,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('reservations').doc(reservation.id).update({
        'status': status.name,
      });

      final updatedReservation = reservation.copyWith(status: status);
      final reservations =
      List<Reservation>.from(
        state.reservationsByStorage[reservation.storageId] ?? const [],
      );
      final index = reservations.indexWhere((item) => item.id == reservation.id);
      if (index != -1) {
        reservations[index] = updatedReservation;
      }

      final updatedMap =
      Map<String, List<Reservation>>.from(state.reservationsByStorage);
      updatedMap[reservation.storageId] = reservations;
      state = state.copyWith(
        reservationsByStorage: updatedMap,
        isUpdating: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update reservation: $error\n$stackTrace');
      state = state.copyWith(
        isUpdating: false,
        errorMessage: '예약 상태를 변경하지 못했어요.',
      );
    }
  }
}