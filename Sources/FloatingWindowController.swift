import AppKit
import SwiftUI

class FloatingWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.init(window: panel)
        panel.delegate = self

        let hostingView = EventInterceptingHostingView(rootView: FloatingInputView(onClose: { [weak self] in
            self?.closePanel()
        }))
        hostingView.onEscape = { [weak self] in
            self?.closePanel()
        }

        panel.contentView = hostingView
        panel.center()
    }

    func toggle() {
        guard let panel = window as? FloatingPanel else { return }
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let panel = window as? FloatingPanel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePanel() {
        guard let panel = window as? FloatingPanel else { return }
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }
}

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
    }
}

class EventInterceptingHostingView<Content: View>: NSHostingView<Content> {
    var onEscape: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            onEscape?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct FloatingInputView: View {
    @State private var text: String = ""
    var onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            TextField("Capture task… examples: !call mechanic|5m  |  task :: notes  |  /done submit  |  #p4 study  |  task due:1h", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 22, weight: .regular))
                .padding(.horizontal)
                .padding(.top, 10)
                .focused($isFocused)
                .onSubmit {
                    let parsed = parseCaptureInput(text)
                    if let parsed {
                        let groupId: String?
                        if let requestedGroup = parsed.groupName {
                            if let group = TaskStore.shared.groups.first(where: { $0.name.caseInsensitiveCompare(requestedGroup) == .orderedSame }) {
                                groupId = group.id
                            } else {
                                groupId = nil
                                PlannerLogger.shared.log(.warn, "Unknown capture group token; creating ungrouped task", metadata: ["group": requestedGroup])
                            }
                        } else {
                            groupId = nil
                        }
                        TaskStore.shared.addTask(
                            title: parsed.title,
                            notes: parsed.notes,
                            priority: parsed.priority,
                            isStarred: parsed.isStarred,
                            status: parsed.statusOverride,
                            source: "menubar_capture",
                            groupId: groupId,
                            dueAt: parsed.dueAt
                        )
                        PlannerLogger.shared.log(.info, "Capture submitted", metadata: ["title": parsed.title])
                        text = ""
                    }
                    onClose()
                }
                .onAppear {
                    isFocused = true
                }

            Text("Shortcuts: !, #p0-#p4, #star, #g:<group>, :: notes, |5m or due:1h, /done, /todo, /inbox, /blocked, /inprogress, /archived")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
