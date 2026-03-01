import Foundation
import AppKit

enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug
    case info
    case warn
    case error

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warn: return 2
        case .error: return 3
        }
    }

    var label: String {
        rawValue.uppercased()
    }
}

final class PlannerLogger {
    static let shared = PlannerLogger()

    private let queue = DispatchQueue(label: "plannercapture.logger")
    private let logFileURL: URL
    private var minLevel: LogLevel = .info

    private init() {
        let fm = FileManager.default
        let logsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("PlannerCapture", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

        self.logFileURL = logsDir.appendingPathComponent("plannercapture.log")
        if !fm.fileExists(atPath: logFileURL.path) {
            fm.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    func setMinLevel(_ level: LogLevel) {
        minLevel = level
        log(.info, "Logger level changed", metadata: ["level": level.rawValue])
    }

    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }

    func copyLastErrorContext() {
        guard let data = try? Data(contentsOf: logFileURL),
              let text = String(data: data, encoding: .utf8) else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("No log file available.", forType: .string)
            return
        }

        let lines = text.split(separator: "\n").map(String.init)
        let errorLines = lines.filter { $0.contains("[ERROR]") || $0.contains("[WARN]") }
        let context = errorLines.suffix(12).joined(separator: "\n")
        let value = context.isEmpty ? "No recent warning/error entries found." : context

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        log(.info, "Copied last error context", metadata: ["line_count": "\(errorLines.suffix(12).count)"])
    }

    func log(_ level: LogLevel, _ message: String, metadata: [String: String] = [:]) {
        guard level.rank >= minLevel.rank else { return }

        queue.async {
            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.string(from: Date())
            let metadataString: String
            if metadata.isEmpty {
                metadataString = ""
            } else {
                let pairs = metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
                metadataString = " \(pairs)"
            }
            let line = "[\(timestamp)] [\(level.label)] \(message)\(metadataString)\n"
            guard let data = line.data(using: .utf8) else { return }

            if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }
}
