import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var menuBarManager: MenuBarManager?
    var floatingWindowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = SettingsStore.shared
        PlannerLogger.shared.log(.info, "PlannerCapture launched")

        // Request notification permission for the tiny ✅ notification
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        UNUserNotificationCenter.current().delegate = self
        
        menuBarManager = MenuBarManager()
        floatingWindowController = FloatingWindowController()
        
        // Register global hotkey cmd+shift+space (Key code 49)
        GlobalHotkey.shared.register(keyCode: 49, modifiers: [.command, .shift]) {
            self.floatingWindowController?.toggle()
        }
    }
    
    // Allows notifications to show even if the app gets focus
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct PlannerCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
