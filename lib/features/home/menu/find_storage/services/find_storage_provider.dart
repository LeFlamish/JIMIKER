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
      final snapshot = await firestore.collection('storages').get();

      final storages = <String, Storage>{};
      for (final doc in snapshot.docs) {
        final storage = Storage.fromDoc(doc);
        if (storage.approved) storages[doc.id] = storage;
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
