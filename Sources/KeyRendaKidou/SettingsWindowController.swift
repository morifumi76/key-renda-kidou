import AppKit
import SwiftUI

/// 設定ウィンドウの管理（常駐アプリなので必要なときだけ表示する）
final class SettingsWindowController: NSObject, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let contentView = SettingsView()
                .environmentObject(AppState.shared)
                .environmentObject(AppState.shared.configStore)

            let hosting = NSHostingController(rootView: contentView)
            // SwiftUI側からのウィンドウ自動リサイズを無効化する
            // （表示中のリサイズがmacOSの描画サイクルと衝突してクラッシュするため、サイズはこちらで固定する）
            hosting.sizingOptions = []
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "key-renda-kidou 設定"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.setContentSize(NSSize(width: 680, height: 720))
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // ウィンドウは使い回す（再生成しない）
    }
}
