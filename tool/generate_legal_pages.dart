// 앱 안의 약관 원문(lib/features/auth/terms/terms_documents.dart)에서
// 공개용 HTML을 만든다.
//
//   dart run tool/generate_legal_pages.dart
//
// 플레이스토어는 개인정보처리방침과 계정 삭제 안내를 "공개 URL"로 요구한다.
// 앱과 웹의 내용이 어긋나면 안 되므로 손으로 옮겨 적지 않고 여기서 뽑는다.
// 약관을 고쳤으면 이 명령을 다시 돌리고 docs/를 커밋하면 된다.

import 'dart:io';

import 'package:jimiker/features/auth/terms/terms_documents.dart';

/// 문의를 받을 주소. 플레이스토어 등록 전에 실제 주소로 바꿔야 한다.
/// 개인정보 보호책임자 연락처이자 계정 삭제 요청을 받는 곳이다.
const String contactEmail = 'TODO-이메일을-적어주세요@example.com';

/// 약관 시행일.
const String effectiveDate = '2026년 8월 14일';

const String appName = '지미커';

const String outputDir = 'docs';

void main() {
  final directory = Directory(outputDir);
  if (!directory.existsSync()) directory.createSync(recursive: true);

  for (final document in legalDocuments) {
    _write('${document.id}.html', _documentPage(document));
  }

  _write('account-deletion.html', _accountDeletionPage());
  _write('index.html', _indexPage());

  stdout.writeln('$outputDir/ 에 ${legalDocuments.length + 2}개 파일을 만들었습니다.');

  if (contactEmail.startsWith('TODO')) {
    stdout.writeln(
      '\n⚠️  contactEmail이 아직 자리표시자입니다. '
      'tool/generate_legal_pages.dart 위쪽을 고치고 다시 실행해주세요.',
    );
  }
}

void _write(String name, String contents) {
  File('$outputDir/$name').writeAsStringSync(contents);
}

/// HTML에서 뜻이 달라지는 문자만 바꾼다.
String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// 모든 페이지가 쓰는 껍데기.
///
/// 바깥에서 파일을 하나도 받아오지 않는다. 글꼴이나 CSS를 외부에서 끌어오면
/// 그 서버가 죽었을 때 약관이 안 보이고, 심사에서 문제가 된다.
String _shell({
  required String title,
  required String body,
  bool isHome = false,
}) {
  return '''
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title | $appName</title>
<style>
  :root {
    --bg: #f5f6fa;
    --card: #ffffff;
    --text: #222222;
    --muted: #666666;
    --line: #e6e7ee;
    --accent: #6b7af5;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #16171c;
      --card: #1e1f26;
      --text: #e8e8ea;
      --muted: #a0a0a8;
      --line: #2e2f38;
      --accent: #8c98ff;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px 16px 64px;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI",
      "Apple SD Gothic Neo", "Malgun Gothic", sans-serif;
    line-height: 1.7;
    -webkit-text-size-adjust: 100%;
  }
  .wrap { max-width: 760px; margin: 0 auto; }
  header { margin-bottom: 22px; }
  .brand {
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    letter-spacing: 0.06em;
    text-decoration: none;
  }
  h1 { font-size: 25px; margin: 10px 0 6px; line-height: 1.35; }
  .meta { font-size: 13px; color: var(--muted); margin: 0; }
  .card {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 16px;
    padding: 24px 22px;
  }
  .doc {
    white-space: pre-wrap;
    word-break: break-word;
    font-size: 14.5px;
    margin: 0;
    font-family: inherit;
  }
  h2 { font-size: 17px; margin: 26px 0 8px; }
  h2:first-child { margin-top: 0; }
  p { margin: 0 0 12px; font-size: 14.5px; }
  ul { margin: 0 0 12px; padding-left: 20px; font-size: 14.5px; }
  li { margin-bottom: 6px; }
  a { color: var(--accent); }
  .list { list-style: none; padding: 0; margin: 0; }
  .list li { margin: 0 0 10px; }
  .list a {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 16px 18px;
    text-decoration: none;
    color: var(--text);
    font-weight: 600;
    font-size: 15px;
  }
  .list .tag {
    font-size: 12px;
    font-weight: 700;
    color: var(--muted);
  }
  .callout {
    background: var(--bg);
    border: 1px solid var(--line);
    border-radius: 12px;
    padding: 14px 16px;
    font-size: 14px;
    margin: 0 0 16px;
  }
  footer {
    margin-top: 34px;
    font-size: 12.5px;
    color: var(--muted);
    text-align: center;
  }
</style>
</head>
<body>
<div class="wrap">
  <header>
    ${isHome ? '<span class="brand">$appName</span>' : '<a class="brand" href="./">$appName</a>'}
    <h1>$title</h1>
    <p class="meta">시행일: $effectiveDate</p>
  </header>
$body
  <footer>$appName · 문의 <a href="mailto:$contactEmail">$contactEmail</a></footer>
</div>
</body>
</html>
''';
}

