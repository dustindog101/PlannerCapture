import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case inbox
    case todo
    case inProgress = "in_progress"
    case blocked
    case done
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inbox: return "Waiting"
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .blocked: return "Blocked"
        case .done: return "Done"
        case .archived: return "Archived"
        }
    }

    static var creatableDefaults: [TaskStatus] {
        [.inbox, .todo, .inProgress, .blocked]
    }
}

struct PlannerTask: Identifiable, Equatable, Decodable {
    let id: String
    var title: String
    var notes: String
    var status: TaskStatus
    var priority: Int
    var isStarred: Bool
    var source: String
    var groupId: String?
    var dueAt: Int?
    var updatedAt: Int

    var isDone: Bool {
        status == .done || status == .archived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case status
        case priority
        case isStarred = "is_starred"
        case source
        case groupId = "group_id"
        case dueAt = "due_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Untitled task"
        self.notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
        self.status = (try? c.decode(TaskStatus.self, forKey: .status)) ?? .todo
        self.priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        self.source = (try? c.decode(String.self, forKey: .source)) ?? "unknown"
        self.groupId = try? c.decodeIfPresent(String.self, forKey: .groupId)
        self.dueAt = try? c.decodeIfPresent(Int.self, forKey: .dueAt)
        self.updatedAt = (try? c.decode(Int.self, forKey: .updatedAt)) ?? Int(Date().timeIntervalSince1970)

        if let boolValue = try? c.decode(Bool.self, forKey: .isStarred) {
            self.isStarred = boolValue
        } else if let intValue = try? c.decode(Int.self, forKey: .isStarred) {
            self.isStarred = intValue != 0
        } else {
            self.isStarred = false
        }
    }
}

struct TaskGroup: Identifiable, Equatable, Decodable {
    let id: String
    var name: String
    var color: String
    var sortOrder: Int
    var archivedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case sortOrder = "sort_order"
        case archivedAt = "archived_at"
    }
}

enum SectionKind: String, CaseIterable, Identifiable {
    case immediate
    case thisWeek = "this_week"
    case other
    case waiting
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waiting: return "Waiting"
        case .immediate: return "Immediate"
        case .thisWeek: return "This Week"
        case .other: return "Other"
        case .done: return "Done"
        }
    }
}

struct TaskSection: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: SectionKind
    let tasks: [PlannerTask]
    let groupId: String?
}

struct TaskEditDraft: Equatable {
    var title: String
    var notes: String
    var status: TaskStatus
    var priority: Int
    var isStarred: Bool
    var groupId: String?
    var dueAt: Int?

    init(task: PlannerTask) {
        title = task.title
        notes = task.notes
        status = task.status
        priority = task.priority
        isStarred = task.isStarred
        groupId = task.groupId
        dueAt = task.dueAt
    }

    init(title: String, notes: String, status: TaskStatus, priority: Int, isStarred: Bool, groupId: String?, dueAt: Int?) {
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.isStarred = isStarred
        self.groupId = groupId
        self.dueAt = dueAt
    }

    func isDifferent(from task: PlannerTask) -> Bool {
        title != task.title ||
            notes != task.notes ||
            status != task.status ||
            priority != task.priority ||
            isStarred != task.isStarred ||
            groupId != task.groupId ||
            dueAt != task.dueAt
    }

    func patchFields() -> [String: Any] {
        [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": notes,
            "status": status.rawValue,
            "priority": max(0, min(priority, 4)),
            "is_starred": isStarred ? 1 : 0,
            "group_id": groupId as Any,
            "due_at": dueAt as Any
        ]
    }
}

private struct SeqResponse: Decodable {
    let latestSeq: Int

    enum CodingKeys: String, CodingKey {
        case latestSeq = "latest_seq"
    }
}

private struct TasksResponse: Decodable {
    let tasks: [PlannerTask]
    let latestSeq: Int

    enum CodingKeys: String, CodingKey {
        case tasks
        case latestSeq = "latest_seq"
    }
}

private struct TaskResponse: Decodable {
    let task: PlannerTask
    let latestSeq: Int

    enum CodingKeys: String, CodingKey {
        case task
        case latestSeq = "latest_seq"
    }
}

private struct GroupsResponse: Decodable {
    let groups: [TaskGroup]
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case groups
        case requestId = "request_id"
    }
}

