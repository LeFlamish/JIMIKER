# 플레이스토어 출시 체크리스트

지미커를 스토어에 올리기까지 남은 일. 코드로 끝난 것은 ✅, 사람이 해야
하는 것은 ☐ 로 표시했다.

---

## 1. 업로드가 막히는 것

### ✅ 패키지명 → `com.jimiker2.app`

`com.example.jimiker`에서 바꿨다. Play는 `com.example`로 시작하는 패키지를
받지 않는다. **한 번 올리면 영원히 못 바꾸므로 다시 손대지 말 것.**

바뀐 곳:
- `android/app/build.gradle.kts` — applicationId, namespace
- `android/app/src/main/kotlin/com/jimiker2/app/MainActivity.kt` — 패키지 · 경로
- `android/app/google-services.json` — 새 앱 등록 포함
- `lib/services/firebase_options.dart` · `firebase.json` — android appId

Firestore 데이터, Storage 파일, Auth 가입자(UID 포함), Functions는 그대로다.

> 이름에 `2`가 붙은 이유: `com.jimiker.app`으로 SHA-1을 등록하려니
> "다른 프로젝트에 같은 SHA-1 + 패키지명 조합이 있다"는 경고가 떴다.
> 조합이 겹치면 구글 로그인이 엉뚱한 OAuth 클라이언트로 붙을 수 있어
> 패키지명을 바꿔 피했다.

#### ✅ SHA-1 등록 완료

`com.jimiker2.app`에 디버그 인증서 지문 4개가 등록돼 있다.
(`google-services.json`의 `client_type: 1` 항목 4개)

나중에 다른 PC에서 빌드하면 그 기기의 디버그 지문을 추가해야 한다.

```bash
cd C:\JIMIKER\android
gradlew signingReport      # Variant: debug 의 SHA1 복사
```

Firebase 콘솔 → 프로젝트 설정 → `com.jimiker2.app` 앱 → **디지털 지문 추가**

> 지문을 추가한 뒤 `google-services.json`을 다시 받지 않아도 된다.
> SHA-1은 구글 서버 쪽 설정이고 앱에 들어가는 값이 아니다.

#### ☐ Maps 키 제한 변경

Google Cloud Console → 사용자 인증 정보 → Maps 키 →
애플리케이션 제한을 `com.jimiker2.app` + 같은 SHA-1로 바꾼다.
안 바꾸면 지도가 회색으로 나온다.

#### iOS는 아직 그대로

`GoogleService-Info.plist`도 없고 APNs도 설정 전이라 번들 id를 바꾸면
Firebase에 등록된 iOS 앱과 어긋나기만 한다. iOS를 실제로 낼 때
Firebase에 iOS 앱을 새로 등록하면서 `project.pbxproj`와
`firebase_options.dart`의 `iosBundleId`를 함께 고친다.

### ☐ 업로드 키스토어

#### 열쇠가 두 개다

```
내 PC                  Google Play                 사용자 기기
─────                  ───────────                 ──────────
업로드 키로 서명   →   업로드 키로 본인 확인  →   앱 서명 키로
(내가 보관)            → 앱 서명 키로 재서명       서명된 앱 설치
                       (구글이 보관)
```

- **업로드 키** — 여기서 만드는 것. Play에 올릴 때 본인임을 증명한다
- **앱 서명 키** — 구글이 만들어 보관한다. 사용자에게 가는 앱에 찍히는 도장

내 PC에서 빌드한 앱과 스토어에서 받은 앱은 **서명이 다르다.**
그래서 6번(첫 업로드 후 할 일)에서 Play의 SHA-1을 Firebase에 또 등록해야 한다.

#### 만들기

`keytool`은 Android Studio가 들고 있는 JDK에 있다.

```powershell
mkdir C:\keys

& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -genkey -v `
  -keystore C:\keys\jimiker-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

물어보는 것 중 국가 코드는 `KR`, 키 비밀번호는 그냥 Enter를 치면
저장소 비밀번호와 같아진다. `-validity 10000`은 약 27년으로,
Play가 요구하는 2033년 이후까지 유효하다.

#### 연결하기

`android/key.properties`를 만든다 (깃에 안 올라간다. 양식은
`android/key.properties.example`).

```properties
storeFile=C:/keys/jimiker-upload.jks
storePassword=(비밀번호)
keyAlias=upload
keyPassword=(비밀번호)
```

⚠️ 윈도우에서도 슬래시(`/`)를 쓴다. 역슬래시는 이스케이프로 읽혀 경로를 못 찾는다.

✅ 이 파일이 있으면 릴리스 빌드가 자동으로 이 키로 서명된다.
없으면 예전처럼 디버그 키로 서명된다(개발용).

#### 확인

