import Foundation

extension Notification.Name {
    static let plannerSettingsDidChange = Notification.Name("plannerSettingsDidChange")
}

enum SortMode: String, Codable, CaseIterable, Identifiable {
    case smart
    case due
    case priority
    case updated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smart: return "Smart"
        case .due: return "Due Date"
        case .priority: return "Priority"
        case .updated: return "Recently Updated"
        }
    }
}

enum GroupViewMode: String, Codable, CaseIterable, Identifiable {
    case bucket
    case groupThenBucket = "group_then_bucket"
    case bucketThenGroup = "bucket_then_group"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bucket: return "Bucket"
        case .groupThenBucket: return "Group -> Bucket"
        case .bucketThenGroup: return "Bucket -> Group"
        }
    }
}

struct PlannerSettings: Codable {
    var gatewayURL: String
    var apiToken: String
    var pollVisibleSec: TimeInterval
    var pollHiddenSec: TimeInterval
    var defaultStatusRaw: String
    var immediateOverrideEnabled: Bool
    var mirrorCLI: Bool
    var logLevelRaw: String
    var showDoneSection: Bool
    var showWaitingSection: Bool
    var defaultSortModeRaw: String
    var defaultGroupViewRaw: String
    var starClickImmediateSave: Bool
    var compactRowDensity: Bool
    var defaultGroupId: String?
    var visibleGroupIds: [String]

    static let `default` = PlannerSettings(
        gatewayURL: "http://127.0.0.1:8765",
        apiToken: "",
        pollVisibleSec: 3,
        pollHiddenSec: 15,
        defaultStatusRaw: TaskStatus.inbox.rawValue,
        immediateOverrideEnabled: true,
        mirrorCLI: false,
        logLevelRaw: LogLevel.info.rawValue,
        showDoneSection: true,
        showWaitingSection: true,
        defaultSortModeRaw: SortMode.smart.rawValue,
        defaultGroupViewRaw: GroupViewMode.bucket.rawValue,
        starClickImmediateSave: true,
        compactRowDensity: false,
        defaultGroupId: nil,
        visibleGroupIds: []
    )

    enum CodingKeys: String, CodingKey {
        case gatewayURL
        case apiToken
        case pollVisibleSec
        case pollHiddenSec
        case defaultStatusRaw
        case immediateOverrideEnabled
        case mirrorCLI
        case logLevelRaw
        case showDoneSection
        case showWaitingSection
        case defaultSortModeRaw
        case defaultGroupViewRaw
        case starClickImmediateSave
        case compactRowDensity
        case defaultGroupId
        case visibleGroupIds
    }

