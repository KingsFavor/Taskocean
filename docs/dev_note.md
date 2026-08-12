# TaskOcean 개발 노트 (Decisions & Assumptions Log)

> 작업 중 **임의로 결정한 사안**과 **가정**을 여기에 남긴다. 나중에 사용자와 합의/수정하기 위한 기록.

## 확정된 설계 결정 (사용자 확인됨 — 2026-07-15)
- **OAuth 준비:** 지금은 **목업 데이터**로 개발. 실제 Google Tasks 연동은 config 자리표시자 + 발급 가이드만 준비하고, 이후 client ID 주입 시 실동작 전환.
- **빌드 순서:** **UI 먼저(목업) → 동기화 엔진 나중.** 단, UI는 `TaskRepository` 프로토콜에만 의존하도록 분리.
- **앱 정체성:** 표시 이름 **TaskOcean**(한 단어), 번들 ID **com.dws.taskocean**, URL 스킴 **taskocean://**.
- **배포 트랙:** **TestFlight/App Store 우선.** App Sandbox 활성화, 서명은 3rd Party Mac Developer 계열 기준. Developer ID 공증은 병행 가능하게 추상화.

## 환경 (실측 2026-07-15)
- Xcode 26.1.1 / Swift 6.2.1 / macOS 26.2 (빌드 25C56).
- 서명 ID 보유: `Apple Development (9F3D4Y5UGJ)`, `Developer ID Application: Kwonwoo Lyu (4S9VPFZ465)`, `3rd Party Mac Developer Application: DWS(KR) (4S9VPFZ465)`.
- **Team ID: `4S9VPFZ465` (DWS(KR)).**

## 임의 결정 (Assumptions — 사용자 검토 요망)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A1 | **최소 배포 타깃 macOS 14.0** | PRD NFR-5 floor=14 Sonoma. `MenuBarExtra`/`SMAppService`/String Catalog 사용 가능. | 지표 보고 하향 재검토(PRD §NFR-5) |
| A2 | **Xcode 프로젝트에 "synchronized file group" 사용** | Xcode 16+/26의 폴더 동기화 그룹으로 pbxproj 수동 편집 없이 소스 추가 가능 → 유지보수 단순. | 필요 시 전통적 그룹으로 전환 |
| A3 | **인메모리 목업 저장소(`MockTaskRepository`)** 초기 도입 | UI-first 개발. 실제 저장은 이후 outbox+캐시로 교체. 인터페이스는 동일 유지. | `GoogleTasksRepository`로 교체 |
| A4 | **로고 워드마크 폰트**: 시스템 세리프 이탤릭으로 근사(디자인의 Playfair Display 웹폰트는 앱에 번들하지 않음, 라이선스/경량성) | 앱 경량성 + 웹폰트 의존 제거 | Playfair Display OFL 폰트 번들로 교체 가능 |
| A5 | **계정 색상 2종 고정 팔레트 시드**(블루/브라운) + 추가 계정용 색 팔레트 확장 | 디자인 기준 2계정. 3+계정 시 색 순환 팔레트 제공. | 사용자 지정 색으로 확장 |

## 미해결 / 사용자 확인 필요
- Pro 가격 포인트, Developer ID 결제 공급자(Paddle vs Lemon Squeezy) — 베타 이후 (PRD §14).
- 히트맵 색 농도 임계값 — 디자인 확정 필요(PRD §14-3). 초기값은 임시 4단계로 구현.
- Tasks API `If-Match`/412 지원 스파이크 — 동기화 단계에서 검증 (PRD §8.3d).

## 임의 결정 (2차 — 구현 중)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A6 | **검색 아이콘 제거**(필터 바) | 검색은 P1(FR-6.4). 동작 없는 아이콘은 UX 해악 → 기능 구현 시 복원 | 아이콘+검색 구현 추가 |
| A7 | **미니 스트립 "N 남음" = 오늘 미완료 + 지남(Overdue) 합산** | "오늘 처리할 것"의 실질 수. PRD FR-4.2의 "미완료(또는 오늘 마감)" 해석 | 오늘만 카운트로 변경 가능 |
| A8 | **기본 전역 단축키: ⌥Space(퀵 캡처), ⌥⇧Space(창 토글)** | 디자인 표기(⌥Space) 준수. 재설정 UI는 P1(FR-5.7) | 설정에서 재매핑 구현 |
| A9 | **dev 전용 env 오버라이드** `TASKOCEAN_APPEARANCE`/`TASKOCEAN_MODE`/`TASKOCEAN_DEMO_REAUTH` | 시각 검증 자동화용. 미설정 시 무동작 — 릴리스 영향 없음 | 릴리스 빌드에서 #if DEBUG 처리 검토 |
| A10 | **완료 토글 시 부모→서브태스크 캐스케이드** | 일반적 UX 관례. Google Tasks 웹도 유사 동작 | 단독 토글로 변경 가능 |
| A11 | **OAuth 클라이언트 유형 = iOS 권장** (가이드) | 커스텀 URL 스킴 공식 지원, client secret 없음 = PKCE 강제 → 샌드박스·보안 정합 | Desktop 유형+loopback은 금지(§8.2) |
| A12 | 히트맵 임계값 임시 4단계: 0 / 1 / 2–3 / 4+ | PRD §14-3 미확정 → 임시값 | 디자인 확정 시 교체 |

## 검증 완료 (2026-07-15, 스크린샷 기준)
- 하루 뷰 라이트/다크 (디자인 01) · 정렬(계정→리스트→position, 완료 하단) · Overdue 배너/Inbox 상시 노출
- 컴팩트/미니 스트립 — 콘텐츠에 맞춰 창 축소 (디자인 02)
- 한/영 로케일 (시스템 언어 따름, 날짜 포맷 포함) (디자인 02)
- 전역 핫키 ⌥Space → 퀵 캡처 → Enter 저장 → Inbox 반영 (디자인 03). **접근성 권한 없이 동작 확인** (RegisterEventHotKey)
- 재인증 격리 — 배너 + 해당 계정 태스크 muted 표시(숨기지 않음), 타 계정 정상 (디자인 05)
- 히트맵 팝오버 — 월 그리드·로케일 주 시작·밀도 색·오늘 링 (디자인 05)
- App Sandbox + Hardened Runtime 켠 채 빌드/서명/실행 정상

## 미검증 / 다음 세션
- 편집 모달·컨텍스트 메뉴·필터 팬 팝오버·첫 실행 화면·메뉴바 팝오버 — 코드 완료, 시각 검증 미실시
- 드래그 정렬(FR-2.10), 창 투명도 슬라이더 동작, 히트맵 셀 클릭 이동 실클릭
- Sparkle 계층, 두 빌드 구성 분리 (릴리스 직전)

## 임의 결정 (3차 — 미구현분 완성)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A13 | **"저녁/Evening" 시간대 칩 미구현** | 디자인에 있으나 Google Tasks는 `due`가 날짜 단위(§8.4.1)라 시간 저장 불가. 로컬 시간대 라벨은 스코프 밖(§3.2) → 무결성 우선. | 앱-레벨 로컬 시간대 태그로 확장 가능(비동기 메타) |
| A14 | **NLP 날짜 파싱: 입력의 마지막 토큰만 검사** | 오탐(제목 중간 단어를 날짜로 오인) 방지. "내일/tomorrow/모레/요일명" 지원. | 형태소 분석기/더 넓은 문법으로 확장 |
| A15 | **단축키 재설정 = 프리셋 6종 선택** (자유 키 녹화 아님) | 안정적·간단. 자유 키 캡처 UI는 후속. | KeyRecorder UI 추가 |
| A16 | **로컬 알림 = 마감일별 1건(사용자 지정 시각, 06–22시)** | API 리마인더 미지원(§8.4.4) 우회. 향후 14일만 예약. | 태스크별 개별 알림으로 확장 |
| A17 | **드래그 리오더: 카드에 드롭 시 대상 바로 아래로 삽입** | 직관적 기본 규칙. mock은 `position` 재기록으로 순서 영속. 실백엔드는 `tasks.move(previous:)`. | 위/아래 삽입 위치 정밀화 |
| A18 | **⌘N = "새 할 일"로 재지정**(기본 "새 윈도우" 제거) | 단일 창 유틸리티라 New Window 불필요. **⌘N이 New Window와 충돌하던 버그 수정.** | 멀티 창 지원 시 복원 |
| A19 | **필터 패널 리스트 카운트 = 미완료·비서브태스크 수** | "남은 작업량" 의미. 디자인의 예시 숫자(6 등)와 다를 수 있으나 실데이터 일관. | 전체/완료 포함 카운트로 변경 가능 |

## 2차·3차 검증 완료 (2026-07-16, 스크린샷)
- 첫 실행(빈 계정) 화면 (디자인 06) · 검색 오버레이(⌘F/아이콘) (FR-6.4) · 편집/추가 모달 (디자인 06)
- Overdue 펼침 — `오늘로 이월`+`날짜 유지` 버튼, 지남 일수 표기 (디자인 04)
- 필터 패널 — 계정·리스트 토글, 리스트별 미완료 카운트, `리스트 추가`, `Google 계정 추가` (디자인 04)
- 전체 빌드 그린(경고 0). 모든 디자인 상태(01–06) 구현·확인.

## 남은 항목 (실백엔드 단계 또는 P2)
- **실 동기화**: `GoogleTasksRepository`(OAuth/Keychain/outbox/폴링/멱등/충돌) — `docs/oauth_setup.md` 가이드대로 client ID 발급 후 착수. UI는 준비 완료(스왑 한 줄).
- 화면 가장자리 스냅(FR-1.5 P2), 멀티 핀 창/위젯/Focus 연동(P2), 동적 글꼴 크기(FR-6.5 일부).
- Sparkle 자동 업데이트 계층 + App Store/Developer ID 빌드 구성 분리(릴리스 직전).
- 드래그 리오더·⌘1–9 리스트 선택·키보드 내비는 구현했으나 합성 입력 한계로 육안 검증은 부분적 → 실사용 확인 권장.

## 임의 결정 (4차 — 사용자 피드백 반영)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A20 | **창 이동 = 상단 크롬(타이틀바 영역)만.** `isMovableByWindowBackground=false` + 크롬/스트립 헤더에 `WindowDragArea`(`mouseDownCanMoveWindow=true`) | 배경 드래그가 태스크 드래그-리오더를 가로채던 문제 해결. 카드 영역은 리오더 전용. | 배경 드래그 재활성화 가능(단 리오더와 충돌) |
| A21 | **클릭-선택 테두리 제거.** 단일 클릭은 선택하지 않음(더블클릭=편집 유지). 선택 링은 **키보드 내비 시에만** 표시 | 사용자 피드백: 클릭 테두리 불필요 | 클릭-선택 복원 가능 |
| A22 | **드래그-리오더는 같은 계정 내로 제한.** 다른 계정으로의 드롭은 무시(계정 간 이동은 컨텍스트 메뉴의 재생성+삭제 경로) | reorder는 `listID`만 바꿔 계정 간엔 list/account 불일치 유발 → 무결성 보호(§8.4.5) | — |

