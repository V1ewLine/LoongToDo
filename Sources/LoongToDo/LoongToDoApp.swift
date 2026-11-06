import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Read the current bundle artwork instead of inheriting a cached Dock image.
        if let filename = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let resource = filename.hasSuffix(".icns") ? filename : filename + ".icns"
            if let url = Bundle.main.resourceURL?.appendingPathComponent(resource),
               let icon = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = icon
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil) }
        return true
    }
}

@main
struct LoongToDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AppStore()
    var body: some Scene {
        Window("LoongTodo", id: "main") {
            ContentView(store: store, calendar: store.calendar)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .tint(Style.accent)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建待办") { store.newTodo() }.keyboardShortcut("n")
                Button("新建日程") { store.newEvent() }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .undoRedo) {
                Button("撤销删除待办") { store.undoDelete() }.keyboardShortcut("z", modifiers: [.command, .option]).disabled(!store.canUndoDelete)
            }
        }
    }
}