String _documentPage(LegalDocument document) {
  return _shell(
    title: document.title,
    body: '  <div class="card"><div class="doc">'
        '${_escape(document.body.trim())}'
        '</div></div>',
  );
}

String _indexPage() {
  final items = StringBuffer();

  for (final document in legalDocuments) {
    items.writeln(
      '      <li><a href="${document.id}.html">'
      '<span>${document.title}</span>'
      '<span class="tag">${document.required ? '필수' : '선택'}</span>'
      '</a></li>',
    );
  }
  items.writeln(
    '      <li><a href="account-deletion.html">'
    '<span>계정 삭제 요청</span><span class="tag">안내</span></a></li>',
  );

  return _shell(
    isHome: true,
    title: '약관 및 정책',
    body:
        '''
  <p class="callout">
    $appName는 보관 공간을 빌려주려는 사람과 빌리려는 사람을 연결하는
    중개 서비스입니다. 아래 문서는 앱 안에서도 같은 내용으로 볼 수 있습니다.
  </p>
  <ul class="list">
${items.toString().trimRight()}
  </ul>''',
  );
}

/// 플레이스토어가 요구하는 계정 삭제 안내.
///
/// 앱을 설치하지 않은 상태에서도 삭제를 요청할 수 있어야 하고,
/// 무엇이 지워지고 무엇이 남는지 밝혀야 한다.
String _accountDeletionPage() {
  return _shell(
    title: '계정 삭제 요청',
    body:
        '''
  <div class="card">
    <p class="callout">
      앱 이름: <b>$appName</b><br>
      계정을 삭제하면 되돌릴 수 없습니다.
    </p>

    <h2>앱에서 직접 삭제하기</h2>
    <p>가장 빠른 방법입니다. 요청을 기다릴 필요 없이 바로 처리됩니다.</p>
    <ul>
      <li>$appName 앱 실행 → <b>내 정보</b></li>
      <li><b>회원 탈퇴</b> 선택 후 안내에 따라 확인</li>
    </ul>

    <h2>앱 없이 요청하기</h2>
    <p>
      앱을 이미 지우셨거나 접속이 어려우시면
      <a href="mailto:$contactEmail">$contactEmail</a> 로 메일을 보내주세요.
      가입에 사용하신 <b>구글 계정 이메일</b>을 함께 적어주시면
      본인 확인 후 처리해 드립니다. 접수 후 영업일 기준 7일 이내에
      처리하고 회신드립니다.
    </p>

    <h2>삭제되는 정보</h2>
    <ul>
      <li>로그인 계정 (구글 연동 정보)</li>
      <li>이메일 주소, 프로필 사진</li>
      <li>알림 발송용 기기 토큰</li>
      <li>등록하신 창고 중 거래 기록이 없는 것 — 사진 파일까지 함께 삭제</li>
    </ul>

    <h2>바로 삭제되지 않고 남는 정보</h2>
    <p>
      예약과 이용 기록은 <b>거래 상대방의 기록이기도 합니다.</b>
      한쪽이 지운다고 상대방의 내역까지 사라지면 상대방이 자기 거래를
      확인할 수 없게 되므로, 다음과 같이 처리합니다.
    </p>
    <ul>
      <li>
        예약 · 이용 · 종료된 이용 기록은 상대방의 화면에 남습니다.
        이때 표시되는 이름은 <b>"탈퇴한 사용자"</b>로 바뀌고,
        이메일과 프로필 사진은 지워집니다.
      </li>
      <li>
        주고받은 대화는 상대방의 채팅 목록에 남습니다.
      </li>
      <li>
        거래 기록이 있는 창고는 문서가 남되 지도와 목록에서 사라집니다.
      </li>
      <li>
        전자상거래법 등 법령이 별도 보관을 요구하는 기록은
        해당 기간 동안 보관한 뒤 파기합니다.
      </li>
    </ul>

    <h2>더 알아보기</h2>
    <p>
      수집 항목과 보관 기간은
      <a href="privacy.html">개인정보 처리방침</a>에 자세히 적혀 있습니다.
    </p>
  </div>''',
  );
}