> **API 정렬 지원 확인:** Google Tasks API `tasks.move`가 `previous`로 같은 리스트 내 재정렬을 **공식 지원**. 따라서 순서의 소스 오브 트루스는 서버 `position`이며, 로컬은 이를 기준으로 정렬 → **태스크 삭제(항목 제거)·외부 순서 변경(폴링 시 position 갱신)에 자연 대응**. 목업은 드롭 시 `position`을 조밀 재부여(`dropTask(_:onto:)` = 대상 바로 앞 삽입). 실백엔드에선 이 지점을 `tasks.move(previous:)` 호출로 교체.

## 검증 (2026-07-16, CGEvent 드래그 시뮬레이션)
- 태스크 카드 드래그 → **순서 변경됨**(디자인 목업이 PRD 위로), **창 위치 불변** ✓
- 상단 크롬 드래그 → **창 이동됨** ✓ (여전히 이동 가능)
- 카드 클릭 → 테두리 없음 ✓

## 임의 결정 (5차 — 계정별 섹션 분리)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A23 | **확장 뷰의 오늘·기한없음 섹션을 계정별 하위 섹션으로 분리**(2계정 이상일 때만, 계정 색 점+이름 헤더). 1계정이면 헤더 없이 병합 | 드래그-리오더는 같은 계정 내에서만 가능(A22) → 정렬 경계를 시각적으로 명확히. 사용자 요청 | 디자인 초기 기본(계정 색 병합 리스트)으로 복귀 가능 |

> 참고: PRD §6.6 기본은 "계정 색으로 구분한 병합 리스트 + 리스트별 그룹핑은 옵션"이었으나, 정렬 직관성을 위해 **계정별 분리를 확장 뷰 기본**으로 격상(사용자 확인). Overdue 그룹은 이월 액션 중심이라 분리 미적용(병합 유지).

## 임의 결정 (6차 — 섹션 접기 + 소제목 정리)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A24 | **섹션 접기/펴기**: 지난 미완료(Overdue)·기한 없음(Inbox)·각 계정 하위 섹션에 chevron 토글. 접힘 시 헤더에 카운트 표시, 태스크 숨김. 상태는 세션 메모리(`overdueExpanded`/`inboxExpanded`/`collapsedAccountSections`) | 사용자 요청. 밀도 관리 | 상태를 UserDefaults로 영속화 가능(추후) |
| A25 | **"오늘/날짜" 섹션 소제목 제거** | 상단 날짜 내비에 이미 날짜가 있어 중복. Overdue 배너 아래 바로 계정 섹션 노출 | 헤더 복원 가능 |
| — | **아바타 위치 이동**: 계정 하위 섹션 헤더에 아바타 표시, 태스크 카드 내부 아바타 제거(단일 계정·Overdue는 예외로 유지) | 계정 정체성을 헤더로 이동, 카드 시각 노이즈 감소. 사용자 요청 | — |
| — | **버그 수정**: LazyVStack의 형제 섹션(오늘/기한없음)이 같은 계정 id로 ForEach 충돌 → 기한없음 계정 헤더 미표시. 섹션 접두사로 id 유일화(`SplitRow`) | — | — |

## 임의 결정 (7차 — 시각 계층/타이포그래피 정리)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A26 | **3단 시각 계층 확립**: L1 섹션(지난미완료·기한없음)=13px 볼드 다크+구분선, L2 계정그룹=색 아바타+11.5px 컬러, L3 태스크=14.5px | 사용자 요청(시인성·직관성). 기존엔 L2가 L1보다 눈에 띄는 계층 역전 | 값 조정 가능 |
| A27 | **L1 섹션 스타일 통일**: 지난 미완료를 박스 배너 → 기한없음과 동일한 볼드 헤더로. 경고 아이콘+브라운 액센트로만 차별 | 사용자 지적: 섹션 간 스타일 불일치. `OverdueBanner` 제거, `SectionHeader`에 icon/accent 옵션 추가 | — |
| A28 | **"오늘" 시작 구분선**: 소제목은 없앤 채(A25), 지난 미완료 아래 구분선으로 오늘 영역 시작을 표시 | 소제목 없이도 오늘/지난미완료 경계 명확화 | — |

## 임의 결정 (8차 — 지난 미완료 카드 단순화)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A29 | **지난 미완료 카드의 "오늘로 이월"·"날짜 유지" 인라인 버튼 제거**. 이월 기능은 우클릭 컨텍스트 메뉴 **"오늘로 이동"**으로 이동(지난 태스크에만 표시, 문구는 사용자 지정). "날짜 유지"는 기능 자체 삭제(`keepOverdueDate`/`overdueDismissedIDs` 제거) — 접기 가능한 섹션(A24)이 같은 역할(오버레이 숨김)을 대체 | 사용자 요청. 384pt 폭에서 버튼 2개+아바타가 제목 줄바꿈 유발. PRD §6.6 "항목별 오늘로 옮기기"는 메뉴로 접근 유지 | 버튼 UI는 git 이력에서 복원 가능 |

## 임의 결정 (9차 — 빠른 추가 뱃지/날짜 선택기)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A30 | **공용 컴포넌트 `ComposeListPill`·`ComposeDatePill` 신설**(`Views/Components/ComposePills.swift`). 퀵캡처·확장 뷰 푸터가 동일한 뱃지→드롭다운 방식으로 계정·리스트·날짜를 지정 | 사용자 요청. 두 추가 인터페이스의 일관성 | — |
| — | **확장 푸터의 리스트 선택을 아래-화살표 Menu → 아바타 뱃지+팝오버로 교체**, 화살표 제거 | 사용자 요청("아래 방향 화살표를 뱃지로"). 부수 효과로 기존 `.menuStyle(.borderlessButton)+.fixedSize()` Menu가 좁은 행에서 0폭으로 붕괴하던 렌더 버그도 해소(Button+팝오버로 안정화) | — |
| — | **퀵캡처의 정적 계정 뱃지를 클릭 가능한 드롭다운으로** | 사용자 요청. 기존엔 표시 전용이라 ⌘1–9로만 변경 가능 | ⌘1–9 단축키는 유지 |
| A31 | **모든 추가 인터페이스에 날짜 선택기 추가**: `ComposeDatePill` = 오늘/내일 칩 + 그래픽 달력(`DatePicker(.graphical)`) + "없음"(Inbox). 기본값 = **현재 보고 있는 날짜**(`store.selectedDay`), 미조작 시 날짜 이동에 따라 따라감. 타이핑 NLP 날짜(예 "내일")가 있으면 그게 우선 | 사용자 요청 | — |
| — | **추가 기본 동작 변경**: 기존 "날짜 없으면 Inbox"(PRD §6.6) → **기본 = 보고 있는 날짜**. Inbox 추가는 날짜 칩에서 "없음" 선택으로 명시 | 사용자가 기본값을 보고 있는 날짜로 지정 | 날짜 칩 기본을 nil로 되돌리면 원복 |
| — | **`TaskEditorView` 신규 추가(⌘N)도 기본 마감일=보고 있는 날짜**로 정렬 | "모든 추가 인터페이스" 일관성 | else 분기의 hasDue/ due 기본 제거 |

> **비목표 확인**: `PRD.md` §3.2 비목표의 "달력 그리드 뷰"는 **태스크 브라우징용 월간 뷰**를 뜻함(금지). 여기 추가한 마감일 **입력 컨트롤**(팝오버 내 달력)은 사용자가 명시 요청한 "날짜 선택 - 달력이 있는 인터페이스"에 해당하며 브라우징 뷰가 아님. Google Tasks API는 날짜 단위 마감일 지원(§8.4.1). 따라서 위반 아님.

## 임의 결정 (10차 — 퀵캡처 단축키·커스텀 달력)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A32 | **퀵캡처 리스트 전환 단축키 ⌘1–9 → ⌘↑/⌘↓ 순환**. 하단 힌트도 "⌘↑↓"로 갱신 | 사용자 지적: 클릭 가능한 뱃지 드롭다운이 생겨 ⌘1–9 불필요. 순환 방식이 더 나음 | — |
| A33 | **날짜 팝오버의 달력을 네이티브 `DatePicker(.graphical)` → 커스텀 `MonthCalendar`로 교체**. 네이티브는 셀 크기가 고정이라 프레임을 키워도 달력 본체가 안 커짐(주변 여백만 늘어남) → 셀 38×34, 앱 팔레트(선택=브라운 `#B08363` 라운드, 오늘=아웃라인), 로케일 요일/첫요일 준수, 월 이동 chevron | 사용자 지적: "달력 자체가 너무 작다". 네이티브 한계 | 네이티브 DatePicker로 되돌릴 수 있으나 크기 문제 재발 |

## 임의 결정 (11차 — 옵션 히트영역·호버 피드백)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A34 | **재사용 `HoverOptionStyle`(ButtonStyle) 신설**: 옵션 프레임 전체를 히트영역(`contentShape`)으로 + 호버/프레스 시 `theme.panel` 배경. 달력 셀·리스트 드롭다운 행에 적용. 칩(오늘/내일/없음)은 `PopoverChip`(호버 시 `panel→panelStrong`) | 사용자 지적: ① 달력에서 숫자를 정확히 눌러야 할 만큼 히트영역이 작음 ② 눌러-열어-선택 방식 옵션에 호버 색이 없어 클릭 가능해 보이지 않음 | — |
| — | **적용 범위 판단**: 커스텀 "옵션 선택" 팝오버는 Compose 뱃지 2종이 전부. 나머지 컨텍스트/이동 메뉴는 네이티브 `Menu`(호버 기본 제공), FilterPanel은 토글 스위치 방식(행 전체 클릭 아님)이라 행 호버 미적용 | 네이티브·토글은 성격이 달라 제외 | 필요 시 FilterPanel에도 확장 가능 |

## 임의 결정 (12차 — 워드마크 컴포넌트)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A35 | **재사용 `Wordmark` 컴포넌트 신설**(로고 템플릿 이미지 + "TaskOcean"). 서체 = **시스템 세리프 이탤릭**(`.system(design: .serif).italic()`, weight bold). 퀵캡처 창 **상단 헤더**(로고+이름+구분선) 신규 추가, 메뉴바 팝오버 헤더도 기존 `fish.fill`+볼드 텍스트 → `Wordmark`로 교체 | 사용자 요청: 퀵 캡처 상단에 로고+이름, 이름 표기는 디자인의 서체·이탤릭 반영 | — |
| — | **Playfair Display 번들 대신 시스템 세리프 이탤릭 사용** | `CLAUDE.md` §3이 워드마크 대체 서체로 시스템 세리프 이탤릭을 명시(디자인 원본은 Playfair Display Italic 700). 폰트 파일 번들+Info.plist 등록은 스코프↑ → 추후 정확 재현이 필요하면 번들 가능 | 폰트 번들 시 `Wordmark`의 `.font`만 교체 |

> 디자인 근거: `design_reference.html` L460(메뉴바 헤더) — `font-family:'Playfair Display',Georgia,serif; font-style:italic; font-weight:700`. 로고는 `TaskOceanLogo`(template) 재사용.

