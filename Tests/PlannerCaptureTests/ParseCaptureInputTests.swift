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

    // MARK: - Due Date Parsing Tests

    func test_parseCaptureInput_relativeMinutes_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Buy milk|5m")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Buy milk")
        XCTAssertNotNil(parsed?.dueAt)

        // Should be ~5 minutes from now (allow 2 second tolerance)
        let expected = before + 300
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~5 minutes from now")
    }

    func test_parseCaptureInput_relativeHours_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Read book|2h")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Read book")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 7200
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~2 hours from now")
    }

    func test_parseCaptureInput_compoundRelative_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Meeting prep|1h30m")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Meeting prep")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 5400 // 1h30m = 90min = 5400s
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~1h30m from now")
    }

    func test_parseCaptureInput_compoundRelativeWithColon_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Task|1h:15m")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Task")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 4500 // 1h15m = 75min = 4500s
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~1h15m from now")
    }

    func test_parseCaptureInput_relativeDays_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Plan trip|1d")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Plan trip")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 86400
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~1 day from now")
    }

    func test_parseCaptureInput_relativeWeeks_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Review|1w")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Review")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 604800
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~1 week from now")
    }

    func test_parseCaptureInput_dueToken_setsDueAt() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("!Meeting #g:Work due:1h :: prep slides")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Meeting")
        XCTAssertEqual(parsed?.notes, "prep slides")
        XCTAssertEqual(parsed?.groupName, "Work")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 3600
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2, "dueAt should be ~1 hour from now")
    }

    func test_parseCaptureInput_unrecognizedDueDate_fallsBackToNotes() {
        let parsed = parseCaptureInput("Bad task|someday maybe")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Bad task")
        XCTAssertNil(parsed?.dueAt)
        XCTAssertTrue(parsed?.notes.contains("[due?: someday maybe]") == true, "Notes should contain the unrecognized due date")
    }

    func test_parseCaptureInput_unrecognizedDueDate_appendsToExistingNotes() {
        let parsed = parseCaptureInput("Task :: existing notes|gibberish")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Task")
        XCTAssertNil(parsed?.dueAt)
        XCTAssertTrue(parsed?.notes.contains("existing notes") == true)
        XCTAssertTrue(parsed?.notes.contains("[due?: gibberish]") == true)
    }

    func test_parseCaptureInput_noPipe_noDueDate() {
        let parsed = parseCaptureInput("Normal task with no date")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Normal task with no date")
        XCTAssertNil(parsed?.dueAt)
        XCTAssertEqual(parsed?.notes, "")
    }

    func test_parseCaptureInput_pipeWithNotes_preservesBoth() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("!call mechanic :: ask for rates|5m")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "call mechanic")
        XCTAssertEqual(parsed?.notes, "ask for rates")
        XCTAssertNotNil(parsed?.dueAt)

        let expected = before + 300
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2)
    }

    func test_parseCaptureInput_pipePreferredOverDueToken() {
        let before = Int(Date().timeIntervalSince1970)
        let parsed = parseCaptureInput("Task due:ignored|5m")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Task due:ignored")
        XCTAssertNotNil(parsed?.dueAt)

        // The pipe takes precedence; due: is only used when there's no pipe
        let expected = before + 300
        XCTAssertTrue(abs((parsed?.dueAt ?? 0) - expected) <= 2)
    }
}
