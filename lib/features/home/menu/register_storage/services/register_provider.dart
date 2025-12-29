import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../../data/models/location.dart';
import '../../../../../data/models/storage.dart';
import '../../../../../data/models/zone.dart';
import '../../../../../services/auth_providers.dart';
import '../../../../search/search_screen.dart';
import '../../../../draw/draw_provider.dart';

class RegisterData {
  final String? address;
  final String? detailAddress;
  final LatLng? latLng;
  final List<XFile> images;
  final List<String> existingImageUrls;
  final bool isSubmitting;

  RegisterData({
    this.address,
    this.detailAddress,
    this.latLng,
    this.images = const [],
    this.existingImageUrls = const [],
    this.isSubmitting = false,
  });

  RegisterData copyWith({
    String? address,
    String? detailAddress,
    LatLng? latLng,
    List<XFile>? images,
    List<String>? existingImageUrls,
    bool? isSubmitting,
  }) {
    return RegisterData(
      address: address ?? this.address,
      detailAddress: detailAddress ?? this.detailAddress,
      latLng: latLng ?? this.latLng,
      images: images ?? this.images,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final registerProvider =
    NotifierProvider<RegisterNotifier, RegisterData>(
      () => RegisterNotifier(),
    );

class RegisterNotifier extends Notifier<RegisterData> {
  @override
  RegisterData build() {
    return RegisterData();
  }

  void reset() {
    state = RegisterData();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final newImages = await picker.pickMultiImage();
    if (newImages.isNotEmpty) {
      final remainingSlots = 10 - state.existingImageUrls.length;
      if (remainingSlots <= 0) {
        return;
      }

      final mergedImages = [...state.images, ...newImages];
      state = state.copyWith(
        images: mergedImages.take(remainingSlots).toList(),
      );
    }
  }

  // [수정 후] 작동 함 (새로운 리스트를 할당)
  void deletePhoto(int index) {
    // 1. 현재 state를 복사하여 새로운 리스트 생성
    final newState = List<XFile>.from(state.images);

    // 2. 복사된 리스트에서 삭제
    newState.removeAt(index);

    // 3. 새로운 리스트를 state에 할당 (이때 UI가 갱신됨)
    state = state.copyWith(images: newState);
  }

  void setInitialData({
    required String address,
    required String detailAddress,
    required LatLng latLng,
    required List<String> existingImageUrls,
  }) {
    state = state.copyWith(
      address: address,
      detailAddress: detailAddress,
      latLng: latLng,
      existingImageUrls: existingImageUrls,
    );
  }

  void removeExistingImage(int index) {
    final updatedImages = List<String>.from(state.existingImageUrls);
    if (index < 0 || index >= updatedImages.length) return;
    updatedImages.removeAt(index);
    state = state.copyWith(existingImageUrls: updatedImages);
  }

  void addressTap(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

    if (result != null && context.mounted) {
      state = state.copyWith(
        address: result["address"],
        detailAddress: result["detailAddress"],
        latLng: result["latLng"],
      );
    }

    controller.text = state.address ?? "";
  }

  void updateDetailAddress(String detailAddress) {
    state = state.copyWith(detailAddress: detailAddress);
  }

  Future<void> registerStorage({
    required DrawProviderData drawState,
    required List<Zone> zones,
    required String detailAddress,
  }) async {
    final firestore = ref.read(firestoreProvider);
    final storage = ref.read(firebaseStorageProvider);
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final address = state.address ?? '';
    final latLng = state.latLng;
    final storageRef = firestore.collection('storages').doc();
    final locationsRef = firestore.collection('locations');

    state = state.copyWith(isSubmitting: true);

    late final DocumentReference locationRef;

    try {
      final downloadUrls = await Future.wait(
        state.images.asMap().entries.map((entry) async {
          final index = entry.key;
          final image = entry.value;
          final file = File(image.path);
          if (!file.existsSync()) {
            throw Exception('이미지 파일을 찾을 수 없습니다.');
          }

          final timestamp = DateTime.now().microsecondsSinceEpoch;
          final path =
              'storages/${storageRef.id}/'
              '${timestamp}_${index}_${image.name}';
          final reference = storage.ref(path);

          final metadata = SettableMetadata(
            customMetadata: {
              'ownerId': user.uid,
              'storageId': storageRef.id,
            },
          );
          await reference.putFile(file, metadata);
          return reference.getDownloadURL();
        }),
      );

      final existingLocation = await locationsRef
          .where('address', isEqualTo: address)
          .limit(1)
          .get();
      late final DocumentReference locationRef;

      if (existingLocation.docs.isNotEmpty) {
        locationRef = existingLocation.docs.first.reference;
      } else {
        locationRef = locationsRef.doc();
      }

      final storageData = Storage(
        locationId: locationRef.id,
        lat: latLng?.latitude ?? 0,
        lng: latLng?.longitude ?? 0,
        address: address,
        detailAddress: detailAddress,
        count: zones.length,
        createdAt: DateTime.now(),
        images: downloadUrls,
        ownerId: user.uid,
        width: drawState.width,
        height: drawState.height,
        layout: {'lines': drawState.lines, 'doors': drawState.doors},
        approved: false, // 나중에 승인 받는다면 false로 수정
      );
      final batch = firestore.batch();
      batch.set(storageRef, storageData.toMap());

      if (existingLocation.docs.isNotEmpty) {
        batch.update(locationRef, {
          'storages': FieldValue.arrayUnion([storageRef.id]),
        });
      } else {
        final location = Location(
          id: locationRef.id,
          address: address,
          lat: latLng?.latitude ?? 0,
          lng: latLng?.longitude ?? 0,
          storages: [storageRef.id],
        );
        batch.set(locationRef, location.toMap());
      }

      for (final zone in zones) {
        final zoneRef = storageRef
            .collection('zones')
            .doc(zone.index);
        batch.set(zoneRef, zone.toMap());
      }
      await batch.commit();
    } catch (error) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
    state = state.copyWith(isSubmitting: false);
  }
}
