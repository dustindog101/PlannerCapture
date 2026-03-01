import AppKit
import SwiftUI

final class PlannerWindowController: NSWindowController {
    static let shared = PlannerWindowController()

    private init() {
        let rootView = PlannerRootView()
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PlannerCapture"
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

private enum PlannerPage: String, CaseIterable, Identifiable {
    case tasks
    case groups
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tasks: return "Tasks"
        case .groups: return "Groups"
        case .settings: return "Settings"
        }
    }
}

private struct PlannerRootView: View {
    @ObservedObject private var settingsStore = SettingsStore.shared

    var body: some View {
        if settingsStore.settings.newUIEnabled {
            PlannerModernView()
        } else {
            PlannerLegacyView()
        }
    }
}

private struct PlannerModernView: View {
    @ObservedObject private var store = TaskStore.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var selectedPage: PlannerPage = .tasks
    @State private var selectedSectionId: String?
    @State private var selectedTaskId: String?
    @State private var draft: TaskEditDraft?
    @State private var lastLoadedTaskId: String?
    @State private var isDirty: Bool = false
    @State private var saveMessage: String = ""
    @State private var moveMessage: String = ""
    @State private var newGroupName: String = ""
    @State private var groupMessage: String = ""
    @State private var groupDraftNames: [String: String] = [:]
    @State private var searchText: String = ""
    @State private var debounceWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 10) {
            header
            switch selectedPage {
            case .tasks:
                tasksPage
            case .groups:
                groupsPage
            case .settings:
                settingsPage
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .onAppear {
            if selectedSectionId == nil {
                selectedSectionId = store.sections.first?.id
            }
            if selectedTaskId == nil {
                selectedTaskId = currentTasks().first?.id
            }
            syncDraftToSelection()
        }
        .onChange(of: store.sections) {
            let previousSectionId = selectedSectionId
            if selectedSectionId == nil || store.sections.first(where: { $0.id == selectedSectionId }) == nil {
                selectedSectionId = store.sections.first?.id
            }
            if let selectedTaskId,
               let destination = sectionContaining(taskId: selectedTaskId),
               destination.id != previousSectionId {
                selectedSectionId = destination.id
                moveMessage = "Moved to \(destination.title)."
            }
            if selectedTaskId == nil || store.task(id: selectedTaskId ?? "") == nil {
                selectedTaskId = currentTasks().first?.id
            }
            syncDraftToSelection()
        }
        .onChange(of: selectedSectionId) {
            if selectedTaskId == nil || currentTasks().first(where: { $0.id == selectedTaskId }) == nil {
                selectedTaskId = currentTasks().first?.id
            }
            syncDraftToSelection()
        }
        .onChange(of: store.groups) {
            var copy = groupDraftNames
            for group in store.groups where copy[group.id] == nil {
                copy[group.id] = group.name
            }
            groupDraftNames = copy
        }
        .onChange(of: selectedTaskId) {
            syncDraftToSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("PlannerCapture")
                .font(.title3.weight(.semibold))

            Circle()
                .fill(store.isConnected ? Color.green : Color.red)
                .frame(width: 9, height: 9)

            Text(store.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(summaryLine)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Picker("", selection: $selectedPage) {
                ForEach(PlannerPage.allCases) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            Spacer()

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Button("Refresh") { store.refreshNow() }
            Button("Settings") { SettingsWindowController.shared.show() }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppearanceTokens.paneCornerRadius, style: .continuous))
    }

    private var tasksPage: some View {
        HStack(spacing: 10) {
            PaneContainer(material: .thinMaterial) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sections")
                        .font(.headline)
                    ForEach(store.sections) { section in
                        Button {
                            selectedSectionId = section.id
                        } label: {
                            HStack {
                                Text(section.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(section.tasks.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedSectionId == section.id ? Color.accentColor.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .frame(minWidth: 220, maxWidth: 240)

            PaneContainer(material: .regularMaterial) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeaderChip(title: selectedSection()?.title ?? "Tasks", count: filteredTasks(currentTasks()).count)

                    if filteredTasks(currentTasks()).isEmpty {
                        Text("No tasks in this section")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    } else {
                        List(selection: $selectedTaskId) {
                            ForEach(filteredTasks(currentTasks())) { task in
                                taskRow(task)
                                    .tag(task.id)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
            }

            PaneContainer(material: .ultraThinMaterial) {
                inspector
            }
            .frame(minWidth: 320, maxWidth: 360)
        }
    }

    private var groupsPage: some View {
        HStack(spacing: 10) {
            PaneContainer(material: .thinMaterial) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Manage Groups")
                        .font(.headline)

                    HStack {
                        TextField("New group name", text: $newGroupName)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            store.createGroup(name: name) { result in
                                switch result {
                                case .success:
                                    groupMessage = "Group added."
                                    newGroupName = ""
                                case .failure:
                                    groupMessage = "Failed to add group."
                                }
                            }
                        }
                    }

                    if !groupMessage.isEmpty {
                        Text(groupMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    List {
                        ForEach(store.groups) { group in
                            HStack {
                                TextField("Group name", text: Binding(
                                    get: { groupDraftNames[group.id] ?? group.name },
                                    set: { groupDraftNames[group.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Spacer()
                                Button("Rename") {
                                    let nextName = (groupDraftNames[group.id] ?? group.name).trimmingCharacters(in: .whitespacesAndNewlines)
                                    store.renameGroup(groupId: group.id, name: nextName) { result in
                                        switch result {
                                        case .success:
                                            groupMessage = "Group renamed."
                                        case .failure:
                                            groupMessage = "Failed to rename group."
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                Button("Remove") {
                                    store.removeGroup(groupId: group.id) { result in
                                        switch result {
                                        case .success:
                                            groupMessage = "Group removed."
                                        case .failure:
                                            groupMessage = "Failed to remove group."
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.inset)
                }
            }

            PaneContainer(material: .regularMaterial) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How Groups Work")
                        .font(.headline)
                    Text("Groups help you separate school, personal, and project tasks. Add groups here, then assign them from the task inspector.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var settingsPage: some View {
        SettingsView()
    }

    private func taskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 8) {
            Button {
                store.toggleTask(id: task.id)
            } label: {
                Image(systemName: task.status == .done ? "arrow.uturn.backward.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(store.isTaskInFlight(task.id))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .strikethrough(task.status == .done)
                Text("\(task.status.label) · p\(task.priority)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if selectedTaskId == task.id {
                    draft?.isStarred.toggle()
                    isDirty = (draft?.isDifferent(from: task) ?? false)
                }
                store.toggleStar(taskId: task.id) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let value):
                            if selectedTaskId == task.id {
                                draft?.isStarred = value
                                if let refreshed = store.task(id: task.id) {
                                    isDirty = (draft?.isDifferent(from: refreshed) ?? false)
                                }
                            }
                        case .failure:
                            if selectedTaskId == task.id {
                                draft?.isStarred = task.isStarred
                                isDirty = false
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: task.isStarred ? "star.fill" : "star")
                    .foregroundColor(task.isStarred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.isTaskInFlight(task.id))

            Button {
                store.removeTask(id: task.id)
            } label: {
                Image(systemName: "archivebox")
                    .foregroundColor(.red.opacity(0.9))
            }
            .buttonStyle(.plain)
            .disabled(store.isTaskInFlight(task.id))
        }
        .padding(.vertical, settingsStore.settings.compactRowDensity ? AppearanceTokens.rowVerticalCompact : AppearanceTokens.rowVerticalRegular)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
                if isDirty { StatusBadgeChip(label: "Unsaved") }
            }

            if let task = selectedTask(), let draft {
                Form {
                    TextField("Title", text: Binding(
                        get: { draft.title },
                        set: { value in
                            self.draft?.title = value
                            scheduleDirtyCheck(task: task)
                        }
                    ))

                    TextEditor(text: Binding(
                        get: { draft.notes },
                        set: { value in
                            self.draft?.notes = value
                            scheduleDirtyCheck(task: task)
                        }
                    ))
                    .frame(minHeight: 90)

                    Picker("Status", selection: Binding(
                        get: { draft.status },
                        set: { value in
                            self.draft?.status = value
                            scheduleDirtyCheck(task: task)
                        }
                    )) {
                        ForEach(TaskStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }

                    Picker("Priority", selection: Binding(
                        get: { draft.priority },
                        set: { value in
                            self.draft?.priority = value
                            scheduleDirtyCheck(task: task)
                        }
                    )) {
                        ForEach(0..<5) { p in
                            Text("P\(p)").tag(p)
                        }
                    }

                    Picker("Group", selection: Binding(
                        get: { draft.groupId ?? "ungrouped" },
                        set: { value in
                            self.draft?.groupId = value == "ungrouped" ? nil : value
                            scheduleDirtyCheck(task: task)
                        }
                    )) {
                        Text("Ungrouped").tag("ungrouped")
                        ForEach(store.groups) { group in
                            Text(group.name).tag(group.id)
                        }
                    }

                    Toggle("Starred", isOn: Binding(
                        get: { draft.isStarred },
                        set: { value in
                            self.draft?.isStarred = value
                            scheduleDirtyCheck(task: task)
                        }
                    ))

                    TextField("Source reference", text: Binding(
                        get: { draft.sourceRef },
                        set: { value in
                            self.draft?.sourceRef = value
                            scheduleDirtyCheck(task: task)
                        }
                    ))

                    Toggle("Has due date", isOn: Binding(
                        get: { draft.dueAt != nil },
                        set: { enabled in
                            self.draft?.dueAt = enabled ? (self.draft?.dueAt ?? Int(Date().timeIntervalSince1970)) : nil
                            scheduleDirtyCheck(task: task)
                        }
                    ))

                    if draft.dueAt != nil {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { dateFromUnix(self.draft?.dueAt) ?? Date() },
                                set: { value in
                                    self.draft?.dueAt = Int(value.timeIntervalSince1970)
                                    scheduleDirtyCheck(task: task)
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Updated: \(absoluteDate(unix: task.updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Task ID: \(task.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Button("Reset") {
                        self.draft = TaskEditDraft(task: task)
                        self.isDirty = false
                        self.saveMessage = ""
                        self.moveMessage = ""
                    }
                    Spacer()
                    if !saveMessage.isEmpty {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !moveMessage.isEmpty {
                        Text(moveMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Button("Save") {
                        saveDraft(task: task)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.isTaskInFlight(task.id) || !isDirty)
                }
            } else {
                Text("Select a task to edit.")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func selectedSection() -> TaskSection? {
        guard let selectedSectionId else { return store.sections.first }
        return store.sections.first(where: { $0.id == selectedSectionId })
    }

    private func currentTasks() -> [PlannerTask] {
        selectedSection()?.tasks ?? []
    }

    private func filteredTasks(_ tasks: [PlannerTask]) -> [PlannerTask] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tasks }
        return tasks.filter { $0.title.lowercased().contains(query) || $0.notes.lowercased().contains(query) }
    }

    private func selectedTask() -> PlannerTask? {
        guard let selectedTaskId else { return nil }
        return store.task(id: selectedTaskId)
    }

    private func syncDraftToSelection() {
        guard let task = selectedTask() else {
            draft = nil
            lastLoadedTaskId = nil
            isDirty = false
            return
        }
        if lastLoadedTaskId != task.id || draft == nil {
            draft = TaskEditDraft(task: task)
            lastLoadedTaskId = task.id
            isDirty = false
        } else if let draft {
            isDirty = draft.isDifferent(from: task)
            if !isDirty {
                self.draft = TaskEditDraft(task: task)
            }
        }
    }

    private func scheduleDirtyCheck(task: PlannerTask) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem {
            guard let draft else { return }
            isDirty = draft.isDifferent(from: task)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func saveDraft(task: PlannerTask) {
        guard let draft else { return }
        let normalized = TaskEditDraft(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: draft.notes,
            status: draft.status,
            priority: draft.priority,
            isStarred: draft.isStarred,
            groupId: draft.groupId,
            dueAt: draft.dueAt,
            sourceRef: draft.sourceRef
        )
        guard !normalized.title.isEmpty else {
            saveMessage = "Title cannot be empty."
            return
        }

        store.saveTaskEdits(taskId: task.id, draft: normalized) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    saveMessage = "Saved."
                    if let destination = sectionContaining(taskId: task.id) {
                        selectedSectionId = destination.id
                        moveMessage = "Moved to \(destination.title)."
                    }
                case .failure:
                    saveMessage = "Save failed."
                }
            }
        }
    }

    private var summaryLine: String {
        let waiting = store.tasks.filter { $0.status == .inbox }.count
        let done = store.tasks.filter { $0.status == .done }.count
        let active = store.tasks.filter { $0.status != .done && $0.status != .archived }.count
        return "Active \(active) · Waiting \(waiting) · Done \(done) · Groups \(store.groups.count)"
    }

    private func sectionContaining(taskId: String) -> TaskSection? {
        store.sections.first(where: { section in
            section.tasks.contains(where: { $0.id == taskId })
        })
    }

    private func absoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func absoluteDate(unix: Int) -> String {
        absoluteDate(Date(timeIntervalSince1970: TimeInterval(unix)))
    }

    private func dateFromUnix(_ value: Int?) -> Date? {
        guard let value else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }
}

private struct PlannerLegacyView: View {
    @ObservedObject private var store = TaskStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Legacy Planner View")
                    .font(.headline)
                Spacer()
                Button("Enable New UI") {
                    var settings = SettingsStore.shared.settings
                    settings.newUIEnabled = true
                    SettingsStore.shared.apply(settings)
                    TaskStore.shared.applySettings()
                }
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            List {
                ForEach(store.sections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.tasks) { task in
                            Text(task.title)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }
}