```powershell
flutter build appbundle

& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -list -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

소유자에 입력한 이름이 나오면 성공이다.
`CN=Android Debug`가 나오면 `key.properties`를 못 읽은 것이다.

#### 백업

- `.jks` 파일을 저장소 폴더 **바깥**에, 두 곳 이상에
- 비밀번호 두 개도 함께

업로드 키를 잃어버려도 구글에 요청하면 본인 확인 후 새 키를 등록해준다.
"영원히 못 고친다"까지는 아니지만 며칠 걸리고 지원팀을 거쳐야 하니
백업해두는 편이 훨씬 싸다.
(진짜 못 바꾸는 앱 서명 키는 구글이 보관하므로 잃어버릴 일이 없다)

### ☐ 앱 아이콘

지금 **Flutter 기본 로고**다. 512×512 PNG를 만들어야 한다.
Play Console에도 같은 아이콘을 따로 올린다.

만든 뒤 `flutter_launcher_icons` 패키지를 쓰면 해상도별로 한 번에 만들어준다.

---

## 2. 공개 URL

✅ 페이지 생성 (`docs/`, 원본은 `terms_documents.dart`)
✅ 문의 주소 기재 (`qordudduq@gmail.com`)
✅ 공개 완료 — https://yeoby97.github.io/JIMIKER-legal/

앱 저장소가 비공개라 약관용 공개 저장소를 따로 뒀다.
**약관을 고치면 그쪽에도 복사해야 한다.** 순서는 `docs/README.md` 참고.

Play Console에 넣을 두 주소:

```
개인정보처리방침
https://yeoby97.github.io/JIMIKER-legal/privacy.html

계정 삭제 요청
https://yeoby97.github.io/JIMIKER-legal/account-deletion.html
```

- ☐ Play Console에 두 주소 입력

### 올리고 나서 직접 확인할 것

심사자는 **로그인하지 않은 상태로** 이 주소를 연다. 시크릿 창에서 확인한다.

- ☐ 시크릿 창에서 두 주소가 모두 열리는가 (404가 아닌가)
- ☐ 첫 화면(`/`)의 링크 5개가 모두 열리는가
      (service · privacy · location · marketing · account-deletion)
- ☐ 각 페이지 왼쪽 위 "지미커"를 누르면 첫 화면으로 돌아가는가
- ☐ 하단 문의 메일 주소가 맞는가
- ☐ 휴대폰에서 열었을 때 글자가 잘리지 않는가

---

## 3. 데이터 안전(Data Safety) 양식 답안

Play Console에서 항목별로 묻는다. 아래는 지금 코드 기준 사실이다.
**기능을 추가하면 이 표도 같이 고쳐야 한다.**

### 공통
| 질문 | 답 |
|---|---|
| 데이터를 수집하거나 공유하나요? | **예** |
| 전송 중 암호화되나요? | **예** (Firebase 전 구간 HTTPS/TLS) |
| 사용자가 삭제를 요청할 수 있나요? | **예** — `.../account-deletion.html` |

### 수집 항목

| 유형 | 항목 | 수집 | 공유 | 필수 | 용도 |
|---|---|---|---|---|---|
| 개인 정보 | 이름 | 예 | 아니오 | 필수 | 앱 기능 (상대에게 표시) |
| 개인 정보 | 이메일 주소 | 예 | 아니오 | 필수 | 앱 기능, 계정 관리 |
| 사진·동영상 | 사진 | 예 | 아니오 | 선택 | 앱 기능 (창고 등록, 채팅) |
| 위치 | 대략적인 위치 | 예 | 아니오 | 선택 | 앱 기능 (주변 창고 표시) |
| 위치 | 정확한 위치 | 예 | 아니오 | 선택 | 앱 기능 (주변 창고 표시) |
| 메시지 | 다른 앱 내 메시지 | 예 | 아니오 | 선택 | 앱 기능 (1:1 문의) |
| 앱 활동 | 앱 상호작용 | 예 | 아니오 | 선택 | 분석 |
| 앱 정보·성능 | 진단 | 예 | 아니오 | 선택 | 분석 |
| 기기·ID | 기기 또는 기타 ID | 예 | 아니오 | 선택 | 앱 기능 (푸시 알림), 분석 |

**"기기 또는 기타 ID"를 빠뜨리지 말 것.** `firebase_analytics`가
광고 ID(`AD_ID`) 권한을 자동으로 넣기 때문에 선언하지 않으면 반려된다.
맞춤 광고에는 쓰지 않으므로 용도는 **분석**으로 답한다.

위치는 "임시로만 처리하고 저장하지 않음"에 해당한다. 지도를 그리는 데만
쓰고 서버에 남기지 않는다. (창고의 좌표는 개인 위치가 아니라 매물 정보다)

---

## 4. 그 밖에 Console에서 채울 것

- ☐ 앱 이름: **지미커**
- ☐ 짧은 설명 (30자): `안 쓰는 공간을 빌려주고, 필요한 만큼 빌려 쓰는 창고 중개`
- ☐ 자세한 설명 — 아래 초안 참고
- ☐ 스크린샷 (휴대전화 최소 2장, 1080×1920 권장)
- ☐ 그래픽 이미지 1024×500
- ☐ 콘텐츠 등급 설문
- ☐ 타겟 고객층: **만 18세 이상** (거래 서비스이므로)
- ☐ 광고 포함 여부: **아니오**
- ☐ 개발자 연락처 이메일

### 자세한 설명 초안

```
지미커는 남는 보관 공간을 빌려주려는 사람과, 짐을 맡길 곳이 필요한
사람을 연결하는 중개 서비스입니다.

