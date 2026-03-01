import Foundation
import UserNotifications

class CLIWrapper {
    static let shared = CLIWrapper()
    
    func addTask(_ text: String) {
        // Execute planner directly with arguments to avoid shell injection.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["planner", "add", text]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                showNotification(message: "✅ Added: \(text)")
            } else {
                showNotification(message: "❌ Failed: \(text)")
            }
        } catch {
            print("Failed to run planner CLI: \(error)")
            showNotification(message: "❌ Failed: \(text)")
        }
    }
    
    func showNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "PlannerCapture"
        content.body = message
        
        // Show notification
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
}
