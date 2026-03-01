import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let rootView = SettingsView()
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PlannerCapture Settings"
        window.contentView = hosting
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    @State private var gatewayURL: String = ""
    @State private var apiToken: String = ""
    @State private var pollVisibleSec: Double = 3
    @State private var pollHiddenSec: Double = 15
    @State private var defaultStatus: TaskStatus = .inbox
    @State private var immediateOverrideEnabled: Bool = true
    @State private var mirrorCLI: Bool = false
    @State private var logLevel: LogLevel = .info
    @State private var showDoneSection: Bool = true
    @State private var showWaitingSection: Bool = true
    @State private var defaultSortMode: SortMode = .smart
    @State private var defaultGroupView: GroupViewMode = .bucket
    @State private var starClickImmediateSave: Bool = true
    @State private var compactRowDensity: Bool = false
    @State private var defaultGroupId: String = ""
    @State private var visibleGroupIds: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PlannerCapture Settings")
                .font(.headline)

            Form {
                TextField("Gateway URL", text: $gatewayURL)
                SecureField("Gateway API Token (optional)", text: $apiToken)

                HStack {
                    Stepper(value: $pollVisibleSec, in: 1...60, step: 1) {
                        Text("Visible Poll Interval: \(Int(pollVisibleSec))s")
                    }
                }

                HStack {
                    Stepper(value: $pollHiddenSec, in: 1...120, step: 1) {
                        Text("Hidden Poll Interval: \(Int(pollHiddenSec))s")
                    }
                }

                Picker("Default New Task Status", selection: $defaultStatus) {
                    ForEach(TaskStatus.creatableDefaults) { status in
                        Text(status.label).tag(status)
                    }
                }

                Toggle("Immediate override for starred/high priority", isOn: $immediateOverrideEnabled)
                Toggle("Mirror new tasks to planner CLI", isOn: $mirrorCLI)
                Toggle("Show Waiting section", isOn: $showWaitingSection)
                Toggle("Show Done section", isOn: $showDoneSection)
                Toggle("Row star click saves instantly", isOn: $starClickImmediateSave)
                Toggle("Compact row density", isOn: $compactRowDensity)

                Picker("Default Sort", selection: $defaultSortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("Default Group View", selection: $defaultGroupView) {
                    ForEach(GroupViewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                TextField("Default Group ID (optional)", text: $defaultGroupId)
                TextField("Visible Group IDs (comma-separated, optional)", text: $visibleGroupIds)

                Picker("Log Level", selection: $logLevel) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
            }

            HStack {
                Button("Open Logs") {
                    PlannerLogger.shared.openLogFile()
                }
                Button("Copy Last Error") {
                    PlannerLogger.shared.copyLastErrorContext()
                }

                Button("Reload") {
                    loadFromStore()
                }

                Spacer()

                Button("Save") {
                    saveToStore()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onAppear {
            loadFromStore()
        }
    }

    private func loadFromStore() {
        let current = store.settings
        gatewayURL = current.gatewayURL
        apiToken = current.apiToken
        pollVisibleSec = current.pollVisibleSec
        pollHiddenSec = current.pollHiddenSec
        defaultStatus = current.defaultStatus
        immediateOverrideEnabled = current.immediateOverrideEnabled
        mirrorCLI = current.mirrorCLI
        logLevel = current.logLevel
        showDoneSection = current.showDoneSection
        showWaitingSection = current.showWaitingSection
        defaultSortMode = current.defaultSortMode
        defaultGroupView = current.defaultGroupView
        starClickImmediateSave = current.starClickImmediateSave
        compactRowDensity = current.compactRowDensity
        defaultGroupId = current.defaultGroupId ?? ""
        visibleGroupIds = current.visibleGroupIds.joined(separator: ",")
    }

    private func saveToStore() {
        let parsedVisibleGroupIds = visibleGroupIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let newSettings = PlannerSettings(
            gatewayURL: gatewayURL,
            apiToken: apiToken,
            pollVisibleSec: pollVisibleSec,
            pollHiddenSec: pollHiddenSec,
            defaultStatusRaw: defaultStatus.rawValue,
            immediateOverrideEnabled: immediateOverrideEnabled,
            mirrorCLI: mirrorCLI,
            logLevelRaw: logLevel.rawValue,
            showDoneSection: showDoneSection,
            showWaitingSection: showWaitingSection,
            defaultSortModeRaw: defaultSortMode.rawValue,
            defaultGroupViewRaw: defaultGroupView.rawValue,
            starClickImmediateSave: starClickImmediateSave,
            compactRowDensity: compactRowDensity,
            defaultGroupId: defaultGroupId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : defaultGroupId.trimmingCharacters(in: .whitespacesAndNewlines),
            visibleGroupIds: parsedVisibleGroupIds
        )

        store.apply(newSettings)
        TaskStore.shared.applySettings()
        TaskStore.shared.refreshNow()
        PlannerLogger.shared.log(.info, "Settings saved from UI")
    }
}
