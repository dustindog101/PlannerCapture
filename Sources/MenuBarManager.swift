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
        popover.contentSize = NSSize(width: 420, height: 540)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuContentView())
        popover.delegate = self

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, self.popover.isShown {
                self.closePopover(sender: event)
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
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PlannerCapture")
                        .font(.headline)
                    Text(store.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(store.isConnected ? .green : .red)
                }
                Spacer()
                Button("Planner") { PlannerWindowController.shared.show() }
                Button("Settings") { SettingsWindowController.shared.show() }
                Button("Refresh") { store.refreshNow() }
            }
            .padding(12)
            .background(.thinMaterial)

            Divider()

            List {
                ForEach(store.sections.prefix(4)) { section in
                    Section(header: Text("\(section.title) (\(section.tasks.count))").font(.subheadline).bold()) {
                        ForEach(section.tasks.prefix(6)) { task in
                            MenuTaskRow(task: task)
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Logs") { PlannerLogger.shared.openLogFile() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(10)
            .background(.thinMaterial)
        }
        .frame(width: 420, height: 540)
        .background(.regularMaterial)
    }
}

private struct MenuTaskRow: View {
    let task: PlannerTask
    @ObservedObject private var store = TaskStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggleTask(id: task.id)
            } label: {
                Image(systemName: task.status == .done ? "arrow.uturn.backward.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(store.isTaskInFlight(task.id))

            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.status == .done)

            Spacer()

            Button {
                store.toggleStar(taskId: task.id)
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
        .padding(.vertical, 2)
    }
}
