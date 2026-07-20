# TaskOcean 배포 가이드 (TestFlight 우선)

번들 ID `com.dws.taskocean` · Team `4S9VPFZ465` (DWS(KR)) · 최소 macOS 14.0

## 현재 상태 (샌드박스 호환 체크리스트)
| 항목 | 상태 |
|---|---|
| App Sandbox 활성화 (`com.apple.security.app-sandbox`) | ✅ 첫 빌드부터 |
| 네트워크: `network.client`만 | ✅ |
| 전역 핫키: `RegisterEventHotKey` (접근성 권한 불필요) | ✅ 검증 완료 |
| OAuth: 커스텀 URL 스킴 `taskocean://` (loopback 서버 없음) | ✅ Info.plist 등록 |
| Hardened Runtime | ✅ |
| 로그인 아이템: `SMAppService` | ✅ |
| Keychain: `keychain-access-groups` | ⏳ 실 OAuth 붙일 때 추가 |

## Track A — TestFlight / App Store (1차 타깃)
1. **App Store Connect**에서 앱 등록: 번들 ID `com.dws.taskocean`, 플랫폼 macOS.
2. 아카이브:
   ```bash
   xcodebuild -project TaskOcean.xcodeproj -scheme TaskOcean -configuration Release \
     archive -archivePath build/TaskOcean.xcarchive
   ```
3. App Store용 export & 업로드 (자동 서명):
   ```bash
   xcodebuild -exportArchive -archivePath build/TaskOcean.xcarchive \
     -exportOptionsPlist ExportOptions-appstore.plist -exportPath build/appstore
   xcrun altool --upload-app ... # 또는 Xcode Organizer / Transporter
   ```
   `ExportOptions-appstore.plist`: `method=app-store-connect`, `teamID=4S9VPFZ465`.
4. TestFlight 내부 테스터 배포 → 심사 없이 즉시 테스트 가능(내부 100명).
   - 외부 테스터는 베타 심사 필요.
5. **주의:** 심사 제출 전 OAuth 민감 스코프 검증 상태 확인 (docs/oauth_setup.md §2).

## Track B — Developer ID 직접 배포 (병행)
1. Release 빌드를 **Developer ID Application: Kwonwoo Lyu (4S9VPFZ465)** 로 서명 (수동 서명 구성 또는 exportOptions `method=developer-id`).
2. 공증:
   ```bash
   ditto -c -k --keepParent TaskOcean.app TaskOcean.zip
   xcrun notarytool submit TaskOcean.zip --keychain-profile "AC_PROFILE" --wait
   xcrun stapler staple TaskOcean.app
   ```
   (`notarytool store-credentials AC_PROFILE` 로 App Store Connect API 키/암호 1회 등록)
3. DMG 패키징 후 동일하게 공증+스테이플.
4. Sparkle 자동 업데이트는 이 트랙 전용 — 빌드 플래그로 분리 예정 (PRD §8.6, 아직 미구현).

## 빌드 구성 메모
- 현재 프로젝트는 **자동 서명(Automatic)** — 로컬 개발/아카이브에 충분.
- App Store vs Developer ID **두 구성 분리**(entitlements/업데이트 계층)는 실배포 직전에 xcconfig로 분리한다.
- 버전: `MARKETING_VERSION` 0.1.0 / `CURRENT_PROJECT_VERSION` 1 — 업로드마다 build number 증가 필요.
