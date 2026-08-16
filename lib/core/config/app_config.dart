// 앱 전역 설정값.
//
// 구글 지도(Maps SDK) 키는 android/app/src/main/AndroidManifest.xml 의
// com.google.android.geo.API_KEY 에 있다. (네이티브 SDK가 직접 읽는다.
// 반드시 패키지명 + SHA-1로 사용처를 제한해 둘 것)
//
// 장소 검색(Places)은 서버(Cloud Functions의 searchPlaces/getPlaceDetail)를
// 경유하므로 앱에는 Places 키가 없다. 그 키는 Secret Manager의
// PLACES_API_KEY 에만 있다. — lib/features/search/places_service.dart 참고
