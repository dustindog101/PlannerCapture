import Foundation

struct CaptureDraft: Equatable {
    var title: String
    var notes: String
    var priority: Int
    var isStarred: Bool
    var statusOverride: TaskStatus?
    var groupName: String?
    var dueAt: Int?
}

// MARK: - Due Date Parsing

/// Attempts to parse a date string into a Unix timestamp.
/// Tries relative offsets first, then falls back to NSDataDetector for absolute/natural language dates.
func parseDueDate(_ raw: String) -> Int? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    // 1. Try relative offset (5m, 2h, 1d, 1w, 1h30m, 1h:30m)
    if let relative = parseRelativeOffset(trimmed) {
        return relative
    }

    // 2. Try NSDataDetector for absolute dates, times, and natural language
    if let detected = parseWithDataDetector(trimmed) {
        return detected
    }

    return nil
}

/// Parses relative time offsets like "5m", "1d", "1w", "1d 10h", "1h30m"
private func parseRelativeOffset(_ input: String) -> Int? {
    let lower = input.lowercased().trimmingCharacters(in: .whitespaces)

    // Weeks
    if lower.hasSuffix("w"), lower.filter({ $0 == "w" }).count == 1 {
        let numStr = lower.dropLast().trimmingCharacters(in: .whitespaces)
        if let num = Int(numStr) {
            return Int(Date().timeIntervalSince1970) + (num * 604800)
        }
    }

    // Days/Hours/Minutes (e.g., "1d 10h", "1h30m", "5m")
    let pattern = #"^(?:(\d+)d)?[:\s]*(?:(\d+)h)?[:\s]*(?:(\d+)m)?$"#
    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
       let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        
        let daysRange = match.range(at: 1)
        let hoursRange = match.range(at: 2)
        let minsRange = match.range(at: 3)
        
        var totalSeconds = 0
        
        if daysRange.location != NSNotFound, let r = Range(daysRange, in: lower), let d = Int(lower[r]) {
            totalSeconds += d * 86400
        }
        if hoursRange.location != NSNotFound, let r = Range(hoursRange, in: lower), let h = Int(lower[r]) {
            totalSeconds += h * 3600
        }
        if minsRange.location != NSNotFound, let r = Range(minsRange, in: lower), let m = Int(lower[r]) {
            totalSeconds += m * 60
        }
        
        if totalSeconds > 0 {
            return Int(Date().timeIntervalSince1970) + totalSeconds
        }
    }

    return nil
}

/// Uses NSDataDetector to parse absolute dates/times and natural language like "tomorrow", "03/10 11:59pm".
/// If a time-only result is in the past, bumps it to tomorrow.
/// If a date-only result (no year specified) is in the past, bumps it to next year.
private func parseWithDataDetector(_ input: String) -> Int? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        return nil
    }

    let range = NSRange(input.startIndex..., in: input)
    guard let match = detector.firstMatch(in: input, options: [], range: range),
          let date = match.date else {
        return nil
    }

    let now = Date()

    // If the resolved date is in the past, apply smart bumping
    if date < now {
        let calendar = Calendar.current

        // Check if input looks like a time-only string (e.g., "8am", "10:50pm")
        let timeOnlyPattern = #"^\d{1,2}(:\d{2})?\s*(am|pm)$"#
        if let timeRegex = try? NSRegularExpression(pattern: timeOnlyPattern, options: .caseInsensitive),
           timeRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
            // Bump to tomorrow
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                return Int(tomorrow.timeIntervalSince1970)
            }
        }

        // Check if input looks like a month/day without year (e.g., "03/10", "03/10 11:59pm")
        let monthDayPattern = #"^\d{1,2}/\d{1,2}(\s+\d{1,2}(:\d{2})?\s*(am|pm))?$"#
        if let mdRegex = try? NSRegularExpression(pattern: monthDayPattern, options: .caseInsensitive),
           mdRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
            // Bump to next year
            if let nextYear = calendar.date(byAdding: .year, value: 1, to: date) {
                return Int(nextYear.timeIntervalSince1970)
            }
        }
    }

    return Int(date.timeIntervalSince1970)
}

// MARK: - Main Capture Parser

func parseCaptureInput(_ raw: String) -> CaptureDraft? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return nil }

    // Step 1: Extract due date string from | separator FIRST (before any other parsing)
    var dueDateRaw: String?
    if let pipeIndex = text.firstIndex(of: "|") {
        dueDateRaw = String(text[text.index(after: pipeIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        text = String(text[..<pipeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Step 2: Parse status command
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

    // Step 3: Parse bang priority
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

    // Step 4: Parse tokens (#star, #p, #g:, due:)
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
        // due: token (for simple values like due:5m, due:1h, due:tomorrow)
        if lower.hasPrefix("due:") && dueDateRaw == nil {
            let rawDue = String(token.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawDue.isEmpty {
                dueDateRaw = rawDue
            }
            continue
        }
        // : token shorthand (alias for due:, like :tomorrow or :5m)
        if lower.hasPrefix(":") && !lower.hasPrefix("::") && lower.count > 1 && dueDateRaw == nil {
            let rawDue = String(token.dropFirst(1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawDue.isEmpty {
                dueDateRaw = rawDue
            }
            continue
        }
        keptTokens.append(token)
    }
    text = keptTokens.joined(separator: " ")

    // Step 5: Split title :: notes
    let parts = text.components(separatedBy: "::")
    let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    var notes: String
    if parts.count >= 2 {
        notes = parts.dropFirst().joined(separator: "::").trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        notes = ""
    }

    // Step 6: Resolve due date
    var dueAt: Int?
    if let dueDateRaw, !dueDateRaw.isEmpty {
        dueAt = parseDueDate(dueDateRaw)
        if dueAt == nil {
            // Graceful fallback: store unrecognized string in notes
            let fallback = "[due?: \(dueDateRaw)]"
            notes = notes.isEmpty ? fallback : "\(notes)\n\n\(fallback)"
            PlannerLogger.shared.log(.warn, "Unrecognized due date input; saved in notes", metadata: ["raw": dueDateRaw])
        } else {
            PlannerLogger.shared.log(.debug, "Due date parsed", metadata: ["raw": dueDateRaw, "unix": "\(dueAt!)"])
        }
    }

    if title.isEmpty { return nil }
    return CaptureDraft(title: title, notes: notes, priority: priority, isStarred: isStarred, statusOverride: statusOverride, groupName: groupName, dueAt: dueAt)
}
