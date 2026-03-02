import Foundation

struct CaptureDraft: Equatable {
    var title: String
    var notes: String
    var priority: Int
    var isStarred: Bool
    var statusOverride: TaskStatus?
    var groupName: String?
}

func parseCaptureInput(_ raw: String) -> CaptureDraft? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return nil }

    var statusOverride: TaskStatus?
    if text.hasPrefix("/") {
        let firstToken = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let remainder = text.dropFirst(firstToken.count).trimmingCharacters(in: .whitespaces)
        switch firstToken.lowercased() {
        case "/done":
            statusOverride = .done
            text = remainder
        case "/todo":
            statusOverride = .todo
            text = remainder
        case "/inbox":
            statusOverride = .inbox
            text = remainder
        case "/blocked", "/block":
            statusOverride = .blocked
            text = remainder
        case "/inprogress", "/in_progress":
            statusOverride = .inProgress
            text = remainder
        case "/archived", "/archive":
            statusOverride = .archived
            text = remainder
        default:
            PlannerLogger.shared.log(.warn, "Unknown capture status command; treating as plain title", metadata: ["token": firstToken])
        }
    }

    var priority = 2
    var isStarred = false

    var bangCount = 0
    while text.hasPrefix("!") {
        bangCount += 1
        text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    if bangCount > 0 {
        priority = min(4, 2 + bangCount)
        isStarred = true
    }

    let tokens = text.split(separator: " ").map(String.init)
    var keptTokens: [String] = []
    var groupName: String?
    for token in tokens {
        let lower = token.lowercased()
        if lower == "#star" || lower == "*" {
            isStarred = true
            continue
        }
        if lower.hasPrefix("#p"), let p = Int(token.dropFirst(2)), (0...4).contains(p) {
            priority = p
            if p >= 3 { isStarred = true }
            continue
        }
        if lower.hasPrefix("#g:") {
            let rawName = String(token.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawName.isEmpty {
                groupName = rawName
            }
            continue
        }
        keptTokens.append(token)
    }
    text = keptTokens.joined(separator: " ")

    let parts = text.components(separatedBy: "::")
    let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let notes: String
    if parts.count >= 2 {
        notes = parts.dropFirst().joined(separator: "::").trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        notes = ""
    }

    if title.isEmpty { return nil }
    return CaptureDraft(title: title, notes: notes, priority: priority, isStarred: isStarred, statusOverride: statusOverride, groupName: groupName)
}
