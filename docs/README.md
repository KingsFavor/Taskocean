# TaskOcean 개발 문서

사용자용 소개는 루트 [`README.md`](../README.md). 이 폴더는 **개발·설계·배포** 자료를 모읍니다.

## 목차

| 문서 | 내용 |
|---|---|
| [PRD.md](PRD.md) | 제품 요구사항 명세 (목표·비목표·API 제약·기능) |
| [design_reference.html](design_reference.html) | 디자인 레퍼런스 (팔레트·창 모드·컴포넌트, HTML 목업) |
| [dev_note.md](dev_note.md) | 개발 진행 로그 및 임의 결정 기록 (A1–) |
| [ci_release.md](ci_release.md) | CI 자동 릴리즈 + 애플 공증 + Homebrew Cask 배포 가이드 |
| [release.md](release.md) | 배포 트랙 개요 (TestFlight/App Store, Developer ID) |
| [oauth_setup.md](oauth_setup.md) | Google OAuth 클라이언트 설정 (실백엔드 연동용) |
| [brand_web_guide.md](brand_web_guide.md) | 브랜드/웹 표기 가이드 |
| [verify_live.md](verify_live.md) | 실기기 검증 절차 |
| [screenshots/](screenshots/) | 스크린샷 (`ko/`, `en/`) |

## 시작점

- **작업 규칙·설계 원칙:** 루트 [`CLAUDE.md`](../CLAUDE.md) — 코드 작성 전 필독.
- **아키텍처 요약:** UI는 `TaskRepository` 프로토콜에만 의존. 현재 `MockTaskRepository`(목업),
  이후 `GoogleTasksRepository`로 교체(`TaskOceanApp.swift` 한 줄 스왑).
- **릴리즈:** 태그 `vX.Y.Z` 푸시 → GitHub Actions가 서명·공증·DMG·Release·Cask 갱신. 상세는 `ci_release.md`.
