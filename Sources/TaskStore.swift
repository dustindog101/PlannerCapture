import Foundation

final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published var tasks: [PlannerTask] = []
    @Published var sections: [TaskSection] = []
    @Published var groups: [TaskGroup] = []
    @Published var lastError: String = ""
    @Published var isConnected: Bool = false
    @Published var lastSyncAt: Date?

    let client = GatewayClient.shared
    var pollTimer: Timer?
    var lastSeenSeq: Int = 0
    var isRefreshing = false
    var isPopoverVisible = false
    var consecutiveFailures = 0
    var settingsObserver: NSObjectProtocol?
    var inFlightActions: [String: String] = [:]
    var groupsById: [String: TaskGroup] = [:]

    private init() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .plannerSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }

        applySettings()
        refreshNow()
    }

    deinit {
        pollTimer?.invalidate()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func applySettings() {
        PlannerLogger.shared.setMinLevel(SettingsStore.shared.settings.logLevel)
        sections = buildSections(from: tasks)
        schedulePolling()
    }

    func setFastPolling(_ fast: Bool) {
        isPopoverVisible = fast
        schedulePolling()
    }

    func refreshNow() {
        loadTasks()
    }

    func task(id: String) -> PlannerTask? {
        tasks.first(where: { $0.id == id })
    }

    func buildSections(from allTasks: [PlannerTask]) -> [TaskSection] {
        TaskSectionBuilder.buildSections(from: allTasks, groups: groups, settings: SettingsStore.shared.settings)
    }
}
