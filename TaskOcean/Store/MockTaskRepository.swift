import Foundation

/// In-memory repository seeded with the exact sample data from the design mockups.
/// Applies every mutation immediately (no network). Interface-identical to a future
/// `GoogleTasksRepository`, so views never learn they're talking to a mock.
@MainActor
final class MockTaskRepository: TaskRepository {
    private var _accounts: [Account]
    private var _lists: [TaskList]
    private var _tasks: [TaskItem]
    private var counter = 0

    init() {
        // Dev-only: start with no accounts to exercise the first-run screen.
        if ProcessInfo.processInfo.environment["TASKOCEAN_EMPTY"] == "1" {
            _accounts = []; _lists = []; _tasks = []
            return
        }
        // Marketing/demo dataset (richer, curated) for brand-site captures.
        // TASKOCEAN_DEMO=1 ; combine with TASKOCEAN_DEMO_REAUTH=1 for the banner shot.
        if ProcessInfo.processInfo.environment["TASKOCEAN_DEMO"] == "1" {
            (_accounts, _lists, _tasks) = Self.demoData()
            return
        }
        let cal = CalendarSupport.calendar
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        // Accounts (design: J = Work/blue, P = Personal/tan) ------------------
        // Dev-only: TASKOCEAN_DEMO_REAUTH=1 puts the work account in the
        // "re-login needed" state to exercise the §8.7 isolation UI.
        let demoReauth = ProcessInfo.processInfo.environment["TASKOCEAN_DEMO_REAUTH"] == "1"
        var work = Account(id: "acc-work", displayName: String(localized: "seed.account.work", defaultValue: "Work"),
                           email: "jun@company.com", kind: .workspace, colorSeed: .blue)
        if demoReauth { work.sessionState = .needsReauth }
        let personal = Account(id: "acc-personal", displayName: String(localized: "seed.account.personal", defaultValue: "Personal"),
                               email: "me@gmail.com", kind: .personal, colorSeed: .tan)
        _accounts = [work, personal]

        // Lists ----------------------------------------------------------------
        _lists = [
            TaskList(id: "l-work", accountID: work.id, title: String(localized: "seed.list.work", defaultValue: "Work")),
            TaskList(id: "l-design", accountID: work.id, title: String(localized: "seed.list.design", defaultValue: "Design")),
            TaskList(id: "l-grocery", accountID: personal.id, title: String(localized: "seed.list.grocery", defaultValue: "Groceries")),
            TaskList(id: "l-later", accountID: personal.id, title: String(localized: "seed.list.later", defaultValue: "Later")),
        ]

        // Tasks (matches Section 01 / 04 of the design) -----------------------
        var t: [TaskItem] = []

        // Today · Work · has 3 subtasks (2 done)
        var prd = TaskItem(id: "t-prd", accountID: work.id, listID: "l-work",
                           title: String(localized: "seed.task.prd", defaultValue: "Sort out PRD v0.3 review comments"),
                           notes: String(localized: "seed.task.prd.notes", defaultValue: "Collect §6 day-view feedback"),
                           due: today, position: "00000000000000000001")
        t.append(prd)
        t.append(TaskItem(id: "t-prd-s1", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.sub.requirements", defaultValue: "Organize requirements list"),
                          due: today, isCompleted: true, completedAt: today,
                          position: "00000000000000000001", parentID: "t-prd"))
        t.append(TaskItem(id: "t-prd-s2", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.sub.reviewComments", defaultValue: "Aggregate review comments"),
                          due: today, isCompleted: true, completedAt: today,
                          position: "00000000000000000002", parentID: "t-prd"))
        t.append(TaskItem(id: "t-prd-s3", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.sub.rereview", defaultValue: "Request re-review after changes"),
                          due: today, position: "00000000000000000003", parentID: "t-prd"))
        _ = prd

        // Today · Work · Design list
        t.append(TaskItem(id: "t-share", accountID: work.id, listID: "l-design",
                          title: String(localized: "seed.task.share", defaultValue: "Share design mockups with the team"),
                          due: today, position: "00000000000000000002"))
        // Today · Personal
        t.append(TaskItem(id: "t-grocery", accountID: personal.id, listID: "l-grocery",
                          title: String(localized: "seed.task.grocery", defaultValue: "Grocery run — milk, coffee beans"),
                          due: today, position: "00000000000000000001"))
        // Today · Personal · completed
        t.append(TaskItem(id: "t-gym", accountID: personal.id, listID: "l-later",
                          title: String(localized: "seed.task.gym", defaultValue: "Sign up for the gym"),
                          due: today, isCompleted: true, completedAt: today,
                          position: "00000000000000000002"))

        // Overdue (non-destructive; original due kept) — Section 04
        t.append(TaskItem(id: "t-invoice", accountID: personal.id, listID: "l-later",
                          title: String(localized: "seed.task.invoice", defaultValue: "Submit invoice"),
                          due: day(-4), position: "00000000000000000001"))
        t.append(TaskItem(id: "t-scope", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.task.scope", defaultValue: "Kick off API scope verification"),
                          due: day(-1), position: "00000000000000000003"))

        // Inbox (no due) — always visible
        t.append(TaskItem(id: "t-sparkle", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.task.sparkle", defaultValue: "Research Sparkle auto-update"),
                          due: nil, position: "00000000000000000004"))
        t.append(TaskItem(id: "t-library", accountID: personal.id, listID: "l-later",
                          title: String(localized: "seed.task.library", defaultValue: "Return library books"),
                          due: nil, position: "00000000000000000003"))
        t.append(TaskItem(id: "t-expense", accountID: work.id, listID: "l-work",
                          title: String(localized: "seed.task.expense", defaultValue: "Scan expense receipts"),
                          due: nil, position: "00000000000000000005"))

        _tasks = t
    }

