import XCTest
@testable import PlannerCapture

final class GatewaySyncIntegrationTests: PlannerCaptureIntegrationTestCase {
    func test_gatewayRequest_includesCorrelationIdAndBearerToken() {
        GatewayStubURLProtocol.clearCapturedRequests()
        GatewayStubURLProtocol.enqueue(
            .init(
                statusCode: 200,
                headers: [
                    "Content-Type": "application/json",
                    "X-Request-Id": "hub-rid-123"
                ],
                body: Data("{\"latest_seq\":42}".utf8)
            ),
            method: "GET",
            pathWithQuery: "/v1/meta/seq"
        )

        let exp = expectation(description: "fetch latest seq")
        GatewayClient.shared.fetchLatestSeq { result in
            switch result {
            case .success(let seq):
                XCTAssertEqual(seq, 42)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)

        let requests = GatewayStubURLProtocol.requests(matching: "GET", pathWithQuery: "/v1/meta/seq")
        XCTAssertEqual(requests.count, 1)
        guard let request = requests.first else {
            XCTFail("Expected one captured request")
            return
        }
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-token")
        XCTAssertNotNil(request.headers["X-Request-Id"])
        XCTAssertEqual(request.headers["Accept"], "application/json")
    }

    func test_toggleTask_whenGatewayReturns404_removesLocalTaskAndRefreshes() {
        let stale = makeTask(id: "stale-1", title: "Stale", status: .todo)

        let store = TaskStore.shared
        store.groups = []
        store.tasks = [stale]
        store.applySettings()

        GatewayStubURLProtocol.clearCapturedRequests()
        GatewayStubURLProtocol.enqueue(
            .init(
                statusCode: 404,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"error\":\"not found\"}".utf8)
            ),
            method: "POST",
            pathWithQuery: "/v1/tasks/stale-1/complete"
        )
        GatewayStubURLProtocol.enqueue(
            .init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"groups\":[],\"request_id\":\"refresh-1\"}".utf8)
            ),
            method: "GET",
            pathWithQuery: "/v1/groups"
        )
        GatewayStubURLProtocol.enqueue(
            .init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"tasks\":[{\"id\":\"live-1\",\"title\":\"Refreshed\",\"notes\":\"\",\"status\":\"todo\",\"priority\":2,\"is_starred\":0,\"source\":\"tests\",\"source_ref\":\"\",\"updated_at\":11}],\"latest_seq\":11}".utf8)
            ),
            method: "GET",
            pathWithQuery: "/v1/tasks?limit=300"
        )

        store.toggleTask(id: "stale-1")

        let recovered = waitUntil(timeout: 2) {
            store.tasks.contains(where: { $0.id == "live-1" }) && !store.tasks.contains(where: { $0.id == "stale-1" })
        }

        XCTAssertTrue(recovered)
        XCTAssertEqual(store.lastError, "")
        XCTAssertEqual(GatewayStubURLProtocol.requests(matching: "POST", pathWithQuery: "/v1/tasks/stale-1/complete").count, 1)
        XCTAssertGreaterThanOrEqual(GatewayStubURLProtocol.requests(matching: "GET", pathWithQuery: "/v1/tasks?limit=300").count, 1)
    }

    func test_toggleStar_whenPatchFails_rollsBackOptimisticState() {
        let task = makeTask(id: "star-1", title: "Star me", isStarred: false)
        let store = TaskStore.shared
        store.tasks = [task]
        store.groups = []
        store.applySettings()

        GatewayStubURLProtocol.clearCapturedRequests()
        GatewayStubURLProtocol.enqueue(
            .init(
                statusCode: 500,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"error\":\"boom\"}".utf8)
            ),
            method: "PATCH",
            pathWithQuery: "/v1/tasks/star-1"
        )

        let exp = expectation(description: "toggle star returns failure")
        store.toggleStar(taskId: "star-1") { result in
            if case .failure = result {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(store.task(id: "star-1")?.isStarred, false)
        XCTAssertEqual(store.lastError, "Gateway error (HTTP 500)")
        XCTAssertEqual(GatewayStubURLProtocol.requests(matching: "PATCH", pathWithQuery: "/v1/tasks/star-1").count, 1)
    }
}
