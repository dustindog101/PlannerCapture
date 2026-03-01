import AppKit
import SwiftUI

final class PlannerWindowController: NSWindowController {
    static let shared = PlannerWindowController()

    private init() {
        let rootView = PlannerManagerView()
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PlannerCapture Manager"
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

private struct PlannerManagerView: View {
    @ObservedObject private var store = TaskStore.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var selectedSectionId: String?
    @State private var selectedTaskId: String?
    @State private var draft: TaskEditDraft?
    @State private var lastLoadedTaskId: String?
    @State private var isDirty: Bool = false
    @State private var saveMessage: String = ""
    @State private var debounceWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                taskList
                Divider()
                editorPanel
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(.regularMaterial)
        .onAppear {
            pickDefaultSectionIfNeeded()
            syncDraftToSelection()
        }
        .onChange(of: store.sections) {
            pickDefaultSectionIfNeeded()
            syncDraftToSelection()
        }
        .onChange(of: selectedSectionId) {
            pickTaskForSelectedSectionIfNeeded()
            syncDraftToSelection()
        }
        .onChange(of: selectedTaskId) {
            syncDraftToSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Planner Manager")
                .font(.title3)
                .fontWeight(.semibold)
            Circle()
                .fill(store.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(store.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
            if let lastSyncAt = store.lastSyncAt {
                Text("Last sync: \(relativeDate(lastSyncAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !saveMessage.isEmpty {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button("Refresh") {
                saveMessage = ""
                store.refreshNow()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var sidebar: some View {
        List(selection: Binding(
            get: { selectedSectionId },
            set: { raw in selectedSectionId = raw }
        )) {
            ForEach(store.sections) { section in
                HStack {
                    Text(section.title)
                    Spacer()
                    Text("\(section.tasks.count)")
                        .foregroundColor(.secondary)
                }
                .tag(section.id)
            }
        }
        .frame(minWidth: 170, idealWidth: 200, maxWidth: 220)
        .listStyle(.sidebar)
        .background(.thinMaterial)
    }

    private var taskList: some View {
        List(selection: $selectedTaskId) {
            ForEach(currentSectionTasks()) { task in
                HStack(spacing: 8) {
                    Button(action: {
                        store.toggleTask(id: task.id)
                    }) {
                        Image(systemName: task.status == .done ? "arrow.uturn.backward.circle.fill" : "circle")
                            .foregroundColor(task.status == .done ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isTaskInFlight(task.id))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .lineLimit(2)
                            .strikethrough(task.status == .done)
                        Text(task.status.label + " · p\(task.priority)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        if settingsStore.settings.starClickImmediateSave {
                            store.toggleStar(taskId: task.id)
                        } else {
                            selectedTaskId = task.id
                            draft = TaskEditDraft(task: task)
                            draft?.isStarred.toggle()
                            isDirty = true
                        }
                    } label: {
                        Image(systemName: task.isStarred ? "star.fill" : "star")
                            .foregroundColor(task.isStarred ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isTaskInFlight(task.id))
                }
                .tag(task.id)
                .padding(.vertical, settingsStore.settings.compactRowDensity ? 1 : 4)
            }
        }
        .frame(minWidth: 300, idealWidth: 350, maxWidth: 380)
        .background(.thinMaterial)
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task Details")
                .font(.headline)

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
                        ForEach(0..<5) { priority in
                            Text("P\(priority)").tag(priority)
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
                                get: { self.dateFromUnix(self.draft?.dueAt) ?? Date() },
                                set: { value in
                                    self.draft?.dueAt = Int(value.timeIntervalSince1970)
                                    scheduleDirtyCheck(task: task)
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                HStack {
                    Button("Archive") {
                        saveMessage = ""
                        store.removeTask(id: task.id)
                    }
                    .disabled(store.isTaskInFlight(task.id))

                    Button("Undo Done") {
                        saveMessage = ""
                        if task.status == .done {
                            store.toggleTask(id: task.id)
                        }
                    }
                    .disabled(store.isTaskInFlight(task.id) || task.status != .done)

                    Spacer()

                    Button("Save") {
                        saveMessage = ""
                        saveDraft(task: task)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.isTaskInFlight(task.id) || !isDirty)
                }
            } else {
                Text("Select a task from a section to edit.")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }

    private func pickDefaultSectionIfNeeded() {
        if selectedSectionId == nil || store.sections.first(where: { $0.id == selectedSectionId }) == nil {
            selectedSectionId = store.sections.first?.id
        }
        pickTaskForSelectedSectionIfNeeded()
    }

    private func pickTaskForSelectedSectionIfNeeded() {
        let sectionTasks = currentSectionTasks()
        if selectedTaskId == nil || sectionTasks.first(where: { $0.id == selectedTaskId }) == nil {
            selectedTaskId = sectionTasks.first?.id
        }
    }

    private func currentSectionTasks() -> [PlannerTask] {
        guard let selectedSectionId else { return [] }
        return store.sections.first(where: { $0.id == selectedSectionId })?.tasks ?? []
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
            dueAt: draft.dueAt
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
                case .failure:
                    saveMessage = "Save failed. Check logs."
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func dateFromUnix(_ value: Int?) -> Date? {
        guard let value else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }
}
