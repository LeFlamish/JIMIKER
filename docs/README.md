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

## 올리기 전에 반드시

`tool/generate_legal_pages.dart` 맨 위의 `contactEmail`을 실제 주소로 바꾸고
다시 실행한다. 자리표시자 상태로 두면 실행할 때 경고가 뜬다.

이 주소는 두 군데에 쓰인다.
- 개인정보 보호책임자 연락처
- 앱 없이 계정 삭제를 요청하는 창구

## GitHub Pages로 공개하기

1. GitHub 저장소 → **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: `main` (또는 기본 브랜치) / 폴더: **`/docs`**
4. Save

1~2분 뒤 아래 주소로 열린다.

```
https://leflamish.github.io/JIMIKER/
https://leflamish.github.io/JIMIKER/privacy.html
https://leflamish.github.io/JIMIKER/account-deletion.html
```

> **저장소가 비공개면 GitHub Pages를 못 쓴다.** (유료 플랜 필요)
> 그럴 때는 약관용 공개 저장소를 따로 만들어 `docs/` 안의 파일만 올리거나,
> Netlify · Vercel 무료 플랜에 이 폴더를 올려도 된다.
> 어느 쪽이든 URL만 확보되면 된다.

## Play Console에 넣을 곳

| 항목 | 주소 |
|---|---|
| 개인정보처리방침 | `.../privacy.html` |
| 계정 삭제 요청 (데이터 안전 항목) | `.../account-deletion.html` |

## 페이지가 지켜야 할 것

- 바깥에서 파일을 하나도 받아오지 않는다 (글꼴·CSS 전부 안에 들어 있다).
  외부 서버가 죽으면 약관이 안 보이고, 그건 심사에서 문제가 된다.
- 다크 모드와 좁은 화면에서 모두 읽힌다.
- 로그인 없이 열린다. 심사자는 계정 없이 이 주소를 연다.
