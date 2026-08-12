<div align="center">
  <img src="Taskfish_logo.png" alt="TaskOcean" width="96" />
  <h1>TaskOcean</h1>
  <p><b>Google Tasks를 화면 위에 늘 띄워두는 작고 조용한 macOS 유틸리티</b></p>
  <p><i>A small, quiet always-on-top Google Tasks companion for macOS.</i></p>
</div>

<p align="center">
  <img src="docs/screenshots/en/01-day-light.png" alt="Day view (light)" width="320" />
  <img src="docs/screenshots/en/02-day-dark.png" alt="Day view (dark)" width="320" />
</p>

---

## 무엇을 하나요

- **항상 위에 떠 있는 작은 창** — 다른 앱 위를 가리지 않게 조용히. 미니 / 컴팩트 / 확장 3가지 모드.
- **3초 캡처** — 전역 단축키로 어디서든 할 일을 바로 추가(자연어 입력 지원).
- **여러 Google 계정을 한 화면** — 업무·개인 계정을 액센트 색으로 구분해 함께.
- **하루에 집중** — `지남(Overdue) → 오늘 → 기한 없음` 순으로 오늘 할 일만.
- 서브태스크, 완료 정리, 계정 간 이동, 드래그 정렬, 검색, 활동 히트맵.
- 메뉴바 아이콘 · Dock 배지 · 로컬 알림, 라이트/다크, 한국어/영어.
- 항상 위 · 투명도 · 자동 페이드로 **방해는 최소**.

가볍고 네이티브입니다(SwiftUI, App Sandbox). 유휴 상태에서 조용합니다.

## 요구 사항

- macOS 14 (Sonoma) 이상
- Google 계정 (Google Tasks 동기화용)

## 설치

Homebrew Cask로 설치합니다(공증된 Developer ID 빌드):

```bash
brew install --cask kingsfavor/tap/taskocean
```

또는:

```bash
brew tap kingsfavor/tap
brew install --cask taskocean
```

## 업데이트

새 버전이 나오면 앱이 **조용히 알려줍니다** — 하루 한 번만 확인하고, 팝업으로 방해하지 않습니다.
새 버전이 있을 때만 창 상단에 얇은 안내 줄이 뜨고(✕로 닫으면 그 버전은 다시 뜨지 않음),
*설정 › 일반 › 업데이트*에서 현재 버전 확인·수동 확인·자동 확인 끄기를 할 수 있습니다.

언제든 직접 확인하려면 **메뉴 막대 › TaskOcean › 업데이트 확인…** 을 누르세요. 최신 여부를 알려주고,
새 버전이 있으면 **업데이트 명령어를 클립보드로 복사**할 수 있습니다.

업데이트 방법:

```bash
brew update && brew upgrade --cask taskocean
```

또는 [릴리스 페이지](https://github.com/KingsFavor/Taskocean/releases/latest)에서 최신 DMG를 받아 덮어쓰면 됩니다.

## 삭제

Homebrew로 설치했다면:

```bash
brew uninstall --cask taskocean
```

설정·캐시 등 **남은 데이터까지 함께 지우려면** `--zap`을 붙이세요:

```bash
brew uninstall --zap --cask taskocean
```

DMG로 직접 설치했다면 `/Applications`의 **TaskOcean.app을 휴지통으로** 옮기면 됩니다.
데이터까지 지우려면 아래 경로도 삭제하세요:

```bash
rm -rf ~/Library/Application\ Support/com.dws.taskocean \
       ~/Library/Caches/com.dws.taskocean \
       ~/Library/HTTPStorages/com.dws.taskocean \
       ~/Library/Preferences/com.dws.taskocean.plist
```

> 로그인 항목(자동 실행)은 앱을 지우면 macOS가 자동 정리합니다.

## Google 계정 연동

TaskOcean은 **실제 Google Tasks**와 동기화합니다. 첫 실행에서 **Google 계정 연결**을 누르면
브라우저 창으로 안전하게 로그인하고(OAuth 2.0 · PKCE, 앱은 비밀번호를 보지 않음), 여러 계정을
한 화면에서 함께 쓸 수 있습니다. 토큰은 macOS **키체인**에만 저장되고, 자체 서버 없이
앱이 Google과 직접 통신합니다. 변경은 즉시 반영된 뒤 백그라운드에서 Google Tasks로 동기화됩니다.

> ℹ️ 앱은 정식(Production) 모드라 **누구나 Google 계정으로 연결**할 수 있습니다. 다만 Google의
> 앱 **검증(verification)이 아직 진행 중**이라, 로그인 과정에서 **"확인되지 않은 앱"** 경고 화면이
> 표시됩니다 — **고급(Advanced) → TaskOcean(으)로 이동**을 눌러 진행하면 됩니다. 검증 완료 전까지
> 연결 가능한 계정 수에 상한(약 100명)이 있습니다.

## 사용 팁

- **전역 단축키**로 창을 어디서든 불러오고 바로 캡처합니다. 기본값은 *설정 › 단축키*에서 확인·변경할 수 있습니다.
- 창 모드(미니/컴팩트/확장)와 항상 위·투명도는 창 안에서 바로 전환됩니다.
- 메뉴바 아이콘에서 열기·빠른 동작에 접근할 수 있습니다.

## 개발 · 문서

개발 관련 자료는 [`docs/`](docs/)에 정리되어 있습니다 — 제품 요구사항, 디자인 레퍼런스, 진행 로그, 배포/CI 가이드 등. 목차는 [docs/README.md](docs/README.md) 참고.

## 라이선스

© 2026 DWS(KR). All rights reserved.
