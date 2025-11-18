import 'package:flutter/material.dart';
import 'home_banner.dart';

class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 일단은 같은 배너 3개라고 가정 (나중에 데이터 넣어서 다르게 만들 수 있음)
  final int _totalPage = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210, // 배너 높이와 동일
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPage,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              // 지금은 모든 페이지가 같은 HomeBanner
              // 나중에 index에 따라 다른 텍스트/색 넣으면 됨
              return const HomeBanner();
            },
          ),

          // ✅ 여기 인디케이터는 배너 위에 '고정'된 상태로 숫자만 변경
          Positioned(
            bottom: 16,
            right: 20,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentPage + 1} / $_totalPage',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
