// 앱 전역 설정값.

/// 지도와 장소 검색에 쓰는 구글 API 키.
///
/// 안드로이드 Maps SDK는 키를 APK 안에 넣을 수밖에 없어 숨길 수 없다.
/// 대신 Google Cloud Console에서 "패키지명 + SHA-1"으로 사용처를 제한해야
/// 남이 가져다 쓰지 못한다. 제한을 걸지 않으면 요금이 그대로 청구된다.
///
/// 키를 바꿀 때 고쳐야 할 곳:
///   - 여기(또는 빌드 옵션)
///   - android/app/src/main/AndroidManifest.xml 의 com.google.android.geo.API_KEY
///
/// 빌드할 때 다른 키를 쓰고 싶으면:
///   flutter build appbundle --dart-define=GOOGLE_MAPS_API_KEY=...
const String googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'AIzaSyAuhd1aQTSgjtgnydP3_wgD3SDD2QD-VGU',
);
