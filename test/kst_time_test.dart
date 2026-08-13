import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/core/utils/kst_time.dart';

/// 한국 기준 벽시계 시각([kstWallClock])에 해당하는 실제 순간을 만든다.
Timestamp _atKst(DateTime kstWallClock) {
  final utc = DateTime.utc(
    kstWallClock.year,
    kstWallClock.month,
    kstWallClock.day,
    kstWallClock.hour,
    kstWallClock.minute,
  );
  return Timestamp.fromDate(utc.subtract(kstOffset));
}

void main() {
  group('toKst', () {
    test('기기 시간대와 상관없이 UTC+9로 변환한다', () {
      final utcNoon = DateTime.utc(2026, 8, 13, 3, 30);
      final kst = toKst(utcNoon);

      expect(kst.hour, 12);
      expect(kst.minute, 30);
      expect(kst.day, 13);
    });

    test('UTC 오후 늦은 시각은 한국 기준 다음 날이 된다', () {
      final kst = toKst(DateTime.utc(2026, 8, 13, 20, 0));

      expect(kst.day, 14);
      expect(kst.hour, 5);
    });
  });

  group('formatKstTimeOfDay', () {
    test('오전/오후를 한국 기준으로 붙인다', () {
      expect(
        formatKstTimeOfDay(_atKst(DateTime(2026, 8, 13, 9, 5))),
        '오전 9:05',
      );
      expect(
        formatKstTimeOfDay(_atKst(DateTime(2026, 8, 13, 15, 7))),
        '오후 3:07',
      );
    });

    test('자정과 정오는 12시로 표기한다', () {
      expect(
        formatKstTimeOfDay(_atKst(DateTime(2026, 8, 13, 0, 0))),
        '오전 12:00',
      );
      expect(
        formatKstTimeOfDay(_atKst(DateTime(2026, 8, 13, 12, 0))),
        '오후 12:00',
      );
    });

    test('값이 없으면 빈 문자열', () {
      expect(formatKstTimeOfDay(null), '');
    });
  });

  group('formatKstChatListTime', () {
    test('오늘 온 메시지는 시각으로 보여준다', () {
      final today = nowKst();
      final label = formatKstChatListTime(
        _atKst(DateTime(today.year, today.month, today.day, 9, 5)),
      );

      expect(label, '오전 9:05');
    });

    test('어제 온 메시지는 "어제"로 보여준다', () {
      final yesterday = nowKst().subtract(const Duration(days: 1));
      final label = formatKstChatListTime(
        _atKst(
          DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            9,
            5,
          ),
        ),
      );

      expect(label, '어제');
    });

    test('올해 지난 메시지는 "M월 d일"로 보여준다', () {
      final target = nowKst().subtract(const Duration(days: 5));
      final label = formatKstChatListTime(
        _atKst(
          DateTime(target.year, target.month, target.day, 9, 5),
        ),
      );

      // 5일 전이 작년으로 넘어가는 연초에는 연도 표기가 나오므로 그 경우는 건너뛴다.
      if (target.year == nowKst().year) {
        expect(label, '${target.month}월 ${target.day}일');
      }
    });

    test('작년 메시지는 연도까지 보여준다', () {
      final lastYear = nowKst().year - 1;
      final label = formatKstChatListTime(
        _atKst(DateTime(lastYear, 3, 9, 9, 5)),
      );

      expect(label, '$lastYear. 3. 9.');
    });

    test('값이 없으면 빈 문자열', () {
      expect(formatKstChatListTime(null), '');
    });
  });
}