## 임의 결정 (13차 — 창 모드 아이콘화)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A36 | **`WindowModePicker` 텍스트 → 아이콘**: 미니·컴팩트는 **둘 다 가로 직사각형**(커스텀 `RoundedRectangle().stroke()`, 미니 14×8 / 컴팩트 14×11로 높이만 ↑), 확장=`arrow.up.left.and.arrow.down.right`(전체화면 유사). 각 버튼 `.help(모드명)` → 이름은 **호버 툴팁**으로만. 선택 하이라이트 유지 | 사용자 요청: 직관 아이콘 + 텍스트는 호버 시에만. 미니/컴팩트 모두 가로 직사각형(높이 차) | 프레임 크기·심볼 교체 가능 |
| A37 | **미니·컴팩트 스트립에도 3버튼 `WindowModePicker` 노출**(기존 단일 "확장" 버튼 대체) | 사용자 요청: 미니/컴팩트에서도 세 버튼 모두 유지 | 스트립을 단일 버튼으로 되돌리기 가능 |
| A38 | **모드 전환 시 `withAnimation` 제거**(원자적 전환). 애니메이션으로 창 콘텐츠 크기를 바꾸면 리사이즈 도중 AppKit Auto Layout 제약 예외(EXC_BREAKPOINT, `_updateConstraintsForSubtreeIfNeeded`)로 **간헐 크래시**. A37로 미니↔컴팩트 직접 전환이 가능해지며 재현됨 → 애니메이션 제거로 해결. 3모드 왕복 7종 전환 크래시 0 검증 | 크래시 수정 | — |

## 임의 결정 (14차 — 컴팩트 퀵추가 단축키 안내)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A39 | **컴팩트 스트립 하단에 흐린 안내 푸터** 추가: "태스크 추가 : {단축키}". 단축키는 `HotKeyPreferences.capture.display`로 설정값 실시간 반영(기본 ⌥Space), `theme.textFaint`, 상단 구분선 | 사용자 요청. 컴팩트엔 추가 입력창이 없어 전역 단축키로 추가함을 안내 | 푸터 제거 |

> 참고: `HotKeyPreferences.capture`는 UserDefaults 계산값이라 관찰 대상 아님 → 설정 변경 즉시 리렌더는 안 되지만 다음 렌더 시 반영(단축키 변경 빈도 낮음, 허용).

## 임의 결정 (15차 — 태스크 개수 완료/전체 표기)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A40 | **섹션·계정 헤더의 개수 표시를 단일 숫자 → "완료/전체"**(예 "1/2"). 재사용 `CompletionCount(done:total:)`(완료=흐림, 전체=강조), `AppStore.tally(_:) -> (done, total)`. SectionHeader(지난미완료·기한없음)·AccountSubHeader에 적용. 툴팁 "완료 n · 전체 m" | 사용자 요청. 최초 "완료/미완료"로 구현했다가 사용자 정정으로 "완료/전체"로 변경 | 단일 카운트로 복귀 가능 |

> 카운트는 `showCompleted`(기본 true)로 필터된 표시 노드 기준. 완료 숨김 시 done=0이 되지만 현재 기본값에선 정확.

## 임의 결정 (16차 — 대규모 UX 개선 배치)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A41 | **핀 해제가 실제로 always-on-top을 끄도록 수정**. `WindowConfigurator`를 순수 `View`로 바꿔 body에서 `store.alwaysOnTop/opacity/showOnAllSpaces`를 읽고 `WindowConfigBridge`(NSViewRepresentable)에 값으로 전달 → 값 변경 시 `updateNSView` 호출됨. 기존엔 RootView.body가 alwaysOnTop을 안 읽어 `updateNSView` 미호출로 레벨이 안 내려감 | 사용자 버그 신고. 검증: 핀 토글 시 CGWindow layer 3↔0 | — |
| A42 | **확장 모드 3-존 분리**: 헤더(날짜+계정+게이지)와 푸터(할 일 추가)를 `theme.panel`로, 태스크 영역은 `theme.window`. 구분선으로 경계 | 사용자 요청 | — |
| A43 | **컴팩트 서브태스크 지원**: `CompactTaskRow` 신설 — 좌측 디스클로저로 서브태스크 인라인 펼침/접기, 각 서브태스크 체크 토글 | 사용자 요청 | — |
| A43b | **컴팩트 창 높이도 동적**: 리스트를 `StripHeightKey`로 측정→`min(max(h,38),440)` 프레임. 서브태스크 펼침/접힘에 따라 창 높이 증감(검증 261↔337). 캡 초과 시 스크롤 | 사용자 요청(여닫기 시 높이 조절) | 고정 높이로 복귀 가능 |
| A43c | **여닫기 튐 수정**: 프레임의 별도 `.animation(value: listHeight)` 제거. GeometryReader가 이미 애니메이션 중인 높이를 측정→listHeight 갱신하는데 거기에 또 프레임 애니메이션이 겹쳐(이중) 매 프레임 재시작→지연·요동, 부모 행까지 튐. 프레임이 측정 높이를 그대로 추종하게 함(확장 뷰와 동일 방식). 부모 고정, 하위만 이동 | 사용자 지적 | — |
| — | **컴팩트 서브태스크 들여쓰기**: 가이드 라인 + leading 50으로 부모 제목 아래 정렬 | 사용자 요청 | — |
| A44 | **태스크 카드 서브태스크 디스클로저**: 좌측에 회전 chevron(▶/▼) 추가로 펼침 가능함을 시사 | 사용자 요청 | — |
| A45 | **카드에서 "오늘" RelativeChip 제거** (상단 날짜와 중복) | 사용자 요청 | — |
| A46 | **동적 창 크기**: 확장 폭 420~520(기존 360~460), 세로는 `DayContentHeightKey`(PreferenceKey)로 콘텐츠 높이 측정→`min(max(h,180),760)` 스크롤 프레임에 반영(상한 캡). 측정 위해 day 콘텐츠 `LazyVStack→VStack`. 미니/컴팩트 폭 340 | 사용자: 작은창→확장이 너무 작음 | 프레임 값 조정 |
| A47 | **진행률 게이지** `ProgressGauge` 신설 — 완료/전체(overdue+오늘) 게이지 바. 확장(날짜 밑)·미니·컴팩트 공통. `store.dayProgress` | 사용자 요청 | — |
| A48 | **메모 없으면 카드 1줄**: `showsNotes`(노트 有+미완료)일 때만 노트 줄+제목 2줄, 아니면 제목 1줄 단일행 | 사용자 요청 | — |
| A49 | **완료 축하 애니메이션**: `CompletionCelebration`(링+스파크 버스트, token 기반 1회 재생) + 체크박스 팝 스케일. 게이지는 완료 시 흰 플래시+초록(`syncOK`) 강조 | 사용자 요청 | — |
| A50 | **옵티미스틱/성능 재정비**: `dayContent`를 계산 프로퍼티→**캐시**(`refreshDayContent()`가 reload 및 selectedDay/showCompleted/필터 didSet에서 갱신). 렌더당 수십 회 재계산되던 필터/정렬 제거. 알림 재계획은 400ms 디바운스+async로 토글 임계경로에서 분리 | 사용자: 완료 처리 피드백이 느림 | — |

## 임의 결정 (17차 — 리스트 관리 모달 분리)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A51 | **리스트 CRUD를 계정 필터 팝오버에서 분리 → 전용 모달 `ListManagerView`**. 필터바의 히트맵 버튼 **왼쪽**에 `list.bullet`(→간결화, 최초 `checklist`) 버튼 추가 → 시트로 모달 오픈. 계정별 그룹, 각 리스트: 인라인 이름변경(연필→TextField→체크 커밋), 삭제(⋯ 메뉴, 계정 마지막 리스트는 비활성), 완료정리(⋯ 메뉴), 계정별 "리스트 추가"(추가 후 즉시 이름편집). 고정 높이 480 + `ScrollView`로 다수 리스트 스크롤. `store.addList`가 새 `TaskList` 반환하도록 변경 | 사용자 요청: 계정 팝오버의 리스트 관리를 별도 버튼/모달로, 추가·수정·삭제 가능. 스크롤·간결 아이콘 | — |
| — | **`FilterPanel`에서 리스트 추가/삭제/완료정리 제거**(가시성 토글만 유지) | 관리 기능을 모달로 이관, 팝오버는 필터 전용 | — |

## 임의 결정 (18차 — 확장 뷰 반응성 개선)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A52 | **확장 뷰 동적 높이 측정 제거 → 고정 크기(460×760)**. A46의 `GeometryReader`+`DayContentHeightKey` 측정→프레임 높이 추종이, 토글/서브태스크 펼침 애니메이션 0.2초 동안 매 프레임 측정값을 바꿔 **NSWindow를 매 프레임 리사이즈**(고비용)→체감 지연. 측정 제거로 상호작용 중 창 리사이즈 0. `VStack→LazyVStack`(보이는 카드만 렌더). 콘텐츠는 내부 스크롤 | 사용자: 확장 화면 완료/서브태스크 반응 느림 | 측정 방식 복원 가능(단 지연 재발) |

> 검증: 토글·서브태스크 펼침 후 창 높이 792 불변. 컴팩트는 동적 높이 유지(작아 부담 적음, A43b 요청 반영). A46의 "동적 세로"는 확장에선 포기(속도 우선), 폭·높이 모두 기존보다 큼(384×620→460×760).

## 임의 결정 (19차 — 반응성 2차: 렌더 부하 감소)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A53 | **완료 축하 버스트를 상시 렌더 → 완료 순간에만 마운트**. 기존 `CompletionCelebration`은 모든 카드 체크박스에 7개 도형(opacity 0)이 항상 존재(카드 8개면 idle ~56 도형/렌더). `CelebrationBurst`(onAppear 재생)+부모 `if celebrating` 게이팅으로 idle 트리에서 제거 | A52(창 리사이즈 제거)로도 여전히 느림 → 실제 렌더 부하가 원인 | — |
| A54 | **완료 토글 `withAnimation` 제거(즉시 반영)**, 서브태스크 펼침·섹션 토글 `.snappy` 스프링 → `.easeOut(0.16)` | 스프링 정착 꼬리가 "느림"으로 읽힘. 완료는 즉시 피드백이 최선 | 애니메이션 복원 가능 |

> 데이터 경로 무비용 확인(mock `tasks()`=배열 그대로 반환, `toggleComplete`=플래그 토글). 지연은 순수 SwiftUI 렌더/애니메이션. 추가 지연 시 후보: 카드 그림자 재래스터, 카드별 `.contextMenu` eager 재평가.

## 임의 결정 (20차 — 반응성 3차: 진짜 원인)
> 사용자 결정적 단서: **섹션 여닫기는 빠른데 완료·서브태스크 열기만 느림**. → 원인 특정됨.

| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A55 | **카드 `Equatable`+`.equatable()`** (`TaskCardView`/`InboxRowView`/`OverdueCardView`/`CompactTaskRow`, `==`는 node 비교). 완료 시 `refreshDayContent()`가 모든 TaskNode 재생성→모든 카드가 새 node로 **전부 재렌더**였음(섹션 토글은 dayContent 불변→카드 재렌더 스킵→빨랐음). equatable로 **바뀐 카드 1개만** 재렌더 | 완료 처리 지연의 실제 원인 | equatable 제거 |
| A56 | **`reload()` 계정·리스트 스냅샷 조건부 재할당**(바뀔 때만). 모든 카드가 `store.account(…)` 관찰 → 매 토글 accountsSnapshot 무단 재할당이 전 카드 무효화 | 위와 결합해 완료 시 무관 카드 재렌더 0 | — |
| A57 | **서브태스크 추가 TextField 지연 생성**(버튼 뒤로). macOS `NSTextField` 생성 비용이 커서, 보기용 펼침마다 히칭. `addingSubtask` 시에만 TextField 마운트 | 서브태스크 열기 지연의 실제 원인 | 상시 TextField로 복귀 |

> 참고: `.equatable()`은 부모 주도 갱신만 게이트. 선택 링·다크모드는 카드가 `store.selectedTaskID`/`@Environment(theme)`를 직접 관찰하므로 그대로 갱신됨.

## 임의 결정 (21차 — 반응성 진짜 원인 + 카드 재구성)
> **측정으로 확정**: `toggle+reload`=0.67ms, 완료 시 카드 1개만 재렌더(equatable 작동), 그림자 제거도 무효 → 코드·렌더 문제 아님. 카드에서 **모든 제스처를 빼니 즉각 반응** → 원인 = 카드 제스처 아비트레이션.

| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A58 | **카드의 whole-card `.onTapGesture(count: 2)`(더블클릭 편집) 제거 → 콘텐츠(제목/메모)로 범위 축소**. 컨테이너 더블탭 제스처가 내부 컨트롤(체크박스·chevron)의 단일 탭을 더블클릭 타임아웃(~0.3s)만큼 지연시킨 것이 "살짝 느림"의 실제 원인. 섹션 헤더는 순수 버튼이라 안 느렸음 | 측정·실험으로 확정된 실제 원인. 사용자 확인("속도문제 해결됨") | — |
| A59 | **whole-card `.draggable`/`.dropDestination` 제거(드래그 리오더 비활성)**. 카드 드래그가 내부 버튼 탭을 드래그로 오인해 확장 버튼이 안 눌리고 지연 재발 | 탭 충돌. 추후 전용 드래그 핸들로 재도입 가능 | 핸들 방식 재구현 |
| A60 | **서브태스크 확장 컨트롤 재배치**: 좌측 chevron 제거 → 카드 **우측 끝**에 [진행률 게이지+chevron] 버튼(패딩으로 큰 탭 영역). `SubtaskProgress`의 **원형 아이콘 제거**(막대+n/m만) | 사용자 요청 | — |

> 유지: 우클릭 컨텍스트 메뉴(편집·이동·삭제), 콘텐츠 더블클릭 편집, 키보드 편집(⏎). 이전 성능 시도(equatable·완료정리 게이팅 등)는 무해·일부 유익하여 유지.

## 임의 결정 (22차 — 드래그 리오더 복구·개선)
| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A61 | **드래그 핸들 제거 → 카드 전체 `.draggable` 복구**. 탭 지연 원인이던 whole-card `.onTapGesture(count:2)`는 콘텐츠(제목/메모)로 이미 축소했으므로, whole-card 드래그를 넣어도 지연 없음(플레인 클릭은 이동 없음→내부 컨트롤로 통과, 드래그는 이동으로 인식) | 사용자 요청("핸들 말고 카드 자체 드래그") | — |
| A62 | **드롭 방향 기반 판정 + 삽입선 위/아래 표시**: `dropTask`가 방향으로 before/after 결정(dragged가 target보다 위→아래로 드래그→after). 삽입 예상 선이 위쪽에만 떠서 "맨 아래" 표현 불가였던 문제 해결 위해 `.draggable`→**`.onDrag`**(시작 콜백)로 바꿔 `store.draggingID` 기록 → hover 카드가 방향 알아 **선을 위(before)/아래(after)** 에 표시. `isAbove(_:_:)` 헬퍼. 맨 밑 카드 하단에 선→맨끝 이동 | 사용자: "맨 아래 삽입선 자체가 안 뜸". location·direction-only 모두 실패 | `.draggable`로 복귀 가능(단 방향 선 상실) |

| A63 | **리오더를 정석 `.onDrag` + `.onDrop(delegate:)`(둘 다 NSItemProvider 구형 API)로 통일**. `.onDrag`+`.dropDestination`(신형) 혼용은 인터롭이 안 돼 드롭이 죽었던 것으로 판단. `ReorderDropDelegate` 신설 — `DropDelegate`만이 **실시간 `info.location`** 을 줘서 행 상/하 절반 판정 → **삽입선을 위/아래에 표시**하고 하단 드롭(=아래로/맨끝 이동)이 가능. `.dropDestination`은 `isTargeted` Bool뿐이라 "맨 아래 삽입"을 표현할 수 없었음. `dropTask(_:onto:after:)` 위치 기반 복구. **2026-07-16 사용자 실사용 검증 완료 — 정상 동작(위→아래·맨 아래 이동 포함).** 리오더 관련 미해결 항목 없음 | 사용자: "맨 아래 삽입선 아예 안 뜸" (draggingID 방향 방식도 실패) | — |

> 시도·폐기 이력(모두 사용자 테스트로 실패 확인): ①location+`.dropDestination`(선 미표시) ②방향(position)기반 ③`.onDrag`+`.dropDestination`(인터롭 실패 추정). 최종 = `.onDrag`+`DropDelegate`.

## 임의 결정 (23차 — due 의미 정정 · 섹션 재배치 · 리스트 표기)
### A64 — `due`는 "마감일"이 아니라 "날짜(예정일)" (공식 문서 재확인)
Google Tasks API v1 `Task` 리소스 **날짜 필드는 `due` 하나뿐**:
> "**Scheduled date** for the task (RFC 3339). **Optional.** This represents the day that the task should be done, or that the task is visible on the calendar grid." / "Only date information is recorded; the time portion is discarded."

- 전체 필드: kind, id, etag, title, updated, selfLink, parent, position, notes, status, **due**, completed, deleted, hidden, links, webViewLink, assignmentInfo → **`deadline` 필드 없음**.
- Google Tasks **앱**은 2025년 별도 "deadline(마감일)" 기능 추가했으나 **공개 API 미노출**.
- → **별도 마감일 필드 구현 금지**(PRD §3.2·§8.4 "API 미지원 기능 임의 구현 금지", 동기화 불가). 대신 **라벨 정정**: "마감일"→"날짜"(ko), "Due"→"Date"(en), `overdueDetail`에서 "마감" 제거. `due`가 Optional인 점은 기존 "없음"(Inbox) 처리로 이미 반영됨.

