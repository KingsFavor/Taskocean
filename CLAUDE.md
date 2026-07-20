# TaskOcean — 개발 지침 (Working Guidelines)

> 이 문서는 **작업 전에 반드시 읽는다.** TaskOcean은 "작고 조용한 상시 유틸리티"다.
> 코드를 쓰기 전, 지금 하려는 일이 이 앱의 **의도**와 **설계 원칙**에 맞는지 먼저 자문한다.

## 0. 한 줄 정체성
Google Tasks를 macOS 화면 위에 **항상 떠 있는 작은 창**으로 두고, **전역 단축키로 3초 안에 캡처**하며, **여러 Google 계정을 하나의 화면**에서 보는 경량 네이티브 앱.
(근거: `PRD.md` §1, §3. 디자인: `design_reference.html`)

## 1. 코드 쓰기 전 체크리스트 (Think-Before-You-Build)
새 기능/변경을 시작하기 전에 아래를 통과해야 한다:

1. **의도 부합** — 이 변경이 "항상-위 · 빠른 캡처 · 멀티 계정 · 하루 집중"이라는 핵심 가치를 강화하는가? 아니면 스코프 확장인가?
2. **비목표 위반 아님** — `PRD.md` §3.2를 어기지 않는가? (Windows/Linux, 자체 백엔드, 협업, 프로젝트 관리 고급 기능, **달력 그리드 뷰**, API 미지원 기능의 임의 구현 = 전부 금지)
3. **API 제약 존중** — `PRD.md` §8.4를 어기지 않는가? (마감일=날짜 단위만, 서브태스크=1단계만, 반복/리마인더/푸시 없음, 계정 간 이동=재생성+삭제, 폴링 기반)
4. **샌드박스 호환** — App Sandbox에서 통과하는가? (§4 참조) TestFlight/App Store가 1차 타깃이다.
5. **경량성** — 유휴 시 CPU/메모리/네트워크를 늘리지 않는가? 불필요한 타이머·폴링·애니메이션을 추가하지 않는가?
6. **결정 기록** — 임의로 결정한 사안이 생기면 `docs/dev_note.md`에 남긴다.

> 애매하면 **멈추고 설계 의도를 다시 확인**한다. 스코프를 넓히는 쪽으로 임의 확장하지 않는다.

## 2. 아키텍처 원칙
- **네이티브 SwiftUI + AppKit** (필요한 곳만 AppKit brige). 최소 macOS 14 Sonoma, 타깃 최신.
- **데이터 계층 추상화:** UI는 `TaskRepository` 프로토콜에만 의존한다. 현재 구현은 `MockTaskRepository`(목업), 이후 `GoogleTasksRepository`로 **교체만** 하면 되도록 UI와 동기화를 분리한다. → 지금 목업이라고 UI가 목업에 직접 묶이면 안 된다.
- **Source of truth = Google Tasks** (미래). 로컬은 캐시 + 낙관적 UI + 내구성 outbox. (§8.3) 지금은 인메모리 목업이지만 **동일한 인터페이스**를 유지한다.
- **상태 격리:** 계정별 세션/동기화는 독립적으로 다룬다. 한 계정 실패가 앱 전체를 막지 않는다. (§8.7)
- **단방향 데이터 흐름:** View → Intent/Action → Store(상태 변경) → View. 낙관적 업데이트를 전제로 설계한다.

## 3. 디자인 원칙 (design_reference.html 준수)
- **팔레트(고정):** 계정 액센트 — 업무 `#5B7CA8`(블루), 개인 `#B08363`(탄/브라운). 동기화 상태 그린 `#7ba86b`.
  - 라이트: 캔버스 `#E9E8E5`, 창 `#FFFFFF`, 패널 `#F4F3F0`/`#F1F0ED`, 본문 `#1b1b1a`, 뮤트 `#a6a5a1`.
  - 다크: 창 `#1D1D1F`, 카드 `#28282B`, 패널 `#3a3a3d`, 본문 `#F4F4F2`, 뮤트 `#7d7d78`.
- **모양:** 창 라운드 22, 카드 15, 칩 7–9. 그림자는 은은하게. 창 폭 기준 384pt(확장), 320pt(스트립).
- **타이포:** 본문 시스템 폰트(한국어 Pretendard 지향 → macOS는 SF/Apple SD Gothic Neo 기본). 로고 워드마크만 Playfair Display Italic 느낌(대체: 시스템 세리프 이탤릭). 로고 이미지는 `Taskfish_logo.png`.
- **밀도:** 작은 창에 많은 태스크를 읽기 쉽게. 여백·장식 최소.
- **방해 최소화:** 저채도, 반투명/페이드 옵션, 조용한 상태 표시(작은 점).
- **3가지 창 모드:** 미니(개수만 스트립) / 컴팩트(제목만) / 확장(상세). 하루 뷰 구성: `지남(Overdue) → 오늘 → 기한없음(Inbox)`.

## 4. 배포·샌드박스 규칙 (어기면 나중에 재작업)
1차 타깃 = **TestFlight/App Store** (App Sandbox 필수). Developer ID 공증도 병행 가능하게 추상화.
- **OAuth 리디렉션 = 커스텀 URL 스킴** `taskocean://` (loopback 로컬 서버 금지 — 샌드박스 `network.server` 회피).
- **전역 핫키 = `RegisterEventHotKey`(Carbon)** 만 사용. `CGEventTap`/전역 이벤트 모니터(접근성 권한 필요) 금지.
- **네트워크 = `com.apple.security.network.client`** 만. 서버 엔타이틀먼트 금지.
- **토큰 = Keychain** (App Store 빌드는 `keychain-access-groups`).
- **엔타이틀먼트 최소집합** 유지. 새 엔타이틀먼트 추가 전 `docs/dev_note.md`에 사유 기록.
- **업데이트 계층 추상화:** App Store 빌드=스토어 기본, Developer ID 빌드=Sparkle. 빌드 플래그로 전환.
- 서명: Team `4S9VPFZ465` (DWS(KR)). 번들 ID `com.dws.taskocean`.

## 5. 지금 상태 / 다음
- **현재:** UI 계층 **기능 완성**(목업 데이터). 디자인 01–06 전 상태 + PRD P0/P1 UI 구현·검증 완료(빌드 그린).
  - 구현됨: 하루 뷰(지남/오늘/Inbox)·3창모드·항상위/투명도/자동페이드·멀티계정/필터/리스트CRUD·서브태스크·완료정리·계정간 이동·드래그 리오더·퀵캡처(NLP)·전역단축키(재설정)·키보드 내비·검색·히트맵·메뉴바·Dock배지·로컬알림·재인증 격리·한/영·로그인 자동실행.
- **다음(실백엔드 단계):** `GoogleTasksRepository` 구현 → `MockTaskRepository` 스왑(`TaskOceanApp.swift` 한 줄). OAuth 발급은 `docs/oauth_setup.md`.
- 진행 로그와 임의 결정(A1–A19)은 `docs/dev_note.md` 참조. 배포는 `docs/release.md`.
