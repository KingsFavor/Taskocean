# Google Tasks OAuth 클라이언트 발급 가이드

실연동 코드는 **구현 완료** 상태다 (`TaskOcean/Sync/`, A72). 남은 것은 Google Cloud
콘솔에서 클라이언트 ID를 발급받아 한 줄 넣는 것뿐이다.

## 사용자가 할 일 (체크리스트)

1. **Google Cloud 프로젝트 생성** — https://console.cloud.google.com → 새 프로젝트 (예: `TaskOcean`)
2. **Tasks API 활성화** — APIs & Services → Library → "Google Tasks API" → **Enable**
3. **OAuth 동의 화면 구성** — APIs & Services → OAuth consent screen
   - User Type: **External**
   - 앱 이름 `TaskOcean`, 지원 이메일 입력
   - **Scopes** 단계에서 추가: `https://www.googleapis.com/auth/tasks`
     (openid/email/profile은 비민감이라 별도 등록 불필요)
   - **Test users**에 사용할 Google 계정 전부 추가 (개인 Gmail + 회사 계정)
4. **OAuth 클라이언트 ID 생성** — APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: **iOS** ← 중요 (아래 "왜 iOS 유형인가")
   - Bundle ID: `com.dws.taskocean`
5. 발급된 **Client ID** (`xxxx.apps.googleusercontent.com`)를 전달 →
   `TaskOcean/Store/GoogleOAuthConfig.swift`의 `clientID`에 주입하면 끝.
   리디렉션 스킴은 client ID에서 자동 파생되므로 다른 설정 불필요.

### 주의사항
- **현재 배포 상태: Production(정식) 모드 · Google 검증 미완료.** 임의 사용자가 로그인할 수 있으나,
  로그인 시 **"확인되지 않은 앱(This app isn't verified)"** 경고 화면이 뜬다 → *고급 → 이동*으로 진행.
  검증 전까지 **연결 계정 약 100명 상한**. (Testing 모드가 아니므로 아래 7일 만료는 해당 없음.)
- 참고 — **Testing 모드**였다면: 리프레시 토큰 7일 후 만료(주 1회 재로그인 배너), 테스트 사용자 100명 한정.
- `tasks` 스코프는 **민감(sensitive) 스코프** — 경고 없는 일반 공개로 가려면 Google 검증 필요.
  최장 지연 요인이므로 조기 착수 (PRD §10, §13).
- iOS 유형 클라이언트는 **client secret이 없다** (정상). PKCE가 그 역할을 대신한다.

## 왜 iOS 유형인가
macOS 네이티브 앱 + 커스텀 URL 스킴 리디렉션 조합의 공식 경로.
"Desktop app" 유형은 loopback(localhost) 리디렉션 전제라 App Sandbox의
`network.server` 금지와 충돌한다 (PRD §8.2, CLAUDE.md §4).

## 리디렉션 동작 (구현 세부)
- Google이 iOS 클라이언트에 요구하는 리디렉션은 **역방향 client ID 스킴**:
  `com.googleusercontent.apps.<id>:/oauthredirect`. `GoogleOAuthConfig.callbackScheme`이
  client ID에서 자동 파생한다.
- **Info.plist 등록 불필요** — `ASWebAuthenticationSession`이 콜백을 자체 가로채므로
  URL 스킴 등록 없이 동작한다. Info.plist의 `taskocean://` 스킴은 OAuth와 무관
  (향후 딥링크용으로 유지).

## 구현 현황 (TaskOcean/Sync/)
- [x] `GoogleOAuth.swift` — PKCE(S256) + state 검증 + ASWebAuthenticationSession, 토큰 교환/갱신/철회
- [x] `KeychainStore.swift` + `GoogleAccountSession.swift` — 계정별 토큰 격리, single-flight 갱신
- [x] `GoogleTasksAPI.swift` — REST v1 전체(CRUD/move/clear/페이지네이션), due 날짜 무손실 변환
- [x] `GoogleTasksRepository.swift` — 낙관적 스냅샷 + 내구성 outbox + 90초 폴링 병합 + 디스크 캐시
- [x] 스왑 배선 — clientID 설정 시 자동으로 실백엔드, 미설정/`TASKOCEAN_FORCE_MOCK=1`이면 목업

## 실계정 연결 후 검증할 항목
- [ ] `completed` 필드 쓰기 가능 여부 (문서 상충, A70) — 백데이팅 지원 판단용
- [ ] 부모 태스크의 리스트 간 이동 시 서브태스크 자동 추종 여부 (A72)
- [ ] Testing 모드 7일 만료 → needsReauth 배너 → 재로그인 경로 실사용 확인
