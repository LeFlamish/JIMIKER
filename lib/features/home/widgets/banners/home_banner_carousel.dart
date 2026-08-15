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

  // 서비스가 하는 일을 첫 화면에서 바로 알 수 있게 세 장으로 나눈다.
  static const List<HomeBanner> _banners = [
    HomeBanner(
      badge: '공간이 필요할 때',
      title: '가까운 창고를 지도에서 찾아요',
      subtitle: '내 주변 보관 공간을 골라\n월 단위로 예약하고 이용해요.',
    ),
    HomeBanner(
      badge: '남는 공간이 있다면',
      title: '창고를 등록해 수익을 만들어요',
      subtitle: '도면을 그리고 구역별 가격을 정하면\n운영자 확인 후 지도에 올라가요.',
    ),
    HomeBanner(
      badge: '안심 거래',
      title: '예약부터 종료까지 기록이 남아요',
      subtitle: '확정된 금액은 바뀌지 않고,\n궁금한 건 1:1 채팅으로 물어봐요.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) => _banners[index],
          ),

          Positioned(
            bottom: 16,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentPage + 1} / ${_banners.length}',
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