    init(
        gatewayURL: String,
        apiToken: String,
        pollVisibleSec: TimeInterval,
        pollHiddenSec: TimeInterval,
        defaultStatusRaw: String,
        immediateOverrideEnabled: Bool,
        mirrorCLI: Bool,
        logLevelRaw: String,
        showDoneSection: Bool,
        showWaitingSection: Bool,
        defaultSortModeRaw: String,
        defaultGroupViewRaw: String,
        starClickImmediateSave: Bool,
        compactRowDensity: Bool,
        defaultGroupId: String?,
        visibleGroupIds: [String]
    ) {
        self.gatewayURL = gatewayURL
        self.apiToken = apiToken
        self.pollVisibleSec = pollVisibleSec
        self.pollHiddenSec = pollHiddenSec
        self.defaultStatusRaw = defaultStatusRaw
        self.immediateOverrideEnabled = immediateOverrideEnabled
        self.mirrorCLI = mirrorCLI
        self.logLevelRaw = logLevelRaw
        self.showDoneSection = showDoneSection
        self.showWaitingSection = showWaitingSection
        self.defaultSortModeRaw = defaultSortModeRaw
        self.defaultGroupViewRaw = defaultGroupViewRaw
        self.starClickImmediateSave = starClickImmediateSave
        self.compactRowDensity = compactRowDensity
        self.defaultGroupId = defaultGroupId
        self.visibleGroupIds = visibleGroupIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gatewayURL = try c.decode(String.self, forKey: .gatewayURL)
        apiToken = (try? c.decode(String.self, forKey: .apiToken)) ?? ""
        pollVisibleSec = (try? c.decode(TimeInterval.self, forKey: .pollVisibleSec)) ?? PlannerSettings.default.pollVisibleSec
        pollHiddenSec = (try? c.decode(TimeInterval.self, forKey: .pollHiddenSec)) ?? PlannerSettings.default.pollHiddenSec
        defaultStatusRaw = (try? c.decode(String.self, forKey: .defaultStatusRaw)) ?? PlannerSettings.default.defaultStatusRaw
        immediateOverrideEnabled = (try? c.decode(Bool.self, forKey: .immediateOverrideEnabled)) ?? PlannerSettings.default.immediateOverrideEnabled
        mirrorCLI = (try? c.decode(Bool.self, forKey: .mirrorCLI)) ?? PlannerSettings.default.mirrorCLI
        logLevelRaw = (try? c.decode(String.self, forKey: .logLevelRaw)) ?? PlannerSettings.default.logLevelRaw
        showDoneSection = (try? c.decode(Bool.self, forKey: .showDoneSection)) ?? PlannerSettings.default.showDoneSection
        showWaitingSection = (try? c.decode(Bool.self, forKey: .showWaitingSection)) ?? PlannerSettings.default.showWaitingSection
        defaultSortModeRaw = (try? c.decode(String.self, forKey: .defaultSortModeRaw)) ?? PlannerSettings.default.defaultSortModeRaw
        defaultGroupViewRaw = (try? c.decode(String.self, forKey: .defaultGroupViewRaw)) ?? PlannerSettings.default.defaultGroupViewRaw
        starClickImmediateSave = (try? c.decode(Bool.self, forKey: .starClickImmediateSave)) ?? PlannerSettings.default.starClickImmediateSave
        compactRowDensity = (try? c.decode(Bool.self, forKey: .compactRowDensity)) ?? PlannerSettings.default.compactRowDensity
        defaultGroupId = try? c.decodeIfPresent(String.self, forKey: .defaultGroupId)
        visibleGroupIds = (try? c.decode([String].self, forKey: .visibleGroupIds)) ?? []
    }

    var defaultStatus: TaskStatus {
        TaskStatus(rawValue: defaultStatusRaw) ?? .inbox
    }

    var logLevel: LogLevel {
        LogLevel(rawValue: logLevelRaw) ?? .info
    }

    var defaultSortMode: SortMode {
        SortMode(rawValue: defaultSortModeRaw) ?? .smart
    }

    var defaultGroupView: GroupViewMode {
        GroupViewMode(rawValue: defaultGroupViewRaw) ?? .bucket
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var settings: PlannerSettings

    private let settingsURL: URL

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = appSupport.appendingPathComponent("PlannerCapture", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.settingsURL = appDir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(PlannerSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = PlannerSettings.default
            save()
        }

        PlannerLogger.shared.setMinLevel(settings.logLevel)
    }

    func apply(_ newSettings: PlannerSettings) {
        settings = sanitize(newSettings)
        save()
        PlannerLogger.shared.setMinLevel(settings.logLevel)
        NotificationCenter.default.post(name: .plannerSettingsDidChange, object: nil)
    }

    private func sanitize(_ value: PlannerSettings) -> PlannerSettings {
        var copy = value

        if URL(string: copy.gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
            copy.gatewayURL = PlannerSettings.default.gatewayURL
        }

        copy.pollVisibleSec = max(1, min(copy.pollVisibleSec, 60))
        copy.pollHiddenSec = max(1, min(copy.pollHiddenSec, 120))

        if TaskStatus(rawValue: copy.defaultStatusRaw) == nil {
            copy.defaultStatusRaw = PlannerSettings.default.defaultStatusRaw
        }

        if LogLevel(rawValue: copy.logLevelRaw) == nil {
            copy.logLevelRaw = PlannerSettings.default.logLevelRaw
        }

        if SortMode(rawValue: copy.defaultSortModeRaw) == nil {
            copy.defaultSortModeRaw = PlannerSettings.default.defaultSortModeRaw
        }

        if GroupViewMode(rawValue: copy.defaultGroupViewRaw) == nil {
            copy.defaultGroupViewRaw = PlannerSettings.default.defaultGroupViewRaw
        }

        return copy
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
}
