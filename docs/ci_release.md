# CI 자동 릴리즈 & Homebrew Cask 배포 가이드

> 태그(`vX.Y.Z`) 하나로 **빌드 → Developer ID 서명 → 공증(notarize) → DMG → GitHub Release → Homebrew Cask 갱신**까지 자동 수행.
> 트랙 B(Developer ID 직접 배포)를 자동화한 것. App Store/TestFlight 트랙은 `docs/release.md` Track A 참조.

## 구성 요소
| 파일 | 역할 |
|---|---|
| `.github/workflows/ci.yml` | push/PR마다 **서명 없이** 컴파일 확인 (빠른 sanity) |
| `.github/workflows/release.yml` | 태그 시 서명·공증·DMG·릴리즈·탭 갱신 |
| `ExportOptions-developerid.plist` | `xcodebuild -exportArchive`용 (method=developer-id, 수동 서명) |
| `.github/templates/taskocean.rb` | Homebrew Cask 템플릿 (`__VERSION__`/`__SHA256__` 치환) |
| `TaskOcean.xcodeproj/.../TaskOcean.xcscheme` | **공유 스킴** (헤드리스 CI 필수) |

> 프로젝트 pbxproj는 로컬 개발 편의를 위해 **Automatic 서명 그대로** 둔다. CI는 아카이브 시
> `CODE_SIGN_STYLE=Manual` + `Developer ID Application`으로 오버라이드하므로 로컬에 영향 없음.

---

## 1. 필요한 GitHub Secrets
`Settings → Secrets and variables → Actions → New repository secret` 에 등록:

| Secret | 내용 | 만드는 법 |
|---|---|---|
| `MACOS_CERTIFICATE_BASE64` | **Developer ID Application** 인증서(.p12)의 base64 | 아래 §2 |
| `MACOS_CERTIFICATE_PASSWORD` | 위 .p12 내보낼 때 지정한 암호 | §2 |
| `MACOS_SIGN_IDENTITY` | 서명 ID 전체 문자열 `Developer ID Application: … (4S9VPFZ465)` | §2 |
| `NOTARY_KEY_ID` | App Store Connect API Key ID | §3 |
| `NOTARY_ISSUER_ID` | App Store Connect Issuer ID | §3 |
| `NOTARY_KEY_BASE64` | API 키(.p8)의 base64 | §3 |
| `TAP_GITHUB_TOKEN` | `KingsFavor/homebrew-tap` 쓰기 권한 PAT | §4 |

> CI 임시 키체인 암호는 워크플로우가 런타임에 임의 생성하므로 별도 시크릿이 필요 없다.
> `TAP_GITHUB_TOKEN`이 없으면 릴리즈는 정상 생성되고 **탭 갱신만 스킵**된다(로그에 안내).

---

## 2. Developer ID 인증서 → base64 (.p12)
로컬 Mac(키체인에 Developer ID Application 인증서 + 개인키가 있는 상태)에서:

```bash
# Keychain Access에서 "Developer ID Application: ... (4S9VPFZ465)" 인증서를
# 개인키와 함께 선택 → 우클릭 → "2개 항목 내보내기" → certificate.p12 저장 (암호 지정)
# 그 암호가 MACOS_CERTIFICATE_PASSWORD.

base64 -i certificate.p12 | pbcopy    # → MACOS_CERTIFICATE_BASE64

# 서명 ID 전체 문자열(MACOS_SIGN_IDENTITY) 확인:
security find-identity -v -p codesigning | grep "Developer ID Application"
#   → 예: "Developer ID Application: Kwonwoo Lyu (4S9VPFZ465)"  (따옴표 안쪽만 등록)
```

인증서가 없다면: [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) →
Certificates → **Developer ID Application** 생성 → 다운로드 → 더블클릭으로 키체인 등록 → 위 절차.

## 3. App Store Connect API 키 (공증용)
notarytool는 앱암호 대신 API 키를 쓴다(권장).

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
2. **Team Keys** 에서 키 생성. 역할은 **Developer**(또는 App Manager)면 공증 충분.
3. 발급 시:
   - **Key ID** → `NOTARY_KEY_ID`
   - 상단 **Issuer ID** → `NOTARY_ISSUER_ID`
   - 다운로드되는 `AuthKey_XXXX.p8`(1회만!) → base64:
     ```bash
     base64 -i AuthKey_XXXX.p8 | pbcopy   # → NOTARY_KEY_BASE64
     ```

## 4. Homebrew 탭 저장소 + PAT
Cask는 **별도 탭 저장소**에 산다. 설치 경로: `brew install --cask kingsfavor/tap/taskocean`.

1. GitHub에 **공개** 저장소 생성: `KingsFavor/homebrew-tap`
   (이름은 반드시 `homebrew-` 접두어 — brew 규칙)
2. `Casks/` 폴더는 워크플로우가 자동 생성/커밋한다(초기엔 비어 있어도 됨).
3. PAT 발급:
   - Fine-grained token 기준: **Repository access → homebrew-tap**,
     Permissions → **Contents: Read and write**.
   - 값 → 이 저장소(taskocean)의 `TAP_GITHUB_TOKEN` secret 에 등록.

> 조직 규칙상 org 저장소에 PAT 대신 GitHub App/deploy key를 써야 한다면
> `release.yml`의 `update-homebrew-tap` job의 clone URL 인증만 교체하면 된다.

---

## 5. 릴리즈 실행
```bash
# 버전 올리기(예: 0.1.0 → 0.1.1) 후
git tag v0.1.1
git push origin v0.1.1
```
→ `release.yml`가:
1. Developer ID로 아카이브/서명 (버전=태그, 빌드번호=run number)
2. `xcrun notarytool submit --wait` 로 공증 → `stapler staple`
3. `TaskOcean-0.1.1.dmg` GitHub Release 업로드 + SHA-256 기록
4. `homebrew-tap`의 `Casks/taskocean.rb` 를 새 버전/해시로 커밋

수동 실행: Actions → **Release** → *Run workflow* → version 입력(태그 없이 테스트용).

## 6. 사용자 설치
```bash
brew tap kingsfavor/tap
brew install --cask taskocean
# 또는 한 줄:  brew install --cask kingsfavor/tap/taskocean
```

## 7. 검증/디버깅 팁
- **공증 로그**: 실패 시 `xcrun notarytool log <submission-id> --key ...` 로 원인 확인
  (주로 hardened runtime 누락, timestamp 없음, 서명 안 된 중첩 바이너리).
  현 프로젝트는 `ENABLE_HARDENED_RUNTIME=YES`, `--timestamp` 지정으로 충족.
- **Gatekeeper 확인(로컬)**: DMG 다운로드 후
  `spctl -a -t open --context context:primary-signature -vv TaskOcean-0.1.1.dmg`
- **Cask 문법 검사(로컬)**: 탭 클론 후 `brew audit --cask --new taskocean`,
  `brew style taskocean`.
- **서명 ID 확인**: 릴리즈 로그의 `security find-identity -v -p codesigning` 출력에
  `Developer ID Application: ... (4S9VPFZ465)` 이 보여야 함.

## 8. 스코프 메모 (CLAUDE.md §4 준수)
- 새 엔타이틀먼트 추가 없음. 서명/공증은 배포 파이프라인일 뿐 앱 런타임 권한과 무관.
- Sparkle 자동 업데이트는 아직 미도입 → Homebrew Cask 자체가 `brew upgrade`로
  업데이트 경로 제공. Sparkle 도입 시 appcast 생성 스텝을 `release.yml`에 추가.
