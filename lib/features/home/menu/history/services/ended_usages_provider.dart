import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/services/auth_providers.dart';

// 구조체는 기존과 동일하게 사용 (Usage 모델 재사용)
class EndedUsageItem {
  final Usage usage;
  final Storage storage;

  const EndedUsageItem({required this.usage, required this.storage});
}

class EndedUsagesState {
  final List<EndedUsageItem> items;
  final bool isLoading;
  final String? errorMessage;

  const EndedUsagesState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EndedUsagesState copyWith({
    List<EndedUsageItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EndedUsagesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final endedUsagesProvider =
    NotifierProvider<EndedUsagesNotifier, EndedUsagesState>(
      EndedUsagesNotifier.new,
    );

class EndedUsagesNotifier extends Notifier<EndedUsagesState> {
  @override
  EndedUsagesState build() => const EndedUsagesState();

  Future<void> loadEndedUsages() async {
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

      // 1. 'endeds' 컬렉션 조회
      final endedsSnapshot = await firestore
          .collection('endeds')
          .where('userId', isEqualTo: user.uid)
          .get();

      final endeds = endedsSnapshot.docs.map(Usage.fromDoc).toList();

      // 2. 정렬: 최근에 종료된 순서대로 (내림차순)
      endeds.sort((a, b) => b.endAt.compareTo(a.endAt));

      final storageIds = endeds
          .map((usage) => usage.storageId)
          .toSet();
      final storagesById = await _fetchStorages(storageIds);

      final items = endeds
          .map((usage) {
            final storage = storagesById[usage.storageId];
            if (storage == null) {
              return null;
            }
            return EndedUsageItem(usage: usage, storage: storage);
          })
          .whereType<EndedUsageItem>()
          .toList();

      state = state.copyWith(items: items, isLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to load ended usages: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '이용 내역을 불러오지 못했어요.',
      );
    }
  }

  // 기존 로직과 동일 (보관함 정보 가져오기)
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
