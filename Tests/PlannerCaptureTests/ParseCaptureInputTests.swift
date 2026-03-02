import XCTest
@testable import PlannerCapture

final class ParseCaptureInputTests: XCTestCase {
    func test_parseCaptureInput_complexInput_extractsStructuredFields() {
        let parsed = parseCaptureInput("/blocked !! Ship API docs #p1 #star #g:Work :: include rollout notes")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.statusOverride, .blocked)
        XCTAssertEqual(parsed?.title, "Ship API docs")
        XCTAssertEqual(parsed?.notes, "include rollout notes")
        XCTAssertEqual(parsed?.priority, 1)
        XCTAssertEqual(parsed?.isStarred, true)
        XCTAssertEqual(parsed?.groupName, "Work")
    }

    func test_parseCaptureInput_priorityTokenOutOfRange_keptAsTextAndBangPriorityApplies() {
        let parsed = parseCaptureInput("!!! Audit logs #p9")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Audit logs #p9")
        XCTAssertEqual(parsed?.priority, 4)
        XCTAssertEqual(parsed?.isStarred, true)
    }

    func test_parseCaptureInput_unknownSlashCommand_treatedAsPlainTitle() {
        let parsed = parseCaptureInput("/tomorrow finish migration :: before standup")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.statusOverride, nil)
        XCTAssertEqual(parsed?.title, "/tomorrow finish migration")
        XCTAssertEqual(parsed?.notes, "before standup")
        XCTAssertEqual(parsed?.priority, 2)
        XCTAssertEqual(parsed?.isStarred, false)
    }
}
