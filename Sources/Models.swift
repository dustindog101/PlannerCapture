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
    var sourceRef: String
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
        case sourceRef = "source_ref"
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
        self.sourceRef = (try? c.decode(String.self, forKey: .sourceRef)) ?? ""
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
    var sourceRef: String

    init(task: PlannerTask) {
        title = task.title
        notes = task.notes
        status = task.status
        priority = task.priority
        isStarred = task.isStarred
        groupId = task.groupId
        dueAt = task.dueAt
        sourceRef = task.sourceRef
    }

    init(title: String, notes: String, status: TaskStatus, priority: Int, isStarred: Bool, groupId: String?, dueAt: Int?, sourceRef: String) {
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.isStarred = isStarred
        self.groupId = groupId
        self.dueAt = dueAt
        self.sourceRef = sourceRef
    }

    func isDifferent(from task: PlannerTask) -> Bool {
        title != task.title ||
            notes != task.notes ||
            status != task.status ||
            priority != task.priority ||
            isStarred != task.isStarred ||
            groupId != task.groupId ||
            dueAt != task.dueAt ||
            sourceRef != task.sourceRef
    }

    func patchFields() -> [String: Any] {
        [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": notes,
            "status": status.rawValue,
            "priority": max(0, min(priority, 4)),
            "is_starred": isStarred ? 1 : 0,
            "group_id": groupId as Any,
            "due_at": dueAt as Any,
            "source_ref": sourceRef.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }
}
