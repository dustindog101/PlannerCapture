import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let rootView = SettingsView()
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case views
    case sync
    case diagnostics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .views: return "Views"
        case .sync: return "Sync"
        case .diagnostics: return "Diagnostics"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    @State private var selectedTab: SettingsTab = .general

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
    @State private var newUIEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PlannerCapture Settings")
                    .font(.headline)
                Spacer()
                Picker("", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
                .labelsHidden()
            }
            .padding(14)
            .background(.thinMaterial)

            Divider()

            Group {
                switch selectedTab {
                case .general: generalTab
                case .views: viewsTab
                case .sync: syncTab
                case .diagnostics: diagnosticsTab
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack {
                Button("Reload") {
                    loadFromStore()
                }
                Spacer()
                Button("Save") {
                    saveToStore()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(.thinMaterial)
        }
        .background(.regularMaterial)
        .onAppear {
            loadFromStore()
        }
    }

    private var generalTab: some View {
        Form {
            Toggle("Enable remodeled planner UI", isOn: $newUIEnabled)
            Picker("Default new task status", selection: $defaultStatus) {
                ForEach(TaskStatus.creatableDefaults) { status in
                    Text(status.label).tag(status)
                }
            }
            Toggle("Immediate override for starred/high priority", isOn: $immediateOverrideEnabled)
            Toggle("Mirror new tasks to planner CLI", isOn: $mirrorCLI)
        }
    }

    private var viewsTab: some View {
        Form {
            Toggle("Show Waiting section", isOn: $showWaitingSection)
            Toggle("Show Done section", isOn: $showDoneSection)
            Toggle("Star click saves instantly", isOn: $starClickImmediateSave)
            Toggle("Compact row density", isOn: $compactRowDensity)

            Picker("Default sort", selection: $defaultSortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Picker("Default group view", selection: $defaultGroupView) {
                ForEach(GroupViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        }
    }

    private var syncTab: some View {
        Form {
            TextField("Gateway URL", text: $gatewayURL)
            SecureField("Gateway API token (optional)", text: $apiToken)

            Stepper(value: $pollVisibleSec, in: 1...60, step: 1) {
                Text("Visible poll interval: \(Int(pollVisibleSec))s")
            }
            Stepper(value: $pollHiddenSec, in: 1...120, step: 1) {
                Text("Hidden poll interval: \(Int(pollHiddenSec))s")
            }

            TextField("Default group ID (optional)", text: $defaultGroupId)
            TextField("Visible group IDs (comma-separated)", text: $visibleGroupIds)
        }
    }

    private var diagnosticsTab: some View {
        Form {
            Picker("Log level", selection: $logLevel) {
                ForEach(LogLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }

            HStack {
                Button("Open logs") {
                    PlannerLogger.shared.openLogFile()
                }
                Button("Copy last error") {
                    PlannerLogger.shared.copyLastErrorContext()
                }
            }
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
        newUIEnabled = current.newUIEnabled
    }

    private func saveToStore() {
        let parsedVisibleGroupIds = visibleGroupIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleanDefaultGroupId = defaultGroupId.trimmingCharacters(in: .whitespacesAndNewlines)

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
            defaultGroupId: cleanDefaultGroupId.isEmpty ? nil : cleanDefaultGroupId,
            visibleGroupIds: parsedVisibleGroupIds,
            newUIEnabled: newUIEnabled
        )

        store.apply(newSettings)
        TaskStore.shared.applySettings()
        TaskStore.shared.refreshNow()
        PlannerLogger.shared.log(.info, "Settings saved from UI")
    }
}
