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

private struct CaptureDraft {
    var title: String
    var notes: String
    var priority: Int
    var isStarred: Bool
    var statusOverride: TaskStatus?
}

private func parseCaptureInput(_ raw: String) -> CaptureDraft? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return nil }

    var statusOverride: TaskStatus?
    if text.hasPrefix("/done ") {
        statusOverride = .done
        text = String(text.dropFirst(6)).trimmingCharacters(in: .whitespaces)
    } else if text.hasPrefix("/block ") {
        statusOverride = .blocked
        text = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    } else if text.hasPrefix("/inprogress ") {
        statusOverride = .inProgress
        text = String(text.dropFirst(12)).trimmingCharacters(in: .whitespaces)
    }

    var priority = 2
    var isStarred = false

    var bangCount = 0
    while text.hasPrefix("!") {
        bangCount += 1
        text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    if bangCount > 0 {
        priority = min(4, 2 + bangCount)
        isStarred = true
    }

    let tokens = text.split(separator: " ").map(String.init)
    var keptTokens: [String] = []
    for token in tokens {
        let lower = token.lowercased()
        if lower == "#star" || lower == "*" {
            isStarred = true
            continue
        }
        if lower.hasPrefix("#p"), let p = Int(token.dropFirst(2)), (0...4).contains(p) {
            priority = p
            if p >= 3 { isStarred = true }
            continue
        }
        keptTokens.append(token)
    }
    text = keptTokens.joined(separator: " ")

    let parts = text.components(separatedBy: "::")
    let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let notes: String
    if parts.count >= 2 {
        notes = parts.dropFirst().joined(separator: "::").trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        notes = ""
    }

    if title.isEmpty { return nil }
    return CaptureDraft(title: title, notes: notes, priority: priority, isStarred: isStarred, statusOverride: statusOverride)
}

struct FloatingInputView: View {
    @State private var text: String = ""
    var onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            TextField("Capture task… examples: test task  |  ! call mechanic :: ask for rates  |  /done submit form  |  #p4 study", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 22, weight: .regular))
                .padding(.horizontal)
                .padding(.top, 10)
                .focused($isFocused)
                .onSubmit {
                    let parsed = parseCaptureInput(text)
                    if let parsed {
                        TaskStore.shared.addTask(
                            title: parsed.title,
                            notes: parsed.notes,
                            priority: parsed.priority,
                            isStarred: parsed.isStarred,
                            status: parsed.statusOverride,
                            source: "menubar_capture"
                        )
                        PlannerLogger.shared.log(.info, "Capture submitted", metadata: ["title": parsed.title])
                        text = ""
                    }
                    onClose()
                }
                .onAppear {
                    isFocused = true
                }

            Text("Default plain entry goes to Waiting. Shortcuts: !, #p0-#p4, #star, :: notes, /done, /block, /inprogress")
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