    /// Curated marketing dataset — a busy day across a Work (blue) and Personal
    /// (tan) Google account. Rich enough to show every surface: subtasks + progress,
    /// notes, overdue/today/inbox, a populated heatmap (future-dated tasks), and
    /// multi-account grouping. Demo-only, so strings are inline (not localized).
    private static func demoData() -> ([Account], [TaskList], [TaskItem]) {
        let cal = CalendarSupport.calendar
        let today = cal.startOfDay(for: Date())
        func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: o, to: today)! }
        // Bilingual captures: English when forced via env or the app locale is en
        // (e.g. launched with -AppleLanguages "(en)").
        let en = ProcessInfo.processInfo.environment["TASKOCEAN_LANG"] == "en"
            || Locale.current.language.languageCode?.identifier == "en"
        func L(_ ko: String, _ eng: String) -> String { en ? eng : ko }

        var personal = Account(id: "d-personal", displayName: L("개인", "Personal"),
                               email: "yeeun.dev@gmail.com", kind: .personal, colorSeed: .tan)
        let work = Account(id: "d-work", displayName: L("업무", "Work"),
                           email: "yeeun@studio.kr", kind: .workspace, colorSeed: .blue)
        // Combine with TASKOCEAN_DEMO_REAUTH=1 for the non-blocking re-login banner.
        if ProcessInfo.processInfo.environment["TASKOCEAN_DEMO_REAUTH"] == "1" {
            personal.sessionState = .needsReauth
        }
        let accounts = [work, personal]

        let lists = [
            TaskList(id: "d-l-product", accountID: work.id, title: L("제품", "Product")),
            TaskList(id: "d-l-design",  accountID: work.id, title: L("디자인", "Design")),
            TaskList(id: "d-l-mkt",     accountID: work.id, title: L("마케팅", "Marketing")),
            TaskList(id: "d-l-home",    accountID: personal.id, title: L("집안일", "Home")),
            TaskList(id: "d-l-grocery", accountID: personal.id, title: L("장보기", "Groceries")),
            TaskList(id: "d-l-read",    accountID: personal.id, title: L("읽을거리", "Reading")),
        ]

        var t: [TaskItem] = []
        var pos = 0
        func add(_ id: String, _ acc: String, _ list: String, _ title: String,
                 notes: String? = nil, due: Date? = nil, done: Bool = false, parent: String? = nil) {
            pos += 1
            t.append(TaskItem(id: id, accountID: acc, listID: list, title: title, notes: notes,
                              due: due, isCompleted: done, completedAt: done ? day(0) : nil,
                              position: String(format: "%020d", pos), parentID: parent))
        }

        // Today — Work
        add("d-rel", work.id, "d-l-product", L("v1.2 릴리스 노트 작성", "Write v1.2 release notes"),
            notes: L("App Store 심사 제출 전까지", "Before App Store submission"), due: today)
        add("d-rel-s1", work.id, "d-l-product", L("변경사항 취합", "Collect the changelog"), due: today, done: true, parent: "d-rel")
        add("d-rel-s2", work.id, "d-l-product", L("스크린샷 6장 교체", "Swap in 6 screenshots"), due: today, done: true, parent: "d-rel")
        add("d-rel-s3", work.id, "d-l-product", L("블로그 초안 발행", "Publish the blog draft"), due: today, parent: "d-rel")
        add("d-onb", work.id, "d-l-design", L("온보딩 3단계 시안 공유", "Share 3-step onboarding mockups"),
            notes: L("#design 채널에 공유", "Post in #design"), due: today)
        add("d-api", work.id, "d-l-product", L("API 사용량 대시보드 점검", "Check the API usage dashboard"), due: today)
        add("d-copy", work.id, "d-l-mkt", L("랜딩 히어로 카피 A/B 정리", "Sort landing hero copy A/B"), due: today)
        // Today — Personal
        add("d-groc", personal.id, "d-l-grocery", L("장보기 — 우유, 달걀, 커피 원두", "Groceries — milk, eggs, coffee beans"), due: today)
        add("d-laundry", personal.id, "d-l-home", L("세탁물 찾아오기", "Pick up the laundry"), due: today, done: true)
        add("d-dog", personal.id, "d-l-home", L("강아지 사료 주문", "Order dog food"), due: today, done: true)

        // Overdue (kept at original past date; collapses by default in the day view)
        add("d-beta", work.id, "d-l-product", L("베타 피드백 이슈 분류", "Triage beta feedback"), due: day(-2))
        add("d-news", work.id, "d-l-mkt", L("7월 뉴스레터 발송", "Send the July newsletter"), due: day(-1))
        add("d-bill", personal.id, "d-l-home", L("관리비 납부", "Pay the utility bill"), due: day(-3))

        // Inbox (no due) — always visible
        add("d-comp", work.id, "d-l-product", L("경쟁 앱 3종 리서치", "Research 3 competitor apps"))
        add("d-icon", work.id, "d-l-design", L("앱 아이콘 라운드 검토", "Review the app icon round"))
        add("d-book", personal.id, "d-l-read", L("빌린 책 반납", "Return borrowed books"))
        add("d-subs", personal.id, "d-l-read", L("구독 뉴스레터 정리", "Clean up newsletter subs"))

        // Future-dated — populate the heatmap without cluttering today's view.
        let future: [(Int, String, String, String)] = [
            (1, work.id, "d-l-product", L("스프린트 회고 준비", "Prep sprint retro")),
            (1, personal.id, "d-l-grocery", L("주말 장보기 목록", "Weekend grocery list")),
            (2, work.id, "d-l-mkt", L("인스타 릴스 편집", "Edit an Instagram reel")),
            (3, work.id, "d-l-product", L("v1.3 킥오프 미팅", "v1.3 kickoff meeting")),
            (3, work.id, "d-l-design", L("다크 모드 QA", "Dark mode QA")),
            (3, personal.id, "d-l-home", L("화분 분갈이", "Repot the plants")),
            (4, work.id, "d-l-product", L("주간 지표 리포트", "Weekly metrics report")),
            (5, personal.id, "d-l-read", L("독서 모임 5장", "Book club, chapter 5")),
            (5, work.id, "d-l-mkt", L("블로그 발행", "Publish a blog post")),
            (7, work.id, "d-l-product", L("릴리스 회고", "Release retro")),
            (7, work.id, "d-l-design", L("아이콘 세트 2차", "Icon set v2")),
            (7, personal.id, "d-l-grocery", L("생필품 보충", "Restock essentials")),
            (7, work.id, "d-l-mkt", L("월간 리캡 작성", "Write the monthly recap")),
            (9, work.id, "d-l-product", L("성능 프로파일링", "Profile performance")),
            (9, personal.id, "d-l-home", L("정기 점검 예약", "Book a maintenance visit")),
            (11, work.id, "d-l-design", L("브랜드 가이드 업데이트", "Update the brand guide")),
            (11, work.id, "d-l-product", L("고객 인터뷰 3건", "3 customer interviews")),
            (-5, work.id, "d-l-product", L("지난주 배포 정리", "Wrap last week's release")),
            (-5, work.id, "d-l-mkt", L("광고 소재 검수", "Review ad creatives")),
        ]
        for (i, f) in future.enumerated() { add("d-f\(i)", f.1, f.2, f.3, due: day(f.0)) }

        return (accounts, lists, t)
    }

    var onChange: (() -> Void)?   // never fires — the mock has no async source

    // MARK: Snapshot
    func accounts() -> [Account] { _accounts }
    func lists() -> [TaskList] { _lists }
    func tasks() -> [TaskItem] { _tasks }

    // MARK: Account lifecycle
    func addAccount() async {
        let idx = _accounts.count
        let acc = Account(id: "acc-\(UUID().uuidString.prefix(6))",
                          displayName: String(localized: "seed.account.new", defaultValue: "New account"),
                          email: "new\(idx)@gmail.com", kind: .personal,
                          colorSeed: AccountColor.seed(forIndex: idx))
        _accounts.append(acc)
        _lists.append(TaskList(id: "l-\(acc.id)", accountID: acc.id,
                               title: String(localized: "seed.list.tasks", defaultValue: "My Tasks")))
    }

    func removeAccount(_ id: String) {
        _accounts.removeAll { $0.id == id }
        _lists.removeAll { $0.accountID == id }
        _tasks.removeAll { $0.accountID == id }
    }

    func reauthenticate(_ accountID: String) async {
        setSession(accountID, .refreshing)
        try? await Task.sleep(nanoseconds: 700_000_000)
        setSession(accountID, .active)
    }

    private func setSession(_ accountID: String, _ state: Account.SessionState) {
        guard let i = _accounts.firstIndex(where: { $0.id == accountID }) else { return }
        _accounts[i].sessionState = state
    }

    // MARK: Task mutations
    @discardableResult
    func addTask(title: String, listID: String, due: Date?, notes: String?, parentID: String?) -> TaskItem {
        counter += 1
        let accountID = _lists.first { $0.id == listID }?.accountID ?? _accounts.first?.id ?? ""
        let item = TaskItem(id: "new-\(counter)-\(UUID().uuidString.prefix(4))",
                            accountID: accountID, listID: listID,
                            title: title, notes: notes, due: due.map(CalendarSupport.startOfDay),
                            position: String(format: "%020d", 9_000_000 + counter),
                            parentID: parentID, syncState: .synced)
        _tasks.append(item)
        return item
    }

    func updateTask(_ task: TaskItem) {
        guard let i = _tasks.firstIndex(where: { $0.id == task.id }) else { return }
        _tasks[i] = task
    }

    func toggleComplete(_ id: String) {
        guard let i = _tasks.firstIndex(where: { $0.id == id }) else { return }
        _tasks[i].isCompleted.toggle()
        _tasks[i].completedAt = _tasks[i].isCompleted ? Date() : nil
        // Toggling a parent cascades to subtasks (mirrors typical UX).
        if _tasks[i].parentID == nil {
            let done = _tasks[i].isCompleted
            for j in _tasks.indices where _tasks[j].parentID == id {
                _tasks[j].isCompleted = done
                _tasks[j].completedAt = done ? Date() : nil
            }
        }
    }

    func deleteTask(_ id: String) {
        _tasks.removeAll { $0.id == id || $0.parentID == id }
    }

    func moveToToday(_ id: String) {
        guard let i = _tasks.firstIndex(where: { $0.id == id }) else { return }
        _tasks[i].due = CalendarSupport.startOfDay(Date())
    }

    func reorder(_ id: String, after previousID: String?, in listID: String) {
        // Mirrors tasks.move(previous:): rewrite `position` so the sort sticks.
        guard let movingIdx = _tasks.firstIndex(where: { $0.id == id }) else { return }
        let parentID = _tasks[movingIdx].parentID
        // Cross-list drag also moves the task into the target list.
        _tasks[movingIdx].listID = listID

        // Current siblings in the target list at the same nesting level, ordered.
        var group = _tasks
            .filter { $0.listID == listID && $0.parentID == parentID }
            .sorted { $0.position < $1.position }
        group.removeAll { $0.id == id }

        let insertAt: Int
        if let previousID, let p = group.firstIndex(where: { $0.id == previousID }) {
            insertAt = p + 1
        } else {
            insertAt = 0   // nil previous → move to top
        }
        group.insert(_tasks[movingIdx], at: insertAt)

        // Reassign dense, sortable positions.
        for (i, t) in group.enumerated() {
            if let idx = _tasks.firstIndex(where: { $0.id == t.id }) {
                _tasks[idx].position = String(format: "%020d", i)
            }
        }
    }

    // MARK: List CRUD
    @discardableResult
    func addList(accountID: String, title: String) -> TaskList {
        counter += 1
        let list = TaskList(id: "l-new-\(counter)", accountID: accountID, title: title)
        _lists.append(list)
        return list
    }

    func renameList(_ listID: String, title: String) {
        guard let i = _lists.firstIndex(where: { $0.id == listID }) else { return }
        _lists[i].title = title
    }

    func deleteList(_ listID: String) {
        _lists.removeAll { $0.id == listID }
        _tasks.removeAll { $0.listID == listID }
    }

    func clearCompleted(listID: String) {
        // tasks.clear semantics: completed tasks in the list are cleared.
        _tasks.removeAll { $0.listID == listID && $0.isCompleted }
    }

    @discardableResult
    func moveTaskToAccount(_ taskID: String, targetListID: String) -> String? {
        guard let task = _tasks.first(where: { $0.id == taskID }),
              let targetList = _lists.first(where: { $0.id == targetListID }),
              targetList.accountID != task.accountID else { return nil }
        // Recreate top-level task in the target account (PRD §8.4.5)…
        let newTask = addTask(title: task.title, listID: targetListID,
                              due: task.due, notes: task.notes, parentID: nil)
        // …recreate its subtasks…
        for sub in _tasks.filter({ $0.parentID == taskID }) {
            _ = addTask(title: sub.title, listID: targetListID,
                        due: sub.due, notes: sub.notes, parentID: newTask.id)
        }
        // …then delete the original (with subtasks).
        deleteTask(taskID)
        return newTask.id
    }

    // MARK: Visibility filters
    func setListVisible(_ listID: String, _ visible: Bool) {
        guard let i = _lists.firstIndex(where: { $0.id == listID }) else { return }
        _lists[i].isVisible = visible
    }

    func setAccountVisible(_ accountID: String, _ visible: Bool) {
        for i in _lists.indices where _lists[i].accountID == accountID {
            _lists[i].isVisible = visible
        }
    }

    // MARK: Sync
    func refresh() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
}
