import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/storage.dart';
import '../../../../../services/auth_providers.dart';

class FindStorageState {
  final Map<String, Storage> storages;
  final Storage? selectedStorage;
  final bool isLoading;
  final String? error;

  const FindStorageState({
    this.storages = const {},
    this.selectedStorage,
    this.isLoading = false,
    this.error,
  });

  FindStorageState copyWith({
    Map<String, Storage>? storages,
    Storage? selectedStorage,
    bool? isLoading,
    String? error,
  }) {
    return FindStorageState(
      storages: storages ?? this.storages,
      selectedStorage: selectedStorage ?? this.selectedStorage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final findStorageProvider =
    NotifierProvider<FindStorageNotifier, FindStorageState>(
      () => FindStorageNotifier(),
    );

class FindStorageNotifier extends Notifier<FindStorageState> {
  @override
  FindStorageState build() {
    return const FindStorageState();
  }

  Future<void> loadStorages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final firestore = ref.read(firestoreProvider);
      // 승인된 것만 받아온다. 전부 받아서 앱에서 거르면 심사 대기·반려된
      // 창고까지 읽게 되는데, Firestore는 읽은 문서 수로 과금한다.
      // (내린 창고는 문서 수가 적어 앱에서 거르는 편이 색인 추가보다 싸다)
      final snapshot = await firestore
          .collection('storages')
          .where('approved', isEqualTo: true)
          .get();

      final storages = <String, Storage>{};
      for (final doc in snapshot.docs) {
        final storage = Storage.fromDoc(doc);
        // 주인이 내린 창고(deleted)는 지도에 띄우지 않는다.
        if (!storage.deleted) {
          storages[doc.id] = storage;
        }
      }

      state = state.copyWith(storages: storages, isLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to load storages: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void selectStorage(String storageId) {
    state = state.copyWith(
      selectedStorage: state.storages[storageId],
    );
  }
}
