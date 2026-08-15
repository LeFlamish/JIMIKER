/// 공간 크기·금액 표기를 한 곳에서 담당한다.
///
/// 화면마다 제각각 포맷하면 "6.0㎡"와 "6㎡"가 섞이고,
/// 평 환산 계수 같은 값이 여러 곳에 복사된다.
library;

/// 1평 = 3.3058㎡ (부동산 표준 환산)
const double _sqmPerPyeong = 3.3058;

/// 2.0 → "2", 2.5 → "2.5"  (소수점이 없으면 정수로)
String formatMeters(double meters) {
  if (meters == meters.roundToDouble()) {
    return meters.round().toString();
  }
  return meters.toStringAsFixed(1);
}

/// "2×3m" — 구역 상자나 목록에 붙는 짧은 크기 표기
String formatZoneSize(double widthM, double heightM) {
  return '${formatMeters(widthM)}×${formatMeters(heightM)}m';
}

/// "6.0㎡ (약 1.8평)"
String formatArea(double areaSqm) {
  final pyeong = areaSqm / _sqmPerPyeong;
  return '${areaSqm.toStringAsFixed(1)}㎡ (약 ${pyeong.toStringAsFixed(1)}평)';
}

/// 이 넓이에 뭐가 들어가는지 감을 잡게 하는 한 줄.
///
/// 정밀한 계산이 아니라 눈높이 비유다. 기준이 바뀌면 여기만 고친다.
String areaHint(double areaSqm) {
  if (areaSqm < 1) return '캐리어 3~4개 정도 들어가는 크기예요.';
  if (areaSqm < 2) return '이삿짐 박스 10개 안팎이 들어가는 크기예요.';
  if (areaSqm < 3.3) return '1인 가구 계절짐 보관에 알맞은 크기예요.';
  if (areaSqm < 6.6) return '원룸 이삿짐이 들어가는 크기예요. (약 1평대)';
  if (areaSqm < 13.2) return '투룸 살림이 들어가는 크기예요. (약 2~4평)';
  return '가정용 살림 전체를 보관할 수 있는 크기예요.';
}

/// 1234000 → "1,234,000원"
String formatWon(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer원';
}

/// 크기가 제각각인 구역들 사이의 비교 기준.
/// "㎡당 8,333원" — 면적이 0이면 빈 문자열.
String formatPricePerSqm(int monthlyPrice, double areaSqm) {
  if (areaSqm <= 0) return '';
  return '㎡당 ${formatWon((monthlyPrice / areaSqm).round())}';
}
