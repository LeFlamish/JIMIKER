import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../data/model/storage.dart';
import '../../../../search/search_screen.dart';

class RegisterData {
  final String? address;
  final String? detailAddress;
  final LatLng? latLng;
  final List<XFile> images;

  RegisterData({
    this.address,
    this.detailAddress,
    this.latLng,
    this.images = const [],
  });

  RegisterData copyWith({
    String? address,
    String? detailAddress,
    LatLng? latLng,
    List<XFile>? images,
  }) {
    return RegisterData(
      address: address ?? this.address,
      detailAddress: detailAddress ?? this.detailAddress,
      latLng: latLng ?? this.latLng,
      images: images ?? this.images,
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

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final newImages = await picker.pickMultiImage();
    if (newImages.isNotEmpty) {
      state = state.copyWith(
        images: (state.images + newImages).take(10).toList(),
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
}
