import KeyRendaKidouCore
import SwiftUI
import AppKit

@main
struct KeyRendaKidouApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: appState.iconState.systemImageName)
        }
    }
}

/// メニューバーのメニュー内容
struct MenuContent: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        if !appState.hasPermission {
            Button("⚠️ 入力監視の許可が必要です…") {
                SettingsWindowController.shared.show()
            }
            Divider()
        }

        Toggle("有効にする", isOn: Binding(
            get: { appState.configStore.config.isEnabled },
            set: { appState.setEnabled($0) }
        ))

        Button("設定を開く…") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",")

        Divider()

        Button("key-renda-kidou を終了") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dockに表示しない常駐アプリとして動作させる
        NSApp.setActivationPolicy(.accessory)

        AppState.shared.startup()

        // 権限がない初回起動時はオンボーディングとして設定画面を開く
        if !AppState.shared.hasPermission {
            SettingsWindowController.shared.show()
        }
    }
}
