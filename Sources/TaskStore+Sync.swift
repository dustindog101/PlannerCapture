import Foundation

extension TaskStore {
    func schedulePolling() {
        pollTimer?.invalidate()
        let interval = pollIntervalWithBackoff()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollForChanges()
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
        PlannerLogger.shared.log(.debug, "Polling scheduled", metadata: ["interval": "\(interval)", "visible": "\(isPopoverVisible)", "failures": "\(consecutiveFailures)"])
    }

    func pollIntervalWithBackoff() -> TimeInterval {
        let settings = SettingsStore.shared.settings
        let base = isPopoverVisible ? settings.pollVisibleSec : settings.pollHiddenSec
        let multiplier = pow(2.0, Double(min(consecutiveFailures, 4)))
        let jitter = Double(Int.random(in: 0...800)) / 1000.0
        let value = min(base * multiplier + jitter, 60)
        return max(1.0, value)
    }

    func pollForChanges() {
        client.fetchLatestSeq { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let seq):
                    self.markHealthyConnection()
                    if seq > self.lastSeenSeq {
                        self.loadTasks()
                    }
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    func loadTasks() {
        guard !isRefreshing else { return }
        isRefreshing = true
        client.fetchGroups { [weak self] groupsResult in
            DispatchQueue.main.async {
                guard let self else { return }
                switch groupsResult {
                case .success(let groups):
                    self.groups = groups.filter { $0.archivedAt == nil }
                    self.groupsById = Dictionary(uniqueKeysWithValues: self.groups.map { ($0.id, $0) })
                case .failure(let error):
                    PlannerLogger.shared.log(.warn, "Group refresh failed", metadata: ["error": self.describe(error)])
                }
            }
        }
        client.fetchTasks(limit: 300) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let payload):
                    self.tasks = payload.tasks
                    self.sections = self.buildSections(from: payload.tasks)
                    self.lastSeenSeq = payload.latestSeq
                    self.lastSyncAt = Date()
                    self.markHealthyConnection()
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    func markHealthyConnection() {
        isConnected = true
        lastError = ""
        if consecutiveFailures != 0 {
            consecutiveFailures = 0
            schedulePolling()
            PlannerLogger.shared.log(.info, "Gateway connection recovered")
        }
    }

    func handle(error: GatewayError) {
        isConnected = false
        lastError = error.userMessage
        consecutiveFailures += 1
        PlannerLogger.shared.log(.error, "TaskStore error", metadata: [
            "error": describe(error),
            "failures": "\(consecutiveFailures)"
        ])
        schedulePolling()
    }

    func describe(_ error: GatewayError) -> String {
        switch error {
        case .invalidURL(let msg):
            return "invalidURL(\(msg))"
        case .transport(let msg):
            return "transport(\(msg))"
        case .timeout(let msg):
            return "timeout(\(msg))"
        case .http(let code, let body, let requestId):
            if let requestId, !requestId.isEmpty {
                return "http(\(code), request_id=\(requestId), \(String(body.prefix(240))))"
            }
            return "http(\(code), \(String(body.prefix(240))))"
        case .decode(let msg):
            return "decode(\(msg))"
        }
    }
}
