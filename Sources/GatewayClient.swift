import Foundation

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

struct GroupResponse: Decodable {
    let group: TaskGroup
    let latestSeq: Int?

    enum CodingKeys: String, CodingKey {
        case group
        case latestSeq = "latest_seq"
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
        if ProcessInfo.processInfo.environment["PLANNERCAPTURE_USE_STUB_URL_PROTOCOL"] == "1" {
            let names = ["PlannerCaptureTests.GatewayStubURLProtocol", "GatewayStubURLProtocol"]
            for name in names {
                if let klass = NSClassFromString(name) as? URLProtocol.Type {
                    config.protocolClasses = [klass]
                    break
                }
            }
        }
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

    func createGroup(name: String, color: String = "blue", sortOrder: Int = 0, completion: @escaping (Result<GroupResponse, GatewayError>) -> Void) {
        let payload: [String: Any] = [
            "name": name,
            "color": color,
            "sort_order": sortOrder
        ]
        requestJSON(path: "/v1/groups", method: "POST", payload: payload, responseType: GroupResponse.self, completion: completion)
    }

    func patchGroup(groupId: String, fields: [String: Any], completion: @escaping (Result<GroupResponse, GatewayError>) -> Void) {
        requestJSON(path: "/v1/groups/\(groupId)", method: "PATCH", payload: fields, responseType: GroupResponse.self, completion: completion)
    }

    func archiveGroup(groupId: String, completion: @escaping (Result<GroupResponse, GatewayError>) -> Void) {
        request(path: "/v1/groups/\(groupId)/archive", method: "POST", body: nil, responseType: GroupResponse.self, completion: completion)
    }

    func createTask(
        title: String,
        notes: String,
        status: TaskStatus,
        priority: Int,
        isStarred: Bool,
        source: String,
        groupId: String?,
        sourceRef: String?,
        completion: @escaping (Result<(task: PlannerTask, latestSeq: Int), GatewayError>) -> Void
    ) {
        let payload: [String: Any] = [
            "title": title,
            "notes": notes,
            "status": status.rawValue,
            "priority": max(0, min(priority, 4)),
            "is_starred": isStarred ? 1 : 0,
            "source": source,
            "group_id": groupId as Any,
            "source_ref": sourceRef as Any
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
