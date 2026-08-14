import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/features/auth/terms/terms_agreement_screen.dart';
import 'package:jimiker/features/auth/terms/terms_document_screen.dart';
import 'package:jimiker/features/auth/terms/terms_documents.dart';

/// 동의 화면이 pop으로 돌려준 값을 담아두는 상자.
///
/// 화면이 닫힌 뒤에야 값이 채워지므로, 테스트가 직접 들고 있어야 한다.
class _Result {
  TermsAgreement? agreement;
  bool closed = false;
}

/// 동의 화면을 띄운다. 닫히면 결과가 [_Result]에 담긴다.
Future<_Result> _openAgreement(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final result = _Result();

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.agreement = await Navigator.of(context)
                    .push<TermsAgreement>(
                      MaterialPageRoute(
                        builder: (_) => const TermsAgreementScreen(),
                      ),
                    );
                result.closed = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();

  return result;
}

/// '동의하고 시작하기' 버튼이 눌리는 상태인지.
bool _canSubmit(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, '동의하고 시작하기'),
  );
  return button.onPressed != null;
}

/// 항목 제목을 눌러 체크를 토글한다.
///
/// '서비스 이용약관'은 '위치기반서비스 이용약관'의 일부라서 부분 일치로 찾으면
/// 두 개가 걸린다. 화면에 그려지는 문구 그대로 찾는다.
Future<void> _check(WidgetTester tester, LegalDocument document) async {
  final label =
      '${document.required ? '[필수] ' : '[선택] '}${document.title}';

  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('약관 문서', () {
    test('필수와 선택이 나뉘어 있다', () {
      expect(requiredDocuments.length, 3);
      expect(
        requiredDocuments.map((doc) => doc.id),
        containsAll(['service', 'privacy', 'location']),
      );

      // 마케팅 수신을 필수로 만들면 법 위반이다.
      final marketing = legalDocuments.firstWhere(
        (doc) => doc.id == 'marketing',
      );
      expect(marketing.required, isFalse);
    });

    test('본문이 빈 문서가 없다', () {
      for (final document in legalDocuments) {
        expect(
          document.body.trim(),
          isNotEmpty,
          reason: '${document.title} 본문이 비었다',
        );
      }
    });

    test('약관 버전은 1 이상이다', () {
      // 사용자 문서에 저장돼서 "동의 기록 없음(0)"과 구분된다.
      expect(termsVersion, greaterThan(0));
    });
  });

  group('TermsAgreementScreen', () {
    testWidgets('필수에 동의하기 전에는 시작할 수 없다', (tester) async {
      await _openAgreement(tester);

      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('선택 항목만 체크해도 시작할 수 없다', (tester) async {
      await _openAgreement(tester);

      await _check(
        tester,
        legalDocuments.firstWhere((doc) => doc.id == 'marketing'),
      );

      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('필수를 하나라도 빼면 시작할 수 없다', (tester) async {
      await _openAgreement(tester);

      for (final document in requiredDocuments.skip(1)) {
        await _check(tester, document);
      }

      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('필수만 동의하면 마케팅은 꺼진 채로 넘어온다', (tester) async {
      final result = await _openAgreement(tester);

      for (final document in requiredDocuments) {
        await _check(tester, document);
      }
      expect(_canSubmit(tester), isTrue);

      await tester.tap(find.text('동의하고 시작하기'));
      await tester.pumpAndSettle();

      expect(result.agreement, isNotNull);
      expect(result.agreement!.marketing, isFalse);
    });

    testWidgets('전체 동의를 누르면 마케팅까지 켜진 채로 넘어온다', (tester) async {
      final result = await _openAgreement(tester);

      await tester.tap(find.text('전체 동의'));
      await tester.pumpAndSettle();
      expect(_canSubmit(tester), isTrue);

      await tester.tap(find.text('동의하고 시작하기'));
      await tester.pumpAndSettle();

      expect(result.agreement, isNotNull);
      expect(result.agreement!.marketing, isTrue);
    });

    testWidgets('전체 동의를 두 번 누르면 다시 다 풀린다', (tester) async {
      await _openAgreement(tester);

      await tester.tap(find.text('전체 동의'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 동의'));
      await tester.pumpAndSettle();

      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('그냥 나가면 동의하지 않은 것으로 돌아간다', (tester) async {
      final result = await _openAgreement(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(result.closed, isTrue);
      // null이면 auth 쪽이 계정을 만들지 않고 로그아웃시킨다.
      expect(result.agreement, isNull);
    });

    testWidgets('각 항목의 전문을 볼 수 있다', (tester) async {
      await _openAgreement(tester);

      await tester.tap(find.text('보기').first);
      await tester.pumpAndSettle();

      expect(find.byType(TermsDocumentScreen), findsOneWidget);
      expect(
        find.textContaining(
          legalDocuments.first.body.trim().split('\n').first,
        ),
        findsOneWidget,
      );
    });
  });

  group('TermsListScreen', () {
    testWidgets('약관을 모두 보여준다', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: TermsListScreen()),
      );
      await tester.pumpAndSettle();

      for (final document in legalDocuments) {
        expect(
          find.text(document.title),
          findsOneWidget,
          reason: '${document.title}이 목록에 없다',
        );
      }
    });

    testWidgets('개인정보 처리방침에 수집 항목과 탈퇴 안내가 들어 있다', (
      tester,
    ) async {
      // 플레이스토어가 요구하는 최소 내용이 빠지지 않았는지 본다.
      final privacy = legalDocuments.firstWhere(
        (doc) => doc.id == 'privacy',
      );

      expect(privacy.body, contains('위치'));
      expect(privacy.body, contains('회원 탈퇴'));
      expect(privacy.body, contains('보관 기간'));
      expect(privacy.body, contains('제3자'));
    });
  });
}