enum GatewayError: Error {
    case invalidURL(String)
    case transport(String)
    case timeout(String)
    case http(Int, String, String?)
    case decode(String)

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Gateway URL is invalid"
        case .transport:
            return "Gateway unavailable"
        case .timeout:
            return "Gateway request timed out"
        case .http(let code, _, _):
            return "Gateway error (HTTP \(code))"
        case .decode:
            return "Gateway response format error"
        }
    }
}

final class GatewayClient {
    static let shared = GatewayClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    private func resolvedBaseURL() -> URL {
        let raw = SettingsStore.shared.settings.gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "http://127.0.0.1:8765")!
    }

    private func authToken() -> String {
        SettingsStore.shared.settings.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchLatestSeq(completion: @escaping (Result<Int, GatewayError>) -> Void) {
        request(path: "/v1/meta/seq", method: "GET", body: nil, responseType: SeqResponse.self) { result in
            completion(result.map { $0.latestSeq })
        }
    }

    func fetchTasks(limit: Int = 200, completion: @escaping (Result<(tasks: [PlannerTask], latestSeq: Int), GatewayError>) -> Void) {
        request(path: "/v1/tasks?limit=\(limit)", method: "GET", body: nil, responseType: TasksResponse.self) { result in
            completion(result.map { ($0.tasks, $0.latestSeq) })
        }
    }

    func fetchGroups(completion: @escaping (Result<[TaskGroup], GatewayError>) -> Void) {
        request(path: "/v1/groups", method: "GET", body: nil, responseType: GroupsResponse.self) { result in
            completion(result.map { $0.groups })
        }
    }

    func createTask(
        title: String,
        notes: String,
        status: TaskStatus,
        priority: Int,
        isStarred: Bool,
        source: String,
        completion: @escaping (Result<(task: PlannerTask, latestSeq: Int), GatewayError>) -> Void
    ) {
        let payload: [String: Any] = [
            "title": title,
            "notes": notes,
            "status": status.rawValue,
            "priority": max(0, min(priority, 4)),
            "is_starred": isStarred ? 1 : 0,
            "source": source,
            "group_id": SettingsStore.shared.settings.defaultGroupId as Any
        ]
        requestJSON(path: "/v1/tasks", method: "POST", payload: payload, responseType: TaskResponse.self) { result in
            completion(result.map { ($0.task, $0.latestSeq) })
        }
    }

    func patchTask(taskId: String, fields: [String: Any], completion: @escaping (Result<(task: PlannerTask, latestSeq: Int), GatewayError>) -> Void) {
        requestJSON(path: "/v1/tasks/\(taskId)", method: "PATCH", payload: fields, responseType: TaskResponse.self) { result in
            completion(result.map { ($0.task, $0.latestSeq) })
        }
    }

    func completeTask(taskId: String, completion: @escaping (Result<(task: PlannerTask, latestSeq: Int), GatewayError>) -> Void) {
        request(path: "/v1/tasks/\(taskId)/complete", method: "POST", body: nil, responseType: TaskResponse.self) { result in
            completion(result.map { ($0.task, $0.latestSeq) })
        }
    }

    func archiveTask(taskId: String, completion: @escaping (Result<(task: PlannerTask, latestSeq: Int), GatewayError>) -> Void) {
        request(path: "/v1/tasks/\(taskId)/archive", method: "POST", body: nil, responseType: TaskResponse.self) { result in
            completion(result.map { ($0.task, $0.latestSeq) })
        }
    }

    private func requestJSON<T: Decodable>(path: String, method: String, payload: [String: Any], responseType: T.Type, completion: @escaping (Result<T, GatewayError>) -> Void) {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            request(path: path, method: method, body: data, responseType: responseType, completion: completion)
        } catch {
            completion(.failure(.decode("failed to encode JSON payload")))
        }
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?, responseType: T.Type, completion: @escaping (Result<T, GatewayError>) -> Void) {
        guard let url = URL(string: path, relativeTo: resolvedBaseURL()) else {
            completion(.failure(.invalidURL(path)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let token = authToken()
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestId = UUID().uuidString
        req.setValue(requestId, forHTTPHeaderField: "X-Request-Id")
        PlannerLogger.shared.log(.debug, "Gateway request", metadata: ["request_id": requestId, "method": method, "path": path])

        session.dataTask(with: req) { data, response, error in
            if let error {
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    PlannerLogger.shared.log(.error, "Gateway timeout", metadata: ["request_id": requestId, "path": path, "error": error.localizedDescription])
                    completion(.failure(.timeout(error.localizedDescription)))
                    return
                }
                PlannerLogger.shared.log(.error, "Gateway transport failure", metadata: ["request_id": requestId, "path": path, "error": error.localizedDescription])
                completion(.failure(.transport(error.localizedDescription)))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                PlannerLogger.shared.log(.error, "Gateway missing HTTP response", metadata: ["request_id": requestId, "path": path])
                completion(.failure(.transport("missing HTTP response")))
                return
            }

            let responseData = data ?? Data()
            let responseText = String(data: responseData, encoding: .utf8) ?? ""
            let responseReqID = http.value(forHTTPHeaderField: "X-Request-Id")

            guard (200...299).contains(http.statusCode) else {
                PlannerLogger.shared.log(.error, "Gateway HTTP failure", metadata: [
                    "request_id": requestId,
                    "response_request_id": responseReqID ?? "",
                    "path": path,
                    "status": "\(http.statusCode)",
                    "body": String(responseText.prefix(600))
                ])
                completion(.failure(.http(http.statusCode, responseText, responseReqID)))
                return
            }

            do {
                let decoded = try self.decoder.decode(responseType, from: responseData)
                PlannerLogger.shared.log(.debug, "Gateway response", metadata: [
                    "request_id": requestId,
                    "response_request_id": responseReqID ?? "",
                    "path": path,
                    "status": "\(http.statusCode)"
                ])
                completion(.success(decoded))
            } catch {
                PlannerLogger.shared.log(.error, "Gateway decode failure", metadata: [
                    "request_id": requestId,
                    "response_request_id": responseReqID ?? "",
                    "path": path,
                    "error": error.localizedDescription,
                    "body": String(responseText.prefix(600))
                ])
                completion(.failure(.decode(error.localizedDescription)))
            }
        }.resume()
    }
}

final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published var tasks: [PlannerTask] = []
    @Published var sections: [TaskSection] = []
    @Published var groups: [TaskGroup] = []
    @Published var lastError: String = ""
    @Published var isConnected: Bool = false
    @Published var lastSyncAt: Date?

    private let client = GatewayClient.shared
    private var pollTimer: Timer?
    private var lastSeenSeq: Int = 0
    private var isRefreshing = false
    private var isPopoverVisible = false
    private var consecutiveFailures = 0
    private var settingsObserver: NSObjectProtocol?
    private var inFlightActions: [String: String] = [:]
    private var groupsById: [String: TaskGroup] = [:]

    private init() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .plannerSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }

        applySettings()
        refreshNow()
    }

    deinit {
        pollTimer?.invalidate()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func applySettings() {
        PlannerLogger.shared.setMinLevel(SettingsStore.shared.settings.logLevel)
        sections = buildSections(from: tasks)
        schedulePolling()
    }

    func setFastPolling(_ fast: Bool) {
        isPopoverVisible = fast
        schedulePolling()
    }

    func refreshNow() {
        loadTasks()
    }

    func task(id: String) -> PlannerTask? {
        tasks.first(where: { $0.id == id })
    }

    func addTask(
        title: String,
        notes: String = "",
        priority: Int = 2,
        isStarred: Bool = false,
        status: TaskStatus? = nil,
        source: String = "menubar"
    ) {
        let resolvedStatus = status ?? SettingsStore.shared.settings.defaultStatus
        client.createTask(
            title: title,
            notes: notes,
            status: resolvedStatus,
            priority: priority,
            isStarred: isStarred,
            source: source
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let created):
                    self.lastSeenSeq = max(self.lastSeenSeq, created.latestSeq)
                    self.markHealthyConnection()
                    self.loadTasks()

                    if SettingsStore.shared.settings.mirrorCLI {
                        let cliText = notes.isEmpty ? title : "\(title) :: \(notes)"
                        CLIWrapper.shared.addTask(cliText)
                    }
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    func removeTask(id: String) {
        guard beginAction(taskId: id, action: "archive") else { return }
        PlannerLogger.shared.log(.info, "Task action started", metadata: ["action": "archive", "task_id": id, "endpoint": "/v1/tasks/\(id)/archive"])
        client.archiveTask(taskId: id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: id)
                switch result {
                case .success(let out):
                    PlannerLogger.shared.log(.info, "Task action success", metadata: [
                        "action": "archive",
                        "task_id": id,
                        "status": out.task.status.rawValue
                    ])
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.loadTasks()
                case .failure(let error):
                    PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                        "action": "archive",
                        "task_id": id,
                        "error": self.describe(error)
                    ])
                    self.handleActionError(taskId: id, error: error)
                }
            }
        }
    }

    func toggleTask(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        guard beginAction(taskId: id, action: "toggle") else { return }
        let targetStatus: TaskStatus = task.status == .done ? .todo : .done
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "toggle",
            "task_id": id,
            "from_status": task.status.rawValue,
            "to_status": targetStatus.rawValue,
            "endpoint": task.status == .done ? "/v1/tasks/\(id)" : "/v1/tasks/\(id)/complete"
        ])
        if task.status == .done {
            client.patchTask(taskId: id, fields: ["status": TaskStatus.todo.rawValue]) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.endAction(taskId: id)
                    switch result {
                    case .success(let out):
                        self.logStatusTransition(taskId: id, oldStatus: task.status, newStatus: out.task.status)
                        PlannerLogger.shared.log(.info, "Task action success", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "status": out.task.status.rawValue
                        ])
                        self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                        self.markHealthyConnection()
                        self.loadTasks()
                    case .failure(let error):
                        PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "error": self.describe(error)
                        ])
                        self.handleActionError(taskId: id, error: error)
                    }
                }
            }
        } else {
            client.completeTask(taskId: id) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.endAction(taskId: id)
                    switch result {
                    case .success(let out):
                        self.logStatusTransition(taskId: id, oldStatus: task.status, newStatus: out.task.status)
                        PlannerLogger.shared.log(.info, "Task action success", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "status": out.task.status.rawValue
                        ])
                        self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                        self.markHealthyConnection()
                        self.loadTasks()
                    case .failure(let error):
                        PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "error": self.describe(error)
                        ])
                        self.handleActionError(taskId: id, error: error)
                    }
                }
            }
        }
    }

    func saveTaskEdits(taskId: String, draft: TaskEditDraft, completion: @escaping (Result<Void, GatewayError>) -> Void) {
        guard beginAction(taskId: taskId, action: "edit") else { return }
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "edit",
            "task_id": taskId,
            "endpoint": "/v1/tasks/\(taskId)"
        ])
        client.patchTask(taskId: taskId, fields: draft.patchFields()) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: taskId)
                switch result {
                case .success(let out):
                    self.logStatusTransition(taskId: taskId, oldStatus: self.task(id: taskId)?.status ?? out.task.status, newStatus: out.task.status)
                    PlannerLogger.shared.log(.info, "Task action success", metadata: [
                        "action": "edit",
                        "task_id": taskId,
                        "status": out.task.status.rawValue
                    ])
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.loadTasks()
                    completion(.success(()))
                case .failure(let error):
                    PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                        "action": "edit",
                        "task_id": taskId,
                        "error": self.describe(error)
                    ])
                    self.handleActionError(taskId: taskId, error: error)
                    completion(.failure(error))
                }
            }
        }
    }

    func toggleStar(taskId: String) {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return }
        guard beginAction(taskId: taskId, action: "toggle_star") else { return }
        let oldValue = task.isStarred
        let newValue = !oldValue
        updateLocalStar(taskId: taskId, isStarred: newValue)
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "toggle_star",
            "task_id": taskId,
            "from": "\(oldValue)",
            "to": "\(newValue)",
            "endpoint": "/v1/tasks/\(taskId)"
        ])
        client.patchTask(taskId: taskId, fields: ["is_starred": newValue ? 1 : 0]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: taskId)
                switch result {
                case .success(let out):
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.loadTasks()
                case .failure(let error):
                    self.updateLocalStar(taskId: taskId, isStarred: oldValue)
                    self.handleActionError(taskId: taskId, error: error)
                }
            }
        }
    }

    func isTaskInFlight(_ taskId: String) -> Bool {
        inFlightActions[taskId] != nil
    }

    private func schedulePolling() {
        pollTimer?.invalidate()
        let interval = pollIntervalWithBackoff()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollForChanges()
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
        PlannerLogger.shared.log(.debug, "Polling scheduled", metadata: ["interval": "\(interval)", "visible": "\(isPopoverVisible)", "failures": "\(consecutiveFailures)"])
    }

    private func pollIntervalWithBackoff() -> TimeInterval {
        let settings = SettingsStore.shared.settings
        let base = isPopoverVisible ? settings.pollVisibleSec : settings.pollHiddenSec
        let multiplier = pow(2.0, Double(min(consecutiveFailures, 4)))
        let jitter = Double(Int.random(in: 0...800)) / 1000.0
        let value = min(base * multiplier + jitter, 60)
        return max(1.0, value)
    }

    private func pollForChanges() {
        client.fetchLatestSeq { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let seq):
                    self.markHealthyConnection()
                    if seq > self.lastSeenSeq {
                        self.loadTasks()
                    }
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    private func loadTasks() {
        guard !isRefreshing else { return }
        isRefreshing = true
        client.fetchGroups { [weak self] groupsResult in
            DispatchQueue.main.async {
                guard let self else { return }
                switch groupsResult {
                case .success(let groups):
                    self.groups = groups.filter { $0.archivedAt == nil }
                    self.groupsById = Dictionary(uniqueKeysWithValues: self.groups.map { ($0.id, $0) })
                case .failure(let error):
                    PlannerLogger.shared.log(.warn, "Group refresh failed", metadata: ["error": self.describe(error)])
                }
            }
        }
        client.fetchTasks(limit: 300) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let payload):
                    self.tasks = payload.tasks
                    self.sections = self.buildSections(from: payload.tasks)
                    self.lastSeenSeq = payload.latestSeq
                    self.lastSyncAt = Date()
                    self.markHealthyConnection()
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    private func markHealthyConnection() {
        isConnected = true
        lastError = ""
        if consecutiveFailures != 0 {
            consecutiveFailures = 0
            schedulePolling()
            PlannerLogger.shared.log(.info, "Gateway connection recovered")
        }
    }

    private func handle(error: GatewayError) {
        isConnected = false
        lastError = error.userMessage
        consecutiveFailures += 1
        PlannerLogger.shared.log(.error, "TaskStore error", metadata: [
            "error": describe(error),
            "failures": "\(consecutiveFailures)"
        ])
        schedulePolling()
    }

    private func beginAction(taskId: String, action: String) -> Bool {
        if inFlightActions[taskId] != nil {
            PlannerLogger.shared.log(.warn, "Ignored action on in-flight task", metadata: ["task_id": taskId, "action": action])
            return false
        }
        inFlightActions[taskId] = action
        return true
    }

    private func endAction(taskId: String) {
        inFlightActions.removeValue(forKey: taskId)
    }

    private func updateLocalStar(taskId: String, isStarred: Bool) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].isStarred = isStarred
        sections = buildSections(from: tasks)
    }

    private func logStatusTransition(taskId: String, oldStatus: TaskStatus, newStatus: TaskStatus) {
        guard oldStatus != newStatus else { return }
        PlannerLogger.shared.log(.info, "Task status transition", metadata: [
            "task_id": taskId,
            "from_status": oldStatus.rawValue,
            "to_status": newStatus.rawValue
        ])
    }

    private func handleActionError(taskId: String, error: GatewayError) {
        if case let .http(status, _, _) = error, status == 404 {
            PlannerLogger.shared.log(.warn, "Action hit stale task; forcing refresh", metadata: ["task_id": taskId, "status": "404"])
            tasks.removeAll { $0.id == taskId }
            sections = buildSections(from: tasks)
            refreshNow()
            lastError = ""
            return
        }
        handle(error: error)
    }

    private func describe(_ error: GatewayError) -> String {
        switch error {
        case .invalidURL(let msg):
            return "invalidURL(\(msg))"
        case .transport(let msg):
            return "transport(\(msg))"
        case .timeout(let msg):
            return "timeout(\(msg))"
        case .http(let code, let body, let requestId):
            if let requestId, !requestId.isEmpty {
                return "http(\(code), request_id=\(requestId), \(String(body.prefix(240))))"
            }
            return "http(\(code), \(String(body.prefix(240))))"
        case .decode(let msg):
            return "decode(\(msg))"
        }
    }

    private func buildSections(from allTasks: [PlannerTask]) -> [TaskSection] {
        let now = Int(Date().timeIntervalSince1970)
        let day = 24 * 60 * 60
        let week = 7 * day
        let settings = SettingsStore.shared.settings

        let active = allTasks.filter { $0.status != .done && $0.status != .archived }
        let waiting = active.filter { $0.status == .inbox }
        let done = allTasks.filter { $0.status == .done }

        var immediate: [PlannerTask] = []
        var thisWeek: [PlannerTask] = []
        var other: [PlannerTask] = []

        for task in active where task.status != .inbox {
            if let due = task.dueAt {
                if due <= now + day {
                    immediate.append(task)
                } else if due <= now + week {
                    thisWeek.append(task)
                } else {
                    other.append(task)
                }
                continue
            }

            if settings.immediateOverrideEnabled && (task.isStarred || task.priority >= 3) {
                immediate.append(task)
            } else {
                other.append(task)
            }
        }

        let buckets: [(SectionKind, [PlannerTask])] = [
            (.immediate, sortTasks(immediate)),
            (.thisWeek, sortTasks(thisWeek)),
            (.other, sortTasks(other)),
            (.waiting, sortTasks(waiting)),
            (.done, sortTasks(done))
        ]

        let visibleGroupIDs = Set(settings.visibleGroupIds)
        let shouldFilterGroups = !visibleGroupIDs.isEmpty
        let baseGroups = groups.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        var groupedChoices: [(id: String?, name: String)] = [("ungrouped", "Ungrouped")]
        groupedChoices.append(contentsOf: baseGroups.map { (Optional($0.id), $0.name) })

        func visibleTasksForGroup(_ tasks: [PlannerTask], groupId: String?) -> [PlannerTask] {
            let filtered = tasks.filter { $0.groupId == groupId }
            if !shouldFilterGroups || groupId == nil {
                return filtered
            }
            guard let groupId else { return filtered }
            return visibleGroupIDs.contains(groupId) ? filtered : []
        }

        func shouldIncludeKind(_ kind: SectionKind) -> Bool {
            if kind == .done && !settings.showDoneSection { return false }
            if kind == .waiting && !settings.showWaitingSection { return false }
            return true
        }

        var built: [TaskSection] = []
        switch settings.defaultGroupView {
        case .bucket:
            for (kind, items) in buckets where shouldIncludeKind(kind) && !items.isEmpty {
                built.append(TaskSection(id: kind.rawValue, title: kind.title, kind: kind, tasks: items, groupId: nil))
            }
        case .groupThenBucket:
            for choice in groupedChoices {
                let gid = choice.id == "ungrouped" ? nil : choice.id
                for (kind, items) in buckets where shouldIncludeKind(kind) {
                    let scoped = visibleTasksForGroup(items, groupId: gid)
                    if scoped.isEmpty { continue }
                    let sectionID = "\(choice.id ?? "ungrouped"):\(kind.rawValue)"
                    built.append(TaskSection(id: sectionID, title: "\(choice.name) · \(kind.title)", kind: kind, tasks: scoped, groupId: gid))
                }
            }
        case .bucketThenGroup:
            for (kind, items) in buckets where shouldIncludeKind(kind) {
                for choice in groupedChoices {
                    let gid = choice.id == "ungrouped" ? nil : choice.id
                    let scoped = visibleTasksForGroup(items, groupId: gid)
                    if scoped.isEmpty { continue }
                    let sectionID = "\(kind.rawValue):\(choice.id ?? "ungrouped")"
                    built.append(TaskSection(id: sectionID, title: "\(kind.title) · \(choice.name)", kind: kind, tasks: scoped, groupId: gid))
                }
            }
        }
        return built
    }

    private func sortTasks(_ input: [PlannerTask]) -> [PlannerTask] {
        let mode = SettingsStore.shared.settings.defaultSortMode
        return input.sorted { lhs, rhs in
            switch mode {
            case .due:
                switch (lhs.dueAt, rhs.dueAt) {
                case let (.some(a), .some(b)) where a != b: return a < b
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
                return lhs.updatedAt > rhs.updatedAt
            case .priority:
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.updatedAt > rhs.updatedAt
            case .updated:
                return lhs.updatedAt > rhs.updatedAt
            case .smart:
                if lhs.isStarred != rhs.isStarred {
                    return lhs.isStarred && !rhs.isStarred
                }
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                switch (lhs.dueAt, rhs.dueAt) {
                case let (.some(a), .some(b)) where a != b:
                    return a < b
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    break
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }
}
