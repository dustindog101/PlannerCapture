import Foundation

/// Reads version metadata baked into the app bundle by build.sh at compile time.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// Human-readable string for display in UI, e.g. "v3.1.0 (build 42)"
    static var displayVersion: String {
        "v\(version) (build \(build))"
    }
}
