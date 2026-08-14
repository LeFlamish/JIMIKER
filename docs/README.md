# docs/ — 공개용 약관 페이지

플레이스토어는 개인정보처리방침과 계정 삭제 안내를 **누구나 볼 수 있는 URL**로
요구한다. 이 폴더가 그 페이지들이다.

## 고칠 때

**이 폴더의 .html을 직접 고치지 말 것.** 다시 생성하면 덮어써진다.

원문은 앱과 같은 파일 하나를 쓴다.

```
lib/features/auth/terms/terms_documents.dart   ← 여기가 원본
```

고친 뒤 다시 뽑는다.

```bash
dart run tool/generate_legal_pages.dart
```

앱 화면과 웹 페이지가 같은 글을 쓰게 하려고 이렇게 해뒀다.
따로 관리하면 한쪽만 고쳐져서 어긋난다.

## 문의 주소

`terms_documents.dart`의 `contactEmail` 하나를 앱과 웹이 같이 쓴다.
바꾸려면 그 상수만 고치고 다시 생성하면 된다.

이 주소는 세 군데에 쓰인다.
- 개인정보 처리방침의 보호책임자 연락처 (앱 화면 + 웹)
- 앱 없이 계정 삭제를 요청하는 창구 (웹)
- 각 페이지 하단 문의처 (웹)

## 어디에 올라가 있나

앱 저장소는 비공개라 GitHub Pages를 쓸 수 없어서, **약관용 공개 저장소를
따로 두고** 거기에 올린다.

```
https://yeoby97.github.io/JIMIKER-legal/
```

즉 이 `docs/` 폴더는 **원본**이고, 실제로 서비스되는 곳은 다른 저장소다.
둘이 어긋나지 않게 아래 순서를 지킨다.

### 약관을 고쳤을 때 (매번 이 순서로)

```bash
# 1) 원본을 고친다
#    lib/features/auth/terms/terms_documents.dart

# 2) 다시 뽑는다
dart run tool/generate_legal_pages.dart

# 3) 공개 저장소로 복사한다 (경로는 본인 환경에 맞게)
cp docs/*.html ../JIMIKER-legal/

# 4) 양쪽 다 커밋한다
#    - 이 저장소: docs/ 변경분
#    - JIMIKER-legal 저장소: 복사한 html
```

**3번을 빠뜨리면 앱과 공개 페이지의 내용이 달라진다.** 개인정보 처리방침이
실제 처리와 다르면 그건 그것대로 문제가 되므로 잊지 말 것.

복사할 파일은 `.html` 6개뿐이다. 이 README와 `play-store.md`는 우리끼리
보는 문서라 공개 저장소에 올릴 필요가 없다.

## Play Console에 넣을 곳

| 항목 | 주소 |
|---|---|
| 개인정보처리방침 | https://yeoby97.github.io/JIMIKER-legal/privacy.html |
| 계정 삭제 요청 (데이터 안전 항목) | https://yeoby97.github.io/JIMIKER-legal/account-deletion.html |

## 페이지가 지켜야 할 것

- 바깥에서 파일을 하나도 받아오지 않는다 (글꼴·CSS 전부 안에 들어 있다).
  외부 서버가 죽으면 약관이 안 보이고, 그건 심사에서 문제가 된다.
- 다크 모드와 좁은 화면에서 모두 읽힌다.
- 로그인 없이 열린다. 심사자는 계정 없이 이 주소를 연다.
