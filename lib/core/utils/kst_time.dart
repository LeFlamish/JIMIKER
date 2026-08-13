import 'package:cloud_firestore/cloud_firestore.dart';

/// 한국 표준시(KST) 오프셋. 서머타임이 없어 고정값으로 충분하다.
const Duration kstOffset = Duration(hours: 9);

/// 어떤 시각이든 한국 기준 벽시계 시간으로 바꾼다.
///
/// 반환된 [DateTime]의 year/month/day/hour... 를 그대로 읽으면 한국 시간이다.
/// (기기 시간대가 무엇이든 결과가 같다.)
DateTime toKst(DateTime dateTime) => dateTime.toUtc().add(kstOffset);

DateTime? kstFromTimestamp(Timestamp? timestamp) =>
    timestamp == null ? null : toKst(timestamp.toDate());

/// 지금 시각(한국 기준)
DateTime nowKst() => toKst(DateTime.now());

/// `오전 9:05` / `오후 11:47` 형태
String formatKstTimeOfDay(Timestamp? timestamp) {
  final kst = kstFromTimestamp(timestamp);
  if (kst == null) return '';
  return _timeOfDayLabel(kst);
}

/// 채팅방 목록 우측에 붙는 "마지막 메시지 시각" 라벨.
///
/// 오늘이면 시각, 어제면 `어제`, 올해면 `M월 d일`, 그 이전이면 `yyyy. M. d.`
String formatKstChatListTime(Timestamp? timestamp) {
  final kst = kstFromTimestamp(timestamp);
  if (kst == null) return '';

  final today = _dateOnly(nowKst());
  final target = _dateOnly(kst);
  final daysAgo = today.difference(target).inDays;

  if (daysAgo == 0) return _timeOfDayLabel(kst);
  if (daysAgo == 1) return '어제';
  if (today.year == target.year) return '${kst.month}월 ${kst.day}일';
  return '${kst.year}. ${kst.month}. ${kst.day}.';
}

String _timeOfDayLabel(DateTime kst) {
  final hour12 = kst.hour % 12 == 0 ? 12 : kst.hour % 12;
  final minute = kst.minute.toString().padLeft(2, '0');
  return '${kst.hour < 12 ? '오전' : '오후'} $hour12:$minute';
}

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);
