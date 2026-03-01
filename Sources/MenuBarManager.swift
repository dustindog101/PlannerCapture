import SwiftUI
import AppKit

class MenuBarManager: NSObject, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?

    override init() {
        super.init()
        setupMenuBar()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "📋"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 430, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuContentView())
        popover.delegate = self

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strSelf = self, strSelf.popover.isShown {
                strSelf.closePopover(sender: event)
            }
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }

    func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            TaskStore.shared.setFastPolling(true)
            TaskStore.shared.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover(sender: AnyObject?) {
        TaskStore.shared.setFastPolling(false)
        popover.performClose(sender)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var store = TaskStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PlannerCapture")
                        .font(.headline)
                    if store.isConnected {
                        Text("Connected to Daily Helper Hub")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text(store.lastError.isEmpty ? "Waiting for gateway" : store.lastError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button("Refresh") {
                    store.refreshNow()
                }
                Button("Planner") {
                    PlannerWindowController.shared.show()
                }
                Button("Settings") {
                    SettingsWindowController.shared.show()
                }
                Button("Logs") {
                    PlannerLogger.shared.openLogFile()
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .background(.thinMaterial)

            Divider()

            List {
                if store.sections.isEmpty {
                    Section(header: Text("Tasks").font(.subheadline).bold()) {
                        Text("No active tasks")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(store.sections) { section in
                        Section(header: Text("\(section.title) (\(section.tasks.count))").font(.subheadline).bold()) {
                            ForEach(section.tasks) { task in
                                TaskRow(task: task)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 430, height: 560)
        .background(.regularMaterial)
    }
}

private struct TaskRow: View {
    let task: PlannerTask
    @ObservedObject private var store = TaskStore.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: {
                store.toggleTask(id: task.id)
            }) {
                Image(systemName: task.status == .done ? "arrow.uturn.backward.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.isTaskInFlight(task.id))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if task.status == .done {
                        Text("Done")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Button {
                        store.toggleStar(taskId: task.id)
                    } label: {
                        Image(systemName: task.isStarred ? "star.fill" : "star")
                            .foregroundColor(task.isStarred ? .yellow : .secondary)
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isTaskInFlight(task.id))
                    Text(task.title)
                        .strikethrough(task.isDone, color: .gray)
                        .foregroundColor(task.isDone ? .gray : .primary)
                        .lineLimit(2)
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text("\(task.status.rawValue) · p\(task.priority) · \(task.source)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                store.removeTask(id: task.id)
            }) {
                Image(systemName: task.status == .done ? "trash" : "archivebox")
                    .foregroundColor(.red.opacity(task.status == .done ? 1 : 0.85))
                    .imageScale(.small)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.isTaskInFlight(task.id))
        }
        .padding(.vertical, settingsStore.settings.compactRowDensity ? 1 : 3)
    }
}
