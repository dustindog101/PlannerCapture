import XCTest
@testable import PlannerCapture

final class SectioningAndSortingTests: PlannerCaptureIntegrationTestCase {
    func test_buildSections_bucketMode_appliesDueWindowsAndSmartSort() {
        var settings = SettingsStore.shared.settings
        settings.defaultGroupViewRaw = GroupViewMode.bucket.rawValue
        settings.defaultSortModeRaw = SortMode.smart.rawValue
        settings.immediateOverrideEnabled = true
        SettingsStore.shared.apply(settings)

        let now = Int(Date().timeIntervalSince1970)
        let immediateDue = now + (4 * 60 * 60)
        let weekDue = now + (3 * 24 * 60 * 60)
        let farDue = now + (12 * 24 * 60 * 60)

        let starNoDue = makeTask(id: "t-star", title: "Starred", status: .todo, priority: 2, isStarred: true, updatedAt: 5)
        let dueSoon = makeTask(id: "t-now", title: "Due soon", status: .todo, priority: 1, dueAt: immediateDue, updatedAt: 1)
        let dueWeek = makeTask(id: "t-week", title: "Due this week", status: .inProgress, priority: 2, dueAt: weekDue, updatedAt: 1)
        let later = makeTask(id: "t-other", title: "Later", status: .todo, priority: 2, dueAt: farDue, updatedAt: 1)
        let waiting = makeTask(id: "t-wait", title: "Inbox", status: .inbox, updatedAt: 1)
        let done = makeTask(id: "t-done", title: "Done", status: .done, updatedAt: 1)

        let store = TaskStore.shared
        store.groups = []
        store.tasks = [later, done, waiting, dueWeek, dueSoon, starNoDue]
        store.applySettings()

        let immediateSection = store.sections.first(where: { $0.kind == .immediate })
        let weekSection = store.sections.first(where: { $0.kind == .thisWeek })
        let otherSection = store.sections.first(where: { $0.kind == .other })
        let waitingSection = store.sections.first(where: { $0.kind == .waiting })
        let doneSection = store.sections.first(where: { $0.kind == .done })

        XCTAssertEqual(immediateSection?.tasks.map(\.id), ["t-star", "t-now"])
        XCTAssertEqual(weekSection?.tasks.map(\.id), ["t-week"])
        XCTAssertEqual(otherSection?.tasks.map(\.id), ["t-other"])
        XCTAssertEqual(waitingSection?.tasks.map(\.id), ["t-wait"])
        XCTAssertEqual(doneSection?.tasks.map(\.id), ["t-done"])
    }

    func test_buildSections_bucketThenGroup_splitsByKindThenGroupVisibility() {
        var settings = SettingsStore.shared.settings
        settings.defaultGroupViewRaw = GroupViewMode.bucketThenGroup.rawValue
        settings.defaultSortModeRaw = SortMode.updated.rawValue
        settings.visibleGroupIds = ["g-visible"]
        SettingsStore.shared.apply(settings)

        let groupVisible = TaskGroup(id: "g-visible", name: "Visible", color: "blue", sortOrder: 0, archivedAt: nil)
        let groupHidden = TaskGroup(id: "g-hidden", name: "Hidden", color: "green", sortOrder: 1, archivedAt: nil)

        let visibleTask = makeTask(id: "vis", title: "Visible task", groupId: "g-visible", updatedAt: 3)
        let hiddenTask = makeTask(id: "hid", title: "Hidden task", groupId: "g-hidden", updatedAt: 2)
        let ungroupedTask = makeTask(id: "ung", title: "Ungrouped task", groupId: nil, updatedAt: 1)

        let store = TaskStore.shared
        store.groups = [groupVisible, groupHidden]
        store.tasks = [hiddenTask, ungroupedTask, visibleTask]
        store.applySettings()

        let titles = store.sections.map(\.title)
        XCTAssertTrue(titles.contains("Other · Ungrouped"))
        XCTAssertTrue(titles.contains("Other · Visible"))
        XCTAssertFalse(titles.contains("Other · Hidden"))

        let otherVisible = store.sections.first(where: { $0.title == "Other · Visible" })
        XCTAssertEqual(otherVisible?.tasks.map(\.id), ["vis"])
    }
}
