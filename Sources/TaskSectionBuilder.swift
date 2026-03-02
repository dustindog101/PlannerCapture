import Foundation

struct TaskSectionBuilder {
    static func buildSections(from allTasks: [PlannerTask], groups: [TaskGroup], settings: PlannerSettings) -> [TaskSection] {
        let now = Int(Date().timeIntervalSince1970)
        let day = 24 * 60 * 60
        let week = 7 * day

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
            (.immediate, sortTasks(immediate, mode: settings.defaultSortMode)),
            (.thisWeek, sortTasks(thisWeek, mode: settings.defaultSortMode)),
            (.other, sortTasks(other, mode: settings.defaultSortMode)),
            (.waiting, sortTasks(waiting, mode: settings.defaultSortMode)),
            (.done, sortTasks(done, mode: settings.defaultSortMode))
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

    private static func sortTasks(_ input: [PlannerTask], mode: SortMode) -> [PlannerTask] {
        input.sorted { lhs, rhs in
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
