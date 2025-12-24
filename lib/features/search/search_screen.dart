import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/search/search_provider.dart';
import 'package:jimiker/features/search/widgets/prediction_list.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final searchRef = ref.watch(searchProvider);
    return Scaffold(
      // 메인 바디 (배경 그라데이션 + 검색창)
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // 1. JIMIKER 스타일 그라데이션 배경
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5C63FF), // 상단: 딥 블루
              Color(0xFF6CE5ED), // 하단: 밝은 민트/시안
            ],
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20), // 앱바와 검색창 사이 간격
                // 2. 검색창 (둥근 스타일)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30), // 캡슐 모양
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: ref
                        .read(searchProvider.notifier)
                        .onChanged,
                    textInputAction:
                        TextInputAction.search, // 키보드 '검색' 버튼 활성화
                    decoration: InputDecoration(
                      hintText: '장소를 입력해주세요.',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                        ),
                      ),
                      border: InputBorder.none, // 기본 테두리 제거
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    onSubmitted: (value) {
                      // TODO: 검색 실행 로직 작성
                      print("검색어: $value");
                    },
                  ),
                ),
                PredictionList(
                  predictions: ref.read(searchProvider).predictions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
