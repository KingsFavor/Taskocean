import Foundation

// MARK: - Wire models (Google Tasks API v1)

struct GTaskList: Decodable {
    let id: String
    var title: String?
}

struct GTask: Decodable {
    let id: String
    var title: String?
    var notes: String?
    var status: String?      // "needsAction" | "completed"
    var due: String?         // RFC 3339, date part only is meaningful (§8.4.1)
    var completed: String?   // RFC 3339 completion timestamp
    var parent: String?
    var position: String?    // lexicographic sibling order
    var deleted: Bool?
    var hidden: Bool?        // completed + cleared
}

enum APIError: Error {
    case unauthorized            // 401 → refresh token and retry once
    case transient(Int)          // 429 / 5xx / network → keep op queued, retry later
    case permanent(Int, String)  // other 4xx → op can never succeed, drop it
}

// MARK: - REST client

/// Thin, stateless REST client for one request burst. Created per call with a
/// fresh access token (the session layer owns refresh), so it never holds a
/// token long enough for it to expire.
struct GoogleTasksAPI {
    let accessToken: String
    private static let base = URL(string: "https://tasks.googleapis.com/tasks/v1")!

    // MARK: Task lists

    func taskLists() async throws -> [GTaskList] {
        try await pages(path: "users/@me/lists", query: [:])
    }

    func insertTaskList(title: String) async throws -> GTaskList {
        try await request("POST", "users/@me/lists", body: ["title": title])
    }

    func patchTaskList(_ listID: String, title: String) async throws {
        let _: GTaskList = try await request("PATCH", "users/@me/lists/\(listID)",
                                             body: ["title": title])
    }

    func deleteTaskList(_ listID: String) async throws {
        try await requestVoid("DELETE", "users/@me/lists/\(listID)")
    }

    // MARK: Tasks

    func tasks(in listID: String) async throws -> [GTask] {
        // showHidden=false: tasks cleared via "완료 정리" stay gone, matching the
        // mock's clearCompleted semantics and keeping payloads small.
        try await pages(path: "lists/\(listID)/tasks",
                        query: ["showCompleted": "true", "maxResults": "100"])
    }

    /// `body` values use NSNull to explicitly clear a field (e.g. remove due).
    func insertTask(listID: String, body: [String: Any],
                    parent: String?, previous: String?) async throws -> GTask {
        var query: [String: String] = [:]
        query["parent"] = parent
        query["previous"] = previous
        return try await request("POST", "lists/\(listID)/tasks", query: query, body: body)
    }

    func patchTask(listID: String, taskID: String, body: [String: Any]) async throws -> GTask {
        try await request("PATCH", "lists/\(listID)/tasks/\(taskID)", body: body)
    }

    func deleteTask(listID: String, taskID: String) async throws {
        try await requestVoid("DELETE", "lists/\(listID)/tasks/\(taskID)")
    }

    /// Reorder / reparent / move across lists (same account only, §8.4.5).
    func moveTask(listID: String, taskID: String,
                  parent: String? = nil, previous: String? = nil,
                  destinationList: String? = nil) async throws -> GTask {
        var query: [String: String] = [:]
        query["parent"] = parent
        query["previous"] = previous
        query["destinationTasklist"] = destinationList
        return try await request("POST", "lists/\(listID)/tasks/\(taskID)/move", query: query)
    }

    func clearCompleted(listID: String) async throws {
        try await requestVoid("POST", "lists/\(listID)/clear")
    }

    // MARK: Plumbing

    private struct Page<T: Decodable>: Decodable {
        var items: [T]?
        var nextPageToken: String?
    }

    private func pages<T: Decodable>(path: String, query: [String: String]) async throws -> [T] {
        var all: [T] = []
        var pageToken: String?
        repeat {
            var q = query
            q["pageToken"] = pageToken
            let page: Page<T> = try await request("GET", path, query: q)
            all.append(contentsOf: page.items ?? [])
            pageToken = page.nextPageToken
        } while pageToken != nil
        return all
    }

    private func makeRequest(_ method: String, _ path: String,
                             query: [String: String], body: [String: Any]?) throws -> URLRequest {
        var comps = URLComponents(url: Self.base.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transient(0)   // network failure — retry later
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299: return data
        case 401: throw APIError.unauthorized
        case 429, 500...599: throw APIError.transient(status)
        default: throw APIError.permanent(status, String(data: data, encoding: .utf8) ?? "")
        }
    }

    private func request<T: Decodable>(_ method: String, _ path: String,
                                       query: [String: String] = [:],
                                       body: [String: Any]? = nil) async throws -> T {
        let data = try await perform(try makeRequest(method, path, query: query, body: body))
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.permanent(200, "decode: \(error)") }
    }

    private func requestVoid(_ method: String, _ path: String,
                             query: [String: String] = [:],
                             body: [String: Any]? = nil) async throws {
        _ = try await perform(try makeRequest(method, path, query: query, body: body))
    }
}

// MARK: - Date conversions

/// Google stores `due` as a date-only value inside an RFC 3339 UTC-midnight
/// timestamp. Converting through `Date` + formatters shifts the day for any
/// timezone east of UTC, so both directions work on **calendar components**:
/// the wire date 2026-07-16 means local 2026-07-16, whatever the timezone.
enum GoogleDates {
    static func dueString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02dT00:00:00.000Z", c.year!, c.month!, c.day!)
    }

    static func dueDate(from string: String) -> Date? {
        guard string.count >= 10,
              let y = Int(string.prefix(4)),
              let m = Int(string.dropFirst(5).prefix(2)),
              let d = Int(string.dropFirst(8).prefix(2)) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
            .map(CalendarSupport.startOfDay)
    }

    /// `completed` is a real timestamp (fractional seconds vary by writer).
    static func timestamp(from string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        return plain.date(from: string)
    }
}
