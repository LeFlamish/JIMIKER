import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimiker/data/models/location.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
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
        entry.value.sort((a, b) {
          if (a.status != b.status) {
            if (a.status == Status.waiting) return -1;
            if (b.status == Status.waiting) return 1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
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
    required Storage currentStorage,
    required String address,
    required String detailAddress,
    required LatLng? latLng,
    required DrawProviderData drawState,
    required List<Zone> zones,
    required List<String> existingImageUrls,
    required List<XFile> newImages,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);

    try {
      final firestore = ref.read(firestoreProvider);
      final storageService = ref.read(firebaseStorageProvider);
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final storageRef = firestore
          .collection('storages')
          .doc(storageId);
      final zonesRef = storageRef.collection('zones');
      final locationsRef = firestore.collection('locations');

      final downloadUrls = await Future.wait(
        newImages.asMap().entries.map((entry) async {
          final index = entry.key;
          final image = entry.value;
          final file = File(image.path);
          if (!file.existsSync()) {
            throw Exception('이미지 파일을 찾을 수 없습니다.');
          }

          final timestamp = DateTime.now().microsecondsSinceEpoch;
          final path =
              'storages/$storageId/'
              '${timestamp}_${index}_${image.name}';
          final reference = storageService.ref(path);

          final metadata = SettableMetadata(
            customMetadata: {
              'ownerId': user.uid,
              'storageId': storageId,
            },
          );
          await reference.putFile(file, metadata);
          return reference.getDownloadURL();
        }),
      );

      final updatedAddress = address.trim();
      final updatedLat = latLng?.latitude ?? currentStorage.lat;
      final updatedLng = latLng?.longitude ?? currentStorage.lng;

      final shouldUpdateLocation =
          updatedAddress.isNotEmpty &&
          updatedAddress != currentStorage.address;

      DocumentReference updatedLocationRef = locationsRef.doc(
        currentStorage.locationId,
      );
      DocumentSnapshot? existingLocationSnapshot;

      if (shouldUpdateLocation) {
        final existingLocation = await locationsRef
            .where('address', isEqualTo: updatedAddress)
            .limit(1)
            .get();

        if (existingLocation.docs.isNotEmpty) {
          existingLocationSnapshot = existingLocation.docs.first;
          updatedLocationRef = existingLocationSnapshot.reference;
        } else {
          updatedLocationRef = locationsRef.doc();
        }
      }

      final updatedImages = [...existingImageUrls, ...downloadUrls];

      final batch = firestore.batch();

      if (shouldUpdateLocation &&
          updatedLocationRef.id != currentStorage.locationId) {
        batch.update(locationsRef.doc(currentStorage.locationId), {
          'storages': FieldValue.arrayRemove([storageId]),
        });

        if (existingLocationSnapshot != null) {
          batch.update(updatedLocationRef, {
            'storages': FieldValue.arrayUnion([storageId]),
          });
        } else {
          final location = Location(
            id: updatedLocationRef.id,
            address: updatedAddress,
            lat: updatedLat,
            lng: updatedLng,
            storages: [storageId],
          );
          batch.set(updatedLocationRef, location.toMap());
        }
      }

      batch.update(storageRef, {
        'address': updatedAddress,
        'detailAddress': detailAddress,
        'lat': updatedLat,
        'lng': updatedLng,
        'locationId': updatedLocationRef.id,
        'count': zones.length,
        'widthM': drawState.width,
        'heightM': drawState.height,
        'layout': {
          'lines': drawState.lines
              .map((line) => line.toMap())
              .toList(),
          'doors': drawState.doors
              .map((door) => {'x': door.dx, 'y': door.dy})
              .toList(),
        },
        'images': updatedImages,
      });

      final existingZonesSnapshot = await zonesRef.get();
      for (final doc in existingZonesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final zone in zones) {
        batch.set(zonesRef.doc(zone.index), zone.toMap());
      }

      await batch.commit();

      final updatedStorage = state.storages[storageId]?.copyWith(
        locationId: updatedLocationRef.id,
        address: updatedAddress,
        detailAddress: detailAddress,
        count: zones.length,
        lat: updatedLat,
        lng: updatedLng,
        width: drawState.width,
        height: drawState.height,
        layout: {'lines': drawState.lines, 'doors': drawState.doors},
        images: updatedImages,
      );

      if (updatedStorage != null) {
        final updatedStorages = Map<String, Storage>.from(
          state.storages,
        );
        updatedStorages[storageId] = updatedStorage;
        state = state.copyWith(
          storages: updatedStorages,
          isUpdating: false,
        );
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
      await firestore
          .collection('reservations')
          .doc(reservation.id)
          .update({'status': status.name});

      final updatedReservation = reservation.copyWith(status: status);
      final reservations = List<Reservation>.from(
        state.reservationsByStorage[reservation.storageId] ??
            const [],
      );
      final index = reservations.indexWhere(
        (item) => item.id == reservation.id,
      );
      if (index != -1) {
        reservations[index] = updatedReservation;
      }

      final updatedMap = Map<String, List<Reservation>>.from(
        state.reservationsByStorage,
      );
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