■ 창고를 찾는 분
- 지도에서 내 주변 창고를 한눈에 확인
- 창고 내부 구역 배치를 보고 원하는 자리를 직접 선택
- 구역별 가격과 이용 가능한 날짜를 미리 확인
- 궁금한 점은 창고 주인과 1:1 문의로 바로 대화

■ 창고를 빌려주는 분
- 사진과 구역 배치를 그려 창고를 등록
- 구역마다 크기와 금액을 따로 설정
- 들어온 예약 요청을 확인하고 승인 또는 거절
- 등록한 창고는 검토를 거쳐 지도에 노출

■ 이용 흐름
예약 신청 → 주인 승인 → 시작일에 이용 시작 → 종료일에 이용 내역으로 보관

지미커는 거래를 중개하며, 창고의 이용 조건과 보관물에 대한 책임은
거래 당사자에게 있습니다.
```

---

## 5. 코드에서 끝난 것

- ✅ 가입 시 약관 동의 (동의 전에는 계정을 만들지 않음)
- ✅ 앱 내 계정 삭제 (`내 정보 > 회원 탈퇴`)
- ✅ 앱 내 약관 열람 (`내 정보 > 약관 및 정책`, 로그인 화면)
- ✅ 앱 이름 `지미커`
- ✅ 릴리스 서명 설정 (`key.properties`가 있으면 자동 적용)
- ✅ 키스토어 `.gitignore` 처리
- ✅ 동작하지 않던 스마트키 버튼 제거
- ✅ 위치 권한 런타임 처리 (거부해도 앱이 동작함)
- ✅ targetSdk 36 (Play 요구 35 이상 충족)
- ✅ Firestore · Storage 보안 규칙

---

## 6. 첫 업로드 **후에** 꼭 할 일

### ☐ Play 앱 서명 키의 SHA-1을 Firebase에 등록

**Play Console → 설정 → 앱 무결성 → 앱 서명 키 인증서 → SHA-1 인증서 지문**
을 복사해 Firebase 콘솔의 Android 앱에 추가한다.

구글이 업로드한 AAB를 **자기 키로 다시 서명**하기 때문에, 이걸 등록하지
않으면 **스토어에서 받은 앱에서만 구글 로그인이 실패한다.**
내 기기에서 직접 빌드한 것은 잘 되는데 스토어 버전만 안 되는 증상이라
원인을 찾기 어렵다. 가장 흔한 실수다.

같은 SHA-1을 Google Cloud Console의 Maps 키 제한에도 추가한다.

---

## 7. 아직 남은 기능적 숙제 (출시를 막지는 않음)

- 이용 연장, 리뷰, 신고 기능 없음
- iOS 푸시 미설정 (APNs 키 업로드 + Xcode capability)

## 8. ⚠️ 반드시 함수를 먼저 배포할 것

앱의 핵심 동작이 서버 함수로 옮겨져 있다. **배포하지 않으면 앱이 반쪽만
동작한다.**

- 예약 생성 (`createReservation`) — 규칙에서 앱의 직접 생성을 막았으므로
  배포 전엔 아무도 예약할 수 없다
- 위치 검색 (`searchPlaces` · `getPlaceDetail`) — Places 키를 앱에 넣지
  않고 서버가 대신 호출한다
- 창고 삭제 승인·반려 (`approveStorageDeletion` · `rejectStorageDeletion`)
  — 규칙에서 앱의 직접 삭제를 막았으므로 배포 전엔 삭제 절차가 안 돈다
- 채팅 안 읽음 뱃지 (`onChatMessageCreated`) — 없어도 대화 자체는 된다

### 배포 순서

```bash
# 1) 위치 검색용 Places 키를 서버 시크릿으로 넣는다 (최초 1회 / 키 교체 시)
#    이 키는 "애플리케이션 제한 없음 + Places API만 허용"으로 만든 서버 전용 키.
#    앱에 안 들어가므로 SHA 제한과 무관하다.
firebase functions:secrets:set PLACES_API_KEY

# 2) 함수와 보안 규칙을 배포한다
firebase deploy --only functions,firestore:rules
```

⚠️ **시크릿을 넣거나 바꾼 뒤에는 반드시 재배포해야 한다.** 함수는 배포
시점의 시크릿 값을 물고 올라가므로, `secrets:set`만 하고 재배포를 안 하면
옛 값(또는 무효 키)으로 계속 돈다. 검색이 `internal` 오류를 내면
`firebase functions:log`에서 `searchPlaces`의 실제 원인을 확인한다.
("The provided API key is invalid"면 키가 죽었거나 재배포 전이라는 뜻)
