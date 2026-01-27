import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/services/auth_providers.dart';

class MyUsageItem {
  final Usage usage;
  final Storage storage;

  const MyUsageItem({required this.usage, required this.storage});
}

class MyUsagesState {
  final List<MyUsageItem> items;
  final bool isLoading;
  final String? errorMessage;

  const MyUsagesState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MyUsagesState copyWith({
    List<MyUsageItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MyUsagesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final myUsagesProvider =
    NotifierProvider<MyUsagesNotifier, MyUsagesState>(
      MyUsagesNotifier.new,
    );

class MyUsagesNotifier extends Notifier<MyUsagesState> {
  @override
  MyUsagesState build() => const MyUsagesState();

  Future<void> loadMyUsages() async {
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
      final usagesSnapshot = await firestore
          .collection('usages')
          .where('userId', isEqualTo: user.uid)
          .get();

      final usages = usagesSnapshot.docs.map(Usage.fromDoc).toList();
      usages.sort((a, b) => a.endAt.compareTo(b.endAt));

      final storageIds = usages
          .map((usage) => usage.storageId)
          .toSet();
      final storagesById = await _fetchStorages(storageIds);

      final items = usages
          .map((usage) {
            final storage = storagesById[usage.storageId];
            if (storage == null) {
              debugPrint('Missing storage for usage ${usage.id}');
              return null;
            }
            return MyUsageItem(usage: usage, storage: storage);
          })
          .whereType<MyUsageItem>()
          .toList();

      state = state.copyWith(items: items, isLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to load usages: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '이용 중인 보관함을 불러오지 못했어요.',
      );
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
}
