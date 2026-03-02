import XCTest
@testable import PlannerCapture

class PlannerCaptureIntegrationTestCase: XCTestCase {
    private var baselineSettings: PlannerSettings!

    override class func setUp() {
        super.setUp()
        setenv("PLANNERCAPTURE_USE_STUB_URL_PROTOCOL", "1", 1)
        URLProtocol.registerClass(GatewayStubURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(GatewayStubURLProtocol.self)
        unsetenv("PLANNERCAPTURE_USE_STUB_URL_PROTOCOL")
        super.tearDown()
    }

    override func setUp() {
        super.setUp()

        baselineSettings = SettingsStore.shared.settings
        GatewayStubURLProtocol.reset()

        GatewayStubURLProtocol.setFallback { request in
            let path = request.url?.path ?? "/"
            let query = request.url?.query.map { "?\($0)" } ?? ""
            let route = "\(path)\(query)"

            switch route {
            case "/v1/meta/seq":
                return GatewayStubURLProtocol.StubResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Data("{\"latest_seq\":1}".utf8)
                )
            case "/v1/groups":
                return GatewayStubURLProtocol.StubResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Data("{\"groups\":[],\"request_id\":\"test-default\"}".utf8)
                )
            case "/v1/tasks?limit=300", "/v1/tasks?limit=200":
                return GatewayStubURLProtocol.StubResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Data("{\"tasks\":[],\"latest_seq\":1}".utf8)
                )
            default:
                return GatewayStubURLProtocol.StubResponse(
                    statusCode: 404,
                    headers: ["Content-Type": "application/json"],
                    body: Data("{\"error\":\"not found\"}".utf8)
                )
            }
        }

        var testSettings = baselineSettings!
        testSettings.gatewayURL = "http://gateway.test"
        testSettings.apiToken = "test-token"
        testSettings.pollVisibleSec = 60
        testSettings.pollHiddenSec = 60
        testSettings.immediateOverrideEnabled = true
        testSettings.showDoneSection = true
        testSettings.showWaitingSection = true
        testSettings.defaultSortModeRaw = SortMode.smart.rawValue
        testSettings.defaultGroupViewRaw = GroupViewMode.bucket.rawValue
        testSettings.visibleGroupIds = []

        SettingsStore.shared.apply(testSettings)

        let store = TaskStore.shared
        store.tasks = []
        store.groups = []
        store.sections = []
        store.lastError = ""
        store.setFastPolling(false)
        store.applySettings()
        GatewayStubURLProtocol.clearCapturedRequests()
    }

    override func tearDown() {
        SettingsStore.shared.apply(baselineSettings)
        GatewayStubURLProtocol.reset()
        super.tearDown()
    }

    @discardableResult
    func waitUntil(timeout: TimeInterval = 2, pollingInterval: TimeInterval = 0.01, _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(pollingInterval))
            if condition() {
                return true
            }
        }
        return condition()
    }

    func makeTask(
        id: String,
        title: String,
        status: TaskStatus = .todo,
        priority: Int = 2,
        isStarred: Bool = false,
        groupId: String? = nil,
        dueAt: Int? = nil,
        updatedAt: Int = 1,
        notes: String = ""
    ) -> PlannerTask {
        let payload: [String: Any?] = [
            "id": id,
            "title": title,
            "notes": notes,
            "status": status.rawValue,
            "priority": priority,
            "is_starred": isStarred ? 1 : 0,
            "source": "tests",
            "source_ref": "",
            "group_id": groupId,
            "due_at": dueAt,
            "updated_at": updatedAt
        ]

        let compact = payload.compactMapValues { $0 }
        let data = try! JSONSerialization.data(withJSONObject: compact)
        return try! JSONDecoder().decode(PlannerTask.self, from: data)
    }
}
