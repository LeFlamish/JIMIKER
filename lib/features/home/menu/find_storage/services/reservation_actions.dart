import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 예약 생성은 Cloud Functions를 거친다.
///
/// 기간이 겹치는지는 보안 규칙으로 막을 수 없다. 규칙은 다른 문서를 범위로
/// 훑어볼 수 없어서, 이미 잡힌 예약과 겹치는지 확인할 방법이 없다.
/// 앱에서만 확인하면 두 사람이 같은 순간에 누를 때 둘 다 성공한다.
/// 계약 금액을 그 시점 값으로 박아두는 일도 서버가 한다.
final reservationActionsProvider = Provider<ReservationActions>((ref) {
  return ReservationActions(
    FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
  );
});

/// 서버가 만들어준 예약
class CreatedReservation {
  const CreatedReservation({
    required this.reservationId,
    required this.monthlyPrice,
    required this.months,
    required this.totalPrice,
  });

  final String reservationId;
  final int monthlyPrice;
  final int months;
  final int totalPrice;
}

class ReservationActions {
  const ReservationActions(this._functions);

  final FirebaseFunctions _functions;

  Future<CreatedReservation> createReservation({
    required String storageId,
    required String containerIndex,
    required DateTime startAt,
    required int months,
  }) async {
    final result = await _functions
        .httpsCallable('createReservation')
        .call({
          'storageId': storageId,
          'containerIndex': containerIndex,
          // 날짜만 쓴다. 서버가 시각을 잘라내고 개월 수를 더해 종료일을 만든다.
          'startAtMs': DateTime(
            startAt.year,
            startAt.month,
            startAt.day,
          ).toUtc().millisecondsSinceEpoch,
          'months': months,
        });

    final data = result.data;
    int read(String key) =>
        data is Map ? (data[key] as num?)?.toInt() ?? 0 : 0;

    return CreatedReservation(
      reservationId: data is Map
          ? data['reservationId']?.toString() ?? ''
          : '',
      monthlyPrice: read('monthlyPrice'),
      months: read('months'),
      totalPrice: read('totalPrice'),
    );
  }
}

/// 예약이 실패했을 때 사용자에게 보여줄 문구.
String readableReservationError(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim() ?? '';

    // 함수가 배포되지 않았으면 Firebase가 영문 NOT_FOUND를 그대로 돌려준다.
    // 서버가 던지는 not-found에는 한글 안내가 붙어 있어 구분된다.
    if (error.code == 'not-found' &&
        (message.isEmpty || message.toUpperCase() == 'NOT_FOUND')) {
      return '예약 기능이 서버에 아직 배포되지 않았어요.\n'
          'firebase deploy --only functions 를 실행해주세요.';
    }

    if (message.isNotEmpty) return message;

    return switch (error.code) {
      'unauthenticated' => '로그인 후 이용해주세요.',
      'already-exists' => '그 기간에는 이미 예약이 있어요.',
      'unavailable' => '연결이 불안정해요. 잠시 후 다시 시도해주세요.',
      _ => '예약하지 못했어요. 잠시 후 다시 시도해주세요.',
    };
  }
  return '예약하지 못했어요. 잠시 후 다시 시도해주세요.';
}