| # | 결정 | 사유 | 되돌리기 |
|---|---|---|---|
| A65 | **섹션 재배치**: 오늘 → **지난 미완료** → 기한 없음. 지난 미완료·기한 없음 **기본 접힘**(`inboxExpanded` 기본 false). 경고 아이콘 제거, `SectionHeader`에 `titleColor` 추가해 **"지난 미완료" 제목만 브라운(#B08363)** 으로 긴급도 표현 | 사용자 요청. 하루(오늘)가 주인공, 나머지는 보조 | — |
| A66 | **리스트 정보 = 아이템 우측 태그**(섹션 분리 대신). 확장·컴팩트 **동일한 트레일링 슬롯**에 작은 뮤트 캡슐. 섹션을 리스트별로 또 쪼개면 계정(L2) 아래 3단이 되어 "한 눈에 보기"가 깨지고, 노트 없는 카드의 1줄 규칙도 유지됨 | 사용자 요청 + "한 눈 관점 해치지 말 것" | 리스트별 섹션 분리로 전환 가능 |
| A67 | **트레일링 메타를 하나의 `HStack(alignment: .center)` 로 묶음** → 노트가 있어 행이 `.top` 정렬일 때도 리스트 뱃지와 게이지가 서로 정렬됨. 파생 이슈 2건 동시 수정: ①`.layoutPriority(1)` 부여(폭 부족 시 "2/3"이 밀려 사라지던 것 → 긴 제목이 대신 truncate) ②`SubtaskProgress`의 **`GeometryReader` 제거 → 고정 폭 바**(greedy 레이아웃이 카드 높이를 부풀리던 것 해소) | 사용자 요청(뱃지·게이지 상하 정렬) | — |
| — | **`InboxRowView`도 동일 수정**: whole-row `.onTapGesture(count:2)`→제목으로 축소(체크박스 지연 제거), 드롭 위/아래 판정 추가. `OverdueCardView`는 경합 제스처 없어 무변경 | 일관성 | — |
- 2026-07-15: PRD·디자인 파악, 설계 질문 4건 확정. `CLAUDE.md`(지침)·본 노트 작성. Xcode 프로젝트 스캐폴딩 착수.
- 2026-07-15 (계속): SwiftUI 앱 전체 스캐폴딩 완료 — 모델/저장소 추상화(`TaskRepository`)/AppStore/하루 뷰/스트립/퀵 캡처/메뉴바/히트맵/설정/현지화(101키)/로고·앱 아이콘 생성/Xcode 프로젝트(objectVersion 77)/샌드박스 엔타이틀먼트. 빌드 그린, 핵심 플로우 스크린샷 검증. `docs/oauth_setup.md`·`docs/release.md` 작성.
- 2026-07-16: 미구현분 완성 — 리스트 CRUD·완료정리·계정간 이동(재생성+삭제), 드래그 리오더(position 영속), NLP 날짜 파싱(한/영), 전역 검색(FR-6.4), 키보드 내비(↑↓/⏎/⌘⏎/Space), 단축키 재설정 프리셋(FR-5.7), 로컬 알림(FR-6.2), Dock 배지(FR-4.2), 자동 페이드(FR-1.7), 서브태스크 인라인 추가, 동기화 상태 뱃지(FR-SYNC-8), Overdue "날짜 유지". **⌘N New Window 충돌 버그 수정.** 현지화 130키. 디자인 01–06 전 상태 재검증. 빌드 그린(경고 0).

## A68. 긴 텍스트 말줄임(ellipsis) 전면 감사 (2026-07-16)
**결정:** 모든 창 모드에서 제목/메모/리스트명/계정명이 길어져도 줄바꿈으로 카드 높이를
밀지 않도록, 텍스트 표시 지점 전체에 `lineLimit` + `.truncationMode(.tail)`을 명시한다.

**규칙**
- 태스크 제목: 확장 카드 2줄, 그 외(컴팩트 행·서브태스크·기한없음 행·드래그 프리뷰) 1줄.
- 메모·지남 상세: 1줄.
- 리스트 배지: 1줄 + 최대폭 상한(확장 92pt / 컴팩트 74pt) + **`.fixedSize()`(가로·세로 모두)**.
  최대폭이 없으면 긴 리스트명이 제목 영역을 압축하므로 폭 상한이 필수. 다만
  `.frame(maxWidth:)`는 *유연한* 프레임이라 그대로 두면 "디자인" 같은 짧은 이름까지
  상한폭만큼 늘어나 모든 배지가 같은 폭이 된다. `.fixedSize()`로 이상적(=글자) 폭을
  제안하게 하면 프레임이 그 값을 상한으로 클램프하므로 **짧으면 그대로, 길면 말줄임**이 된다.
  (`.fixedSize(horizontal:false, vertical:true)`는 가로를 제안값에 맡겨 늘어남 — 사용 금지)
- 계정명·이메일, 리스트 선택 팝오버/관리 모달/필터 패널의 리스트명: 1줄.

**감사에서 실제로 누락돼 있던 곳** — 지난 미완료 카드 제목, 기한 없음 행 제목,
서브태스크 제목(카드·에디터), 드래그 프리뷰 제목, 리스트 배지(확장·컴팩트),
계정 서브헤더 이름, 리스트 관리 모달·필터 패널·컴포즈 팝오버의 리스트명.

**검증:** 목업 시드에 긴 한글 문자열을 임시 주입해 full/compact/mini + 지난 미완료·기한 없음
전개 + 서브태스크 전개까지 스크린샷 확인 후 시드 원복.

## A69. 리스트 배지 일관 적용 + 확장 모드 동적 높이 복구 (2026-07-16)

### 1) `ListTag` 공용 컴포넌트로 통합
확장 카드/컴팩트 행에만 있던 리스트 배지를 **지난 미완료 카드·기한 없음 행**에도
동일하게 적용. 마크업이 네 벌로 늘어나므로 `Chips.swift`의 `ListTag(title:maxWidth:fontSize:)`
로 추출해 폭 상한 규칙(A68)을 한 곳에 모았다. 확장 92pt / 컴팩트 74pt.
- 지난 미완료 카드: 계정 아바타 왼쪽에 배치하고 그 묶음에 `.layoutPriority(1)` —
  긴 제목이 배지를 밀어내지 않게.
- 기한 없음 행: 계정 서브헤더로 묶이므로 리스트만 안 보이던 상태였음 → 후행에 배지.
- 완료된 태스크에는 표시하지 않음(기존 확장 카드 규칙과 동일).

### 2) 확장 모드 동적 높이 복구 — **회귀였음**
성능 문제 추적 중 "매 프레임 창 리사이즈가 원인"이라는 **오진**으로 확장 모드를
`.frame(width: 460, height: 760)` 고정으로 바꿨는데, 실제 원인은 카드 컨테이너의
`.onTapGesture(count: 2)`였음(A62 확정). 그런데 고정 프레임을 원복하지 않아
**확장 모드만 섹션·서브태스크 여닫기에 창 높이가 반응하지 않는 상태**로 남아 있었다.
컴팩트의 `StripHeightKey` 패턴을 그대로 옮겨 `DayListHeightKey`로 복구.
`.frame(height: min(max(listHeight, 60), 560))` — 상한을 넘으면 내부 스크롤.

**검증:** 전 섹션 접힘 653pt → 지난 미완료 펼침 783pt → 기한 없음 펼침 802pt(상한 도달,
내부 스크롤). 여닫기 애니메이션은 섹션 자체의 `withAnimation`만 사용(2차 애니메이션
추가 시 튐 — A55).

**교훈:** 오진으로 넣은 임시 변경은 오진이 확인된 즉시 원복할 것. 주석에 근거를
남겨뒀는데도(그 주석 자체가 틀린 근거였다) 몇 단계 뒤에야 사용자가 발견했다.

## A70. "기한(deadline)" 스코프 제외 확정 + 편집 모달 날짜 UI 통일 (2026-07-16)

### 1) 기한(deadline)은 구현하지 않는다 — 확정
공식 Tasks 웹/캘린더 UI에는 **날짜와 별개로 "기한"**을 지정하는 기능이 있다
(날짜 7/21 + 기한 7/22처럼 독립 설정). **이 기한은 공개 API에 노출돼 있지 않다.**

라이브 discovery 문서(`tasks.googleapis.com/$discovery/rest?version=v1`, 2026-07-16 확인):
- `deadline` 필드 **없음**. `starred`도 없음.
- `due` 설명이 직접 못박음 — "Scheduled date for the task... This represents the day
  that the task should be done, or that the task is visible on the calendar grid.
  **It doesn't represent the deadline of the task.** Only date information is recorded;
  the time portion of the timestamp is discarded when setting this field."
- `completed`는 별개 필드로 존재하고 읽기 가능(쓰기 가능 여부는 HTML 레퍼런스=Output only vs
  discovery=readOnly 플래그 없음으로 엇갈림 → 실 호출로 검증 필요. discovery의 readOnly
  플래그는 불완전하다: `hidden`은 플래그가 없는데 설명엔 read-only라고 적혀 있음).

**검토했으나 기각한 우회로**
- `notes`에 인코딩 → 공식 앱 설명란에 `[기한: 7/22]`가 그대로 노출, 사용자 데이터 오염.
- 로컬 전용 메타데이터 → 사용자가 **공식 앱에서 기한을 바꿔도 읽을 방법이 없어**
  우리 창에 조용히 틀린 기한이 남는다. 안 보여주는 것보다 나쁨.
  "Source of truth = Google Tasks"(CLAUDE.md §2) 및 PRD §3.2 위반.

**결론:** 우리의 "날짜" = `due`(예정일)이고 공식 앱의 날짜 필드와 정확히 같은 의미.
하루 뷰의 지남/오늘/날짜없음 구분도 전부 `due` 기준이라 의미가 어긋나지 않는다.
API에 열리면 그때 붙인다.

**부수 정정:** `inbox.header` 한국어가 "기한 없음"이었는데 영어는 이미 "No date"였다.
`due`가 없는 상태를 가리키므로 **"날짜 없음"**으로 수정 — 위 결정과 용어를 일치시킴.

### 2) 편집 모달 날짜 UI = 추가 인터페이스와 통일
편집 모달만 `Toggle(hasDue)` + 네이티브 `DatePicker(.date)` 조합이었다 → 퀵 추가/푸터와
같은 `ComposeDatePill`(오늘 · 내일 · 커스텀 달력 · 없음)로 교체.
- `hasDue: Bool` + `due: Date` 두 상태를 **`due: Date?` 하나로** 축소. 필의 "없음"이
  토글이 하던 역할을 이미 표현하므로 토글은 중복이었다.
- `editor.dateOnly`("날짜만 · 시간 없음") 문자열 삭제 — 필에는 시간 어피던스가 아예 없어
  경고할 대상이 없다. 추가 인터페이스도 이 라벨 없이 동작해왔다.
- "리스트" 행도 네이티브 `Picker` → `ComposeListPill`로 교체(후속 요청). Picker가 필요로 하던
  `"계정 · 리스트"` 합성 문자열은 필의 아바타가 계정을 표현하므로 불필요해져 사라짐.
- 힌트 라벨 2개 삭제: `editor.dateOnly`("날짜만 · 시간 없음"), `editor.oneLevel`("1단계까지").
  둘 다 API 제약을 설명하는 문구였지만 **UI가 이미 그 제약을 표현한다** — 필에 시간 어피던스가
  없고, 서브태스크에는 2단계를 만들 수단 자체가 없다. 못 하는 걸 굳이 말로 알릴 필요 없음.
  (제약 자체는 PRD §8.4.1/§8.4.2에 남아 있고 코드 주석으로도 유지)

**결과:** 편집 모달의 리스트·날짜 행이 퀵 추가/푸터와 완전히 동일한 컨트롤을 쓴다.

## A71. 편집 모달의 계정 간 이동 차단 — 잠복 버그 (2026-07-16)

**증상(사용자 지적):** 편집 모달 리스트 필로 다른 계정 리스트를 고를 수 있었다.

**실제로는 "이동"이 아니라 데이터 손상이었다.** `TaskItem.accountID`는 `let`이라 바뀌지
않는데 `save()`는 `t.listID = listID` 후 `updateTask` → mock은 `_tasks[i] = task`로 덮는다.
결과는 **accountID=A, listID=B계정의 리스트**인 모순 태스크:
- 하루 뷰는 `accountID`로 그룹핑 → 여전히 A 밑에 표시
- `ListTag`는 `store.list(task.listID)` → B 계정의 리스트 이름 표시
- 실 API에선 표현 불가 (A 엔드포인트에 B의 tasklist id를 patch → 404)

**A70이 만든 회귀가 아니다.** 기존 네이티브 `Picker`도 `ForEach(store.lists)`로 전 계정
리스트를 나열했고 `save()`도 동일했다 — 원래 있던 구멍. 다만 A70에서 계정별로 묶고
아바타를 붙인 필로 바꾸면서 **계정 전환을 적극 권하는 UI로 만들어** 노출을 키웠다.

**결정: 편집 시 같은 계정으로 제한.** 계정 간 이동은 재생성+삭제(PRD §8.4.5)라 **새 id가
생기고 position·completedAt·서브태스크 id가 전부 리셋**된다. 오타 고치러 들어온 사용자가
드롭다운 한 번으로 밟을 동작이 아니다. 우클릭 메뉴가 이미 "리스트 이동"(같은 계정) /
"계정 이동"(`moveTaskToAccount`)으로 올바르게 나눠 놨으므로 그 모델을 따른다.

**구현 (2중 방어)**
1. `ComposeListPill(lockedToAccountID:)` 추가 — 편집 시 `editing?.accountID` 전달로 해당
   계정 리스트만 표시. 신규 추가는 nil(전 계정) 유지 — 이땐 이동이 아니라 대상 선택이므로.
2. `AppStore.updateTask`에 가드 — 리스트의 accountID가 태스크와 다르면 `assertionFailure`
   (디버그에서 즉시 발각) + 릴리스에선 listID 변경만 무시하고 나머지 필드 수정은 반영.
   **UI만 막으면 코드에서 여전히 재현 가능하므로 모순 상태 자체를 표현 불가능하게 만든다.**

**교훈:** UI 컴포넌트를 공용화할 때 그 컴포넌트가 **원래 맥락에서 갖던 권한**(추가=전 계정
선택 가능)이 새 맥락(편집=계정 고정)에 그대로 딸려온다. 공용화는 모양만 옮기는 게 아니라
권한도 옮긴다.

## A63-note. 드래그 리오더 검증 방법 (2026-07-16)
`ReorderDropDelegate`(A63)는 **사용자 실사용으로 정상 확인**. 리오더 이슈는 종결.

**CGEvent 합성 드래그(`$TMPDIR/drag`)로는 SwiftUI의 Transferable/NSItemProvider 드래그
세션이 시작되지 않는다** — 그래서 A59~A63 내내 "고쳤는지" 를 에이전트가 자체 확인하지
못하고 사용자에게 되묻는 왕복이 반복됐다. 드래그·드롭 변경 시에는 스크린샷 검증을 시도하지
말고 **처음부터 사용자에게 테스트를 요청**할 것. (클릭·키보드는 `cliclick`으로 검증 가능,
단 한글 입력은 IME 때문에 불가 → 긴 문자열 테스트는 목업 시드에 임시 주입이 확실하다.)

## A72. 실백엔드 구현 — GoogleTasksRepository + OAuth 계층 (2026-07-16)

`TaskOcean/Sync/` 신설 4파일 + 배선. UI는 한 글자도 안 바뀜 — `TaskRepository` 심 그대로.

### 로그인 (써드파티 로그인 정비 요청)
RFC 8252(네이티브 앱 OAuth) 기준으로 구성:
- **PKCE S256** + **state 검증**(CSRF) + **client secret 없음**(iOS 유형 클라이언트)
- **ASWebAuthenticationSession** — 샌드박스 안전(루프백 서버 불필요, §8.2), 시스템 관리
  웹 플로우. **콜백 스킴은 Info.plist 등록 불필요**(세션이 자체 가로챔) → 리디렉션은
  Google 요구대로 역방향 client ID 스킴, `GoogleOAuthConfig.callbackScheme`에서 자동 파생.
  기존 `taskocean://oauth/callback` 상수는 폐기(문서의 "구현 단계에서 확정" 항목 확정).
- 계정 추가 = `prompt=select_account`(브라우저의 현 세션 무단 재사용 방지),
  재인증 = `login_hint`(해당 계정 프리셀렉트). 재인증에서 **다른 계정을 고르면 sub 불일치로
  거부**하고 needsReauth 유지 — 세션 바꿔치기 방지.
- id_token(JWT) 페이로드에서 sub/email/name/hd 추출(서명 검증 불필요 — 토큰 엔드포인트
  TLS 직수신). `hd` 유무로 workspace/personal 판별. **Account.id = Google `sub`**
  (이메일 변경에도 안정).
- 토큰: **Keychain**(data-protection keychain, 계정별 1항목 격리). 갱신은 **single-flight**
  (동시 401이 갱신을 중복 발사하면 Google의 리프레시 토큰 회전과 충돌 가능). 만료 60초 전
  선제 갱신. `invalid_grant` → needsReauth(계정별 격리, §8.7). 계정 제거 시 revoke + Keychain 삭제.

### 데이터 (PRD §8.3)
- **낙관적 스냅샷**: 모든 뮤테이션 즉시 로컬 반영(temp id `local-…`) → UI 지연 0.
- **내구성 outbox**: 오퍼레이션 저널을 디스크 영속(Application Support/TaskOcean/outbox.json)
  → 재실행에도 유실 없음. 계정별 FIFO 플러시. 실패 분류: 401→토큰 갱신 1회 재시도→
  invalid_grant면 needsReauth(큐 유지) / 429·5xx·네트워크→큐 유지, 다음 사이클 /
  기타 4xx→영구 실패, 드롭+로그.
- **temp id 재매핑**: insert 응답의 서버 id로 스냅샷+큐 내 모든 참조(parentID, previousID,
  listID, destinationListID) 재작성 — temp를 참조하는 후속 op가 실 id로 나감.
- **폴링 병합**: 90초(+톨러런스) + 앱 활성화 시(30초 초과 시). 서버 우선, 단 outbox에
  걸린 항목은 로컬 유지. 삭제 pending은 서버 사본 제외. 계정별 순차·격리.
- **디스크 캐시**: 스냅샷을 cache.json에 write-through → 오프라인 재실행 시 즉시 표시.
- **due 변환은 캘린더 컴포넌트로**: Google due = UTC 자정 고정. Date 포매터를 거치면
  UTC 동쪽 타임존(한국)에서 하루 밀림 → 양방향 모두 y/m/d 성분만 사용(`GoogleDates`).
- insert 시 `previous`=마지막 형제로 지정(API 기본은 맨 위 삽입, 우리 UI는 맨 아래 추가).

### 배선
- `TaskRepository`에 `onChange` 추가(비동기 변경 통지: 폴링 병합/플러시 완료/세션 상태).
  스토어 발 뮤테이션은 AppStore가 자체 reload하므로 onChange는 외부 변경 전용.
- `TaskOceanApp.makeRepository()`: clientID 설정 시 실백엔드, 미설정 시 목업,
  `TASKOCEAN_FORCE_MOCK=1`로 강제 목업(UI 개발용).

### 실계정 검증 대기 항목 (oauth_setup.md에도 기재)
- `completed` 쓰기 가능 여부(A70 문서 상충) · 부모 리스트 이동 시 서브태스크 서버측 추종
  여부(불명 — 자식 move op를 함께 보내되 404는 무해 드롭) · Testing 모드 7일 만료 배너 경로.

## A73. 용어: "서브태스크" → "하위 작업" (2026-07-16)
한국어 사용자 노출 문자열 전면 교체(`editor.subtasks`, `editor.addSubtask`).
영어("Subtasks")와 코드 식별자/주석/dev_note 과거 기록은 유지. 외래어 음차보다
자연스러운 우리말 용어 선호 — 이후 신규 문자열도 "하위 작업"으로 통일할 것.

## A74. Keychain 저장 무음 실패 — 재실행마다 재로그인 요구 (2026-07-16)
**증상:** 로그인 성공 → 앱 재실행 → 두 계정 모두 needsReauth. 캐시(태스크)는 살아있음.

**원인:** `kSecUseDataProtectionKeychain`(모던 keychain)은 **application-identifier
엔타이틀먼트 필요** — 프로비저닝된 빌드(App Store/TestFlight)에만 있고 개발 서명 Debug
빌드에는 없다(`codesign -d --entitlements`로 확인). SecItemAdd가 -34018
(errSecMissingEntitlement)로 거부됐는데 **save()가 상태 코드를 무시해 무음 실패**.
첫 세션은 토큰이 메모리에 있어 정상 동작 → 재실행 때만 증상 발현(-25300 not found).

**수정:** 모던 keychain 우선 시도 → -34018이면 레거시 파일 keychain 폴백.
읽기/삭제는 항상 양쪽 도메인 시도 → 개발↔App Store 트랙 이동에도 토큰 유지.
그 외 실패는 NSLog로 노출(무음 실패 금지).

**교훈:** 보안 API의 OSStatus를 버리지 말 것. "성공 경로에서 조용한" 코드는 실패도 조용하다.

## A75. 파괴적 작업 확인 다이얼로그 (2026-07-16, 사용자 요청)
- **태스크 삭제**(우클릭 메뉴): `store.pendingDeleteTaskID` 게이트 → RootView의 공용
  `confirmationDialog`. 세 사용처(확장 카드/지난 미완료/기한 없음)가 하나의 다이얼로그 공유.
- **에디터의 하위 작업 × 버튼**: 시트 위라 RootView 다이얼로그가 못 뜨므로 에디터 자체
  다이얼로그(로컬 `pendingSubDelete`).
- **계정 연결 해제**(설정): 로컬 데이터+로그인 정보 제거라 확인 필수. 메시지에 "Google
  서버의 데이터는 유지됩니다" 명시 — 사용자가 서버 삭제로 오해하지 않게.
- 리스트 삭제는 기존 확인(ListManagerView) 유지. `완료 정리`는 서버에서 hidden 처리
  (Google 웹에서 복구 가능)라 확인 없이 유지.

## A76. 재로그인 버튼 = 첫 로그인과 동일한 로더 (2026-07-16, 사용자 요청)
기존: `reauthNeeded`가 `.needsReauth`만 필터 → 버튼 클릭 즉시 `.refreshing`이 되며
**배너가 통째로 사라지고**, 취소하면 다시 튀어나옴. 수정: `reauthNeeded`를
`sessionState != .active`로 바꿔 OAuth 창이 떠 있는 동안 배너 유지, 버튼은
FirstRunView와 같은 스피너+"로그인 중…"(비활성) 상태로 전환. 성공(.active) 시에만 배너 퇴장.

**A74 검증 완료:** 재로그인 → 앱 강제종료 → 재실행에서 세션 자동 복원 + 폴링 데이터
반영 확인(레거시 keychain 폴백 경로). Debug 빌드 실사용 사이클 정상.


## A77. 창 수동 리사이즈 + 모드별 크기 기억 (2026-07-20, 사용자 요청)
"창 크기 수동 리사이즈도 가능하게 해줘 — 모든 모드에 대해."

**기존:** `.windowResizability(.contentSize)`가 창을 콘텐츠에 완전히 고정 → 리사이즈
핸들 무력. 높이는 PreferenceKey(StripHeightKey/DayListHeightKey)로 콘텐츠에 자동 추종.

**변경:**
- Scene: `.contentSize` → `.contentMinSize`. 콘텐츠는 **최소 크기**만 정하고 창은 자유
  리사이즈. `.defaultSize(460,640)`.
- RootView: 각 모드 뷰를 `.frame(minWidth/minHeight, maxWidth/maxHeight: .infinity,
  alignment: .top)`로 창을 채우게. 고정 폭(340/460) 제거.
- DayView/CompactStrip: 리스트 `.frame(height: 측정값)` → `.frame(maxHeight: .infinity)`.
  넘치면 스크롤. **자동 높이 추종 폐기** → StripHeightKey/DayListHeightKey 및 측정용
  GeometryReader 삭제. MiniStrip은 Spacer로 상단 고정 + 배경 채움.
- 모드별 크기 기억: SwiftUI 창 autosave는 **모드 무관 단일 프레임**이라 미니→재실행 시
  확장이 스트립 크기로 열리는 문제. 그래서 autosave에 의존하지 않고 `WindowConfigurator`가
  **모드별 프레임을 직접 UserDefaults(`taskocean.windowFrame.<mode>`)에 저장/복원**.
  리사이즈/이동 옵저버(didResize/didMove)가 현재 모드 키로 프레임 기록. 모드 전환 시:
  떠나는 모드 저장 → 들어오는 모드 크기를 **현재 top-left 유지한 채** 적용(없으면 기본값).
  첫 페인트만 위치까지 복원(재실행 시 마지막 자리).

**함정 2건(해결):**
1. **SwiftUI 초기 사이징이 내 `setFrame`을 덮어씀** — viewDidMoveToWindow의 동기 setFrame이
   SwiftUI 레이아웃 pass에 밀림. → 크기 적용을 `DispatchQueue.main.async`로 SwiftUI 이후 지연.
2. **옵저버가 SwiftUI 초기 크기를 사용자 드래그로 오인 저장** → 시드값 오염. → `suspendPersistence`
   플래그 **기본 true**로 시작, 첫 복원 완료 후에만 false. 프로그램적 리사이즈 중엔 저장 중단.

**검증:** 저장 키에 640×900 시드 → 재실행 시 640×900 위치까지 복원 + 저장키 무오염 확인.
full→compact(360×400)/full→mini(340×96) 전환 스냅 확인(env TASKOCEAN_MODE). 세 모드 모두
콘텐츠가 창을 채우고 푸터/힌트 하단 고정 확인. `.contentMinSize`라 각 모드 min 이하로는 안 줄어듦.

## A78. 실서버 검증: completed 쓰기 확정 (2026-07-20)
A70 문서 충돌("completed가 output-only인가?") 실계정 실측으로 해소.
- 완료: `PATCH .../tasks/{id}` body `{"status":"completed"}` → 200, 응답에
  `"status":"completed"` + 서버가 `"completed":"2026-07-20T03:16:12.488Z"` **자동 생성**.
- 해제: body `{"status":"needsAction","completed":null}` → 200, `"status":"needsAction"`.
- **결론:** 완료는 쓰기 가능한 `status`로 처리하고 타임스탬프는 서버가 채운다. 우리 코드가
  타임스탬프를 직접 쓰지 않으므로(§perform patchTask) 문서의 output-only 논란과 무관하게 정상.
  하위작업의 부모 리스트 이동은 코드가 자식까지 개별 moveTask로 명시 이동(서버 cascade 비의존)
  — 라이브 미구동(멀티스텝 UI 셋업 필요), 설계상 확정.

**검증 도구 메모:** cliclick 클릭은 좌표 보정만 맞으면 SwiftUI 컨트롤 발화됨(체크박스 토글 성공).
단 System Events keystroke/AXWindow 제어는 이 환경에서 권한 없음(-1719). 창 프레임은
CGWindowList(top-origin)와 cliclick 좌표계 일치.

## A79. 재검증 (2026-07-20): 완료 토글 1:1 확정, 3연속 PATCH는 아티팩트
사용자 "다시 검증" 요청으로 실계정 재실측.
- **1클릭 = 1 toggleComplete = 1 PATCH** 확정. UI는 mock으로 1클릭=1호출 확인(Checkbox는
  단일 Button, 이중 발화 없음), 실백엔드로 1토글=1PATCH 확인. `completed:{status:completed}`→
  200(서버가 타임스탬프 채움), 해제 `{status:needsAction,completed:null}`→200 재확인.
- 검증 중 관찰된 **1클릭→3 PATCH(완료↔미완료 오실레이션, ~1.3s 간격)는 실버그 아님**.
  완료 애니메이션으로 하단으로 **재정렬 중인 행**을 합성 클릭이 겹쳐 때린 테스트 아티팩트.
  안정된 행 클릭 시 항상 1:1. (교훈: 합성 클릭 검증은 애니메이션/재정렬 완료 후에.)
- **주의:** 검증용 합성 클릭이 실계정 태스크 상태를 여러 번 오변경 → 매번 원복 확인함.
  실데이터 대상 클릭 자동화는 좌표·애니메이션 리스크가 커서 최소화할 것.
- 하위작업 부모리스트 이동은 이번에도 라이브 미구동(부모+자식 각각 개별 moveTask 명시 이동,
  코드상 확정) — 실계정에 부모+자식 생성/이동/삭제가 필요해 실데이터 리스크로 보류.

## A80. 브랜드 웹용 데모 데이터·캡처 + 날짜 연도 표시 (2026-07-20, 사용자 요청)
브랜드(마케팅) 웹 제작을 위해 가계정 더미 데이터 화면 캡처 + 지침서 작성.
- **마케팅 데모 시드**: `MockTaskRepository.demoData()` (env `TASKOCEAN_DEMO=1`). 기본 mock 시드는
  디자인 목업 충실도용이라 건드리지 않고 별도. 2계정(업무 blue yeeun@studio.kr / 개인 tan
  yeeun.dev@gmail.com)·6리스트·오늘/지남/날짜없음 + 히트맵 밀도용 미래 날짜 태스크. 하위작업·메모·
  완료 포함. `TASKOCEAN_DEMO_REAUTH=1` 조합 시 개인 계정만 재인증 배너(격리 데모).
- **양 언어 캡처**: 영문은 `-AppleLanguages "(en)"` 실행 인자로 **프로세스 언어 자체**를 바꿔야
  날짜·`String(localized:)`·Text 전부 영어가 된다(앱 내 store.language 오버라이드/`\.locale`
  환경은 SwiftUI `Text`만 바꾸고 DateFormatter·String(localized:)는 시스템 locale 유지 —
  **알려진 i18n 한계**, 라이브 언어 전환도 날짜는 재시작 필요). demoData는 env 또는 en locale로
  영문 문자열 선택. 캡처 세트: `docs/screenshots/{ko,en}/01~09` (day-light/dark·compact·mini·
  reauth·subtasks·filter·search·heatmap).
- **날짜 헤더에 연도 추가**: `DayFormatter.headerTitle` 템플릿 `MMMd`→`yMMMd`
  ("2026년 7월 20일" / "Jul 20, 2026"). 전 언어·전 창모드 헤더 반영.
- 지침서: `docs/brand_web_guide.md` (팔레트 정확값·타이포·기능↔스크린샷 매핑·비목표·페이지 구성).

**캡처 도구 메모(보강):** 팝오버(필터·히트맵)는 `screencapture -l<popoverWinId>`가 **본창까지
합성**해 잡아줌(팝오버만 격리 안 됨) — 맥락 있는 컷으로 오히려 좋음. 단 첫 시도 실패("could not
create image") 잦으니 재시도. 완료 애니메이션으로 재정렬 중인 행 클릭은 피하기(A79). 한글은
IME로 타이핑 불가 → 검색어는 클립보드 `pbcopy` + ⌘V로 주입(라틴 "API"도 IME 우회 위해 붙여넣기).

## A81. i18n: 앱 내 언어 전환이 날짜·명령형 문자열까지 반영 (2026-07-20, 사용자 요청)
**문제(A80에서 기록):** 앱 내 언어 전환(설정)이 SwiftUI `Text("key")`(=`\.locale` 환경 따름)만
바꾸고, **명령형 `String(localized:)`와 `DateFormatter(Locale.current)`는 시스템 언어 유지** →
영어로 바꿔도 날짜 헤더("7월 20일")·"오늘" 칩·섹션 제목 등이 한글로 남음.

**해결:** 중앙 `AppLocale`(신규 `TaskOcean/Models/AppLocale.swift`) 도입.
- `AppLocale.current`(Locale, 선택 언어) + `AppLocale.bundle`(선택 `.lproj`) + `isKorean`.
  `AppStore.language` didSet + init에서 `AppLocale.apply(language)`.
- **명령형 문자열**: 실사용자 대상 `String(localized:"K",defaultValue:"V")` 전부 →
  `AppLocale.string("K","V")`(선택 `.lproj` 번들의 `localizedString(forKey:)`에서 해석).
  대상: CalendarSupport(badge.today/…)·RootView(today.header)·DayChrome(badge.today=그 "오늘"
  칩)·DayView(overdue/inbox 제목)·Chips·ListManagerView·NotificationScheduler. (Mock 시드 21개는
  dev/데모용이라 제외.)
- **DateFormatter**: 표시용 `df.locale = Locale.current` 전부 → `AppLocale.current`
  (CalendarSupport 5·HeatmapView 2·ComposePills·SearchViews·NaturalDateparser 표시부).
  NaturalDateParser의 키워드 파싱("내일"/"tomorrow")은 불변(입력 언어 기준).
- **라이브 리렌더**: `Text`는 `\.locale`로 갱신되지만 명령형/날짜는 스스로 무효화 안 됨 →
  RootView 콘텐츠와 MenuBarContent에 `.id(store.language)`로 언어 변경 시 서브트리 전체 rebuild
  (희귀 조작이라 상태 리셋 비용 허용). AppLocale.apply가 didSet에서 rebuild 전에 실행돼 일관됨.

**검증:** `-AppleLanguages` 없이 `store.language=.english`만으로 날짜("Jul 20, 2026" 연도 포함)·
"Today"·"Add a task"·"Overdue" 전부 영어 확인(예전엔 이 경로에서 한글 잔존). 즉 실사용자가 설정에서
영어로 바꾸면 재시작 없이 날짜까지 완전 영어. 반대(영→한)도 동일 경로.

## A82. 기본 캡처 단축키 ⌥Space → ⌘⇧Space (2026-07-20, 사용자 요청)
`HotKeyPreferences.capture` 기본값 `.optSpace` → `.cmdShiftSpace`(⇧⌘Space). 프리셋·표시
문자열은 이미 존재(한 줄 변경). 창 토글 기본은 `.optShiftSpace`(⌥⇧Space) 유지 — 충돌 없음.
사용자가 이미 커스텀 지정한 경우(UserDefaults `hotkey.capture` 존재) 영향 없음. 컴팩트 addHint·
설정 표기는 `HotKeyPreferences.capture.display` 동적이라 자동 반영. (design_reference/기존 문서의
⌥Space 표기는 이제 기본이 아님.)

## A83. 독 아이콘 재열기 시 새 창 생성 문제 (2026-07-20, 사용자 보고)
**증상:** 상단 독에서 앱 열기 → 기존 창으로 가지 않고 새 창이 열림.

**원인:** `WindowGroup(id:"main")`은 다중 창을 허용 → 독 재열기 / 메뉴바 `openWindow(id:"main")`가
매번 새 창 생성.

**수정:**
- 씬 `WindowGroup` → **`Window("TaskOcean", id: MainWindow.id)`** (단일 유니크 창, macOS 13+).
  독/`openWindow`가 항상 이 하나의 창을 포커스.
- `AppDelegate`(@NSApplicationDelegateAdaptor) `applicationShouldHandleReopen`: 보이는 창이
  없으면 `AppServices.showMainWindow()`로 기존(숨김) 창을 앞으로, 정말 없을 때만 AppKit 기본 재열기.
- 공유 식별자 `MainWindow.id = "taskocean.main"`. WindowConfigurator가 창에
  `NSWindow.identifier` 부여.
- **A77 부작용 동시 수정:** `toggleMainWindow()`가 `frameAutosaveName == "TaskOcean.main"`로
  창을 찾았는데 A77에서 per-mode 이름(`TaskOcean.full` 등)으로 바꿔 **못 찾던** 버그 → 이제
  `mainWindow()`가 `identifier == MainWindow.id`로 조회.

**검증:** 창 열린 상태에서 `open`(=독 재열기 이벤트) 반복 → 창 수 1 유지(중복 없음, 동일 id).
닫은 뒤 재열기도 1창. 실백엔드로도 정상.

## A84. CI 자동 릴리즈 + 공증 + Homebrew Cask 파이프라인 (2026-08-11)
**결정:** 태그(`vX.Y.Z`) 푸시로 Developer ID 서명·공증·DMG·GitHub Release·Homebrew Cask 갱신을
자동화. 트랙 B(직접 배포)의 자동화. 상세: `docs/ci_release.md`.

**임의 결정 사항:**
- **트랙 선택:** Homebrew Cask는 직접 다운로드 가능한 서명·공증 산출물이 필요 → App Store(트랙 A)가
  아닌 **Developer ID(트랙 B)** 를 자동화 대상으로 삼음. 두 트랙은 계속 공존.
- **배포 포맷 = DMG (`hdiutil UDZO` + `/Applications` 심볼릭 링크).** 헤드리스 러너에서 `create-dmg`의
  Finder 창 레이아웃 스크립팅은 불안정 → 장식 없는 견고한 DMG 채택(Homebrew는 외형 무관). DMG 자체도
  Developer ID로 서명해 공증 티켓을 staple.
- **탭 저장소 = `KingsFavor/homebrew-tap`**, 설치 경로 `kingsfavor/tap/taskocean`. Cask는 관례상
  별도 저장소. `release.yml`의 `update-homebrew-tap` job이 `TAP_GITHUB_TOKEN`으로 push.
  토큰 미설정 시 릴리즈는 성공, 탭 갱신만 스킵(비치명적).
- **공증 인증:** 앱암호 대신 **App Store Connect API 키(.p8)** 사용(notarytool 권장).
- **서명 방식:** pbxproj는 로컬용 Automatic 유지, CI만 `CODE_SIGN_STYLE=Manual` +
  `Developer ID Application` 오버라이드(로컬 개발 무영향).
- **공유 스킴 추가:** 헤드리스 CI에는 xcuserdata의 자동생성 스킴이 없으므로
  `xcshareddata/xcschemes/TaskOcean.xcscheme`를 커밋(신규 필수 파일).
- **버전 소스:** `MARKETING_VERSION`=태그, `CURRENT_PROJECT_VERSION`=GitHub run number(단조 증가).
- 엔타이틀먼트 변경 없음(배포 파이프라인 한정, 앱 런타임 권한 무관 — CLAUDE.md §4 준수).

**전제(사용자 수동 1회 설정):** GitHub Secrets 7종, `homebrew-tap` 저장소 생성, Developer ID
인증서/ASC API 키 발급. 절차 전부 `docs/ci_release.md` §1–4.

## A85. 공개 레포용 문서 구조 정리 (2026-08-12)
**결정:** 저장소가 public(`KingsFavor/Taskocean`)이 되면서 루트를 **사용자용**과 **개발용**으로 분리.
- 루트 **`README.md` 신설(사용자용)** — 소개·스크린샷·기능·요구사항·Homebrew 설치·현재 상태.
- 개발 문서 **`PRD.md`, `design_reference.html`을 `docs/`로 이동.** `docs/README.md` 인덱스 추가.
- `CLAUDE.md`는 루트 유지(에이전트/작업 지침 — 루트에 있어야 함). 내부 경로 참조를 `docs/PRD.md`,
  `docs/design_reference.html`로 갱신. `docs/brand_web_guide.md` 출처 표기도 동기화.

**정직성 주의:** 현 빌드는 목업 데이터로 동작(실 Google 연동 개발 중, A_실백엔드 단계)이므로 README에
"프리뷰 — 샘플 데이터" 상태를 명시. 실제보다 부풀린 주장 금지.

## A86. 인앱 업데이트 안내 (조용한 방식) (2026-08-12, 사용자 요청)
**요청:** 앱 업데이트 시 인앱 안내. **제약: "절대 UX를 해치지 마."**

**설계 (사용자 선택: 얇은 닫기형 배너 + 설정):**
- **`UpdateChecker`**(`System/UpdateChecker.swift`, `@MainActor @Observable`) — 공개 GitHub Releases
  API(`/releases/latest`)로 최신 태그 조회 → 현재 `CFBundleShortVersionString`과 숫자 버전 비교.
- **비방해 원칙:**
  - 아웃바운드 HTTPS만(App Sandbox `network.client`, 서버 엔타이틀먼트 없음 — CLAUDE.md §4 준수).
  - **하루 1회**, 실행 시에만 확인(폴링 타이머 없음 — 경량성). `UserDefaults` 스로틀.
  - 네트워크 실패는 **무음**(에러 UI 없음). 결과를 캐시 → 재실행 시 네트워크 없이 배너 복원,
    실행 버전이 따라잡으면 자동 소멸.
  - 모달·포커스 뺏기 **없음**. 배너 ✕ = 해당 버전 **건너뛰기**(다시 안 뜸).
- **표면 2곳:**
  - **얇은 배너**(`UpdateBanner`, RootView) — 새 버전 있을 때만 확장(full) 뷰 상단에 1줄. 미니/컴팩트는
    의도적으로 미표시(글랜스 모드 최소주의). 라벨 클릭=릴리스 페이지, hover=brew 명령 툴팁.
  - **설정 › 일반 › 업데이트** — 현재 버전, 자동확인 토글, "지금 확인", 상태, 릴리스 열기.
- 배포가 Homebrew Cask라 **자가 업데이트 안 함**(Sparkle 미도입, §8.6). 안내=릴리스 링크 + `brew upgrade`.
- 로컬라이제이션 `update.*` 11키(한/영) 추가. README에 "업데이트" 섹션 추가.
- 엔타이틀먼트 변경 없음.

**후속(2026-08-12):** 메뉴바 드롭다운에도 조용한 업데이트 줄 추가(미니/컴팩트 사용자용, 새 버전 있을 때만).

**후속 — 사용자 주도 수동 확인:** 앱 메뉴 **"업데이트 확인…"**(`CommandGroup(after: .appInfo)`, About 아래
= macOS 표준 위치) 추가. `checkForUpdatesInteractive()`. **UX 원칙 재확인:** 자동(무청유) 확인은 계속 무음이지만,
**사용자가 직접 누른** 수동 확인은 결과 피드백(작은 `NSAlert`: 최신/새 버전+brew 명령·릴리스 열기/확인 실패)을
주는 것이 오히려 좋은 UX — 클릭에 아무 반응 없는 게 더 나쁨. 모달은 사용자 요청에 대한 응답일 때만 사용.
설정 › 일반의 인라인 "지금 확인"(무모달)은 그대로 유지. 키 `cmd.checkUpdates`, `action.ok`, `update.alert.*` 추가.

## A87. 개발 빌드 vs 배포판 구분 표시 (2026-08-12, 사용자 요청)
**문제:** Homebrew 배포판(Release·공증·/Applications)과 Xcode 개발 빌드(Debug)가 같은 번들 ID·이름·아이콘 →
동시에 실행 시 어느 게 도는지 구분 불가.

**해결 (`System/BuildInfo.swift`):** `isDevelopment` = `#if DEBUG`(개발 빌드에만 정의, Release는 미정의) 또는
Release여도 `/Applications/` 밖에서 실행 시 true. 배포판만 false.
- **개발 빌드에만 "DEV" 배지**(`DevBadge`, 앰버색 캡슐, hover 시 번들 경로 표시)를 창 크롬(확장)·미니·컴팩트
  헤더·메뉴바 드롭다운 헤더에 표시. **배포판은 아무 표식 없음 → 엔드유저 무영향.**
- **메뉴바 글리프**: 개발=`fish.fill`(채움), 배포=`fish`(외곽선) → 두 메뉴바 아이콘을 클릭 없이 구분.
- **설정 › 일반**: 버전 `(빌드번호)` + DEV 배지, 채널 라인(개발/로컬 Release/배포판(Homebrew)).
- 키 `build.channel*` 4개 추가. 엔타이틀먼트 변경 없음.

**주의:** 배지는 재빌드/재설치 후 나타남. 개발 copy를 Xcode에서 다시 실행하면 즉시 DEV 표시 → Homebrew copy와
구분됨(배포판은 원래 배지 없음). Homebrew copy의 "배포판" 채널 라인까지 반영하려면 다음 릴리스 설치 필요.

## A88. 수동 업데이트 확인 피드백 + 명령어 복사 (2026-08-12, 사용자 요청)
앱 메뉴 "업데이트 확인…"(A86, macOS 표준 = 첫 메뉴 About 아래)의 결과 피드백 강화:
- **결과 알림**(사용자 주도 시에만): 최신=버전 표시, 새 버전=`현재 → 신규` + brew 명령, 실패=안내.
  새 버전 알림 버튼: **[명령어 복사](기본)** / [릴리스 열기] / [나중에].
- **복사 명령어에 `brew update` 포함** → `brew update && brew upgrade --cask taskocean`
  (`brew update` 없이는 Homebrew가 새 cask 버전을 모름). 상수 `brewUpgradeCommand`→`brewUpdateCommand`로 개명.
- 복사 창구: 알림 버튼 + 설정 › 일반(새 버전 시 [명령어 복사]) + 배너(복사 아이콘·우클릭) + 메뉴바 줄(우클릭).
- 키 `update.copyCommand` 추가. README 업데이트 섹션에 메뉴·복사 안내 반영.

## A89. Homebrew 업데이트 후 자동 재시작 (2026-08-12, 사용자 요청)
**배경:** `brew upgrade`가 디스크 번들만 교체 → 실행 중 프로세스는 구버전 유지. 사용자가 "실행 중 자동
재시작 OK"라고 함.

**구현 (`System/UpdateRelauncher.swift`, `AppServices.start()`에서 기동):**
- **감지:** `NSApplication.didBecomeActiveNotification`(폴링 없음 — 경량성) 시, **디스크의 Info.plist**에서
  `CFBundleShortVersionString`을 직접 읽어(= Bundle.main 캐시 우회) 실행 버전보다 높으면 업데이트로 판단.
- **재시작:** `NSWorkspace.openApplication`(새 인스턴스) **성공 시에만** `NSApp.terminate` → 샌드박스 안전,
  실패 시 무해(구 copy 유지, 수동 재시작). 엔타이틀먼트 추가 없음.
- **개발 빌드 제외**(`BuildInfo.isDevelopment`): Xcode 재빌드가 번들을 바꿔 무한 self-relaunch 방지 — 필수 게이트.

**한계(정직):** Homebrew가 업그레이드 중 앱을 **종료시키면** 이 로직은 실행 안 됨(프로세스 사망) → 사용자가 다시
열면 신버전. 즉 이 자동 재시작은 "앱이 살아있는 채로 번들만 교체된 경우"의 보완. 샌드박스 실제 동작은 배포 빌드
실기기 검증 필요(빌드 그린은 확인).

## A90. 문서 오류 정정 — "목업" 아님, 실백엔드 기본 (2026-08-12, 사용자 지적)
**오류:** README에 "프리뷰 — 샘플(목업) 데이터"라고 적었으나 **사실과 다름**. 코드 재분석 결과:
- `GoogleOAuthConfig.clientID`가 **첫 커밋(f6d1def)부터 설정**됨 → `isConfigured == true` →
  `makeRepository()`가 항상 `GoogleTasksRepository`(실백엔드) 반환. 엔드유저 빌드는 목업이 아님.
- `Sync/` 전체 실제 구현(OAuth PKCE, 토큰 키체인 격리, Tasks REST CRUD/move/clear, outbox+폴링 병합).
  스텁/`fatalError` 없음. FirstRunView "계정 연결" → 실제 `signIn()`.
- 원인: CLAUDE.md §5의 "목업 데이터/다음=실백엔드" 낡은 서술을 **검증 없이** README로 옮김.

**정정:** README "현재 상태—프리뷰" 삭제 → "Google 계정 연동"(실 Google Tasks·OAuth·키체인, 검증 전
테스트 사용자 한정·7일 만료 caveat). CLAUDE.md §5·`TaskRepository.swift` 주석도 실상태로 갱신.
**교훈:** 상태 주장은 문서(특히 오래된 CLAUDE.md 상태 섹션)가 아니라 **코드에서 검증**한다.

**저장소 위생:** 추적되던 `.DS_Store` 3개(`.`, `docs/`, `docs/screenshots/`) `git rm --cached`로 추적 해제
(.gitignore엔 이미 존재).
