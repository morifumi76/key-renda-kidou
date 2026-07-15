import KeyRendaKidouCore
import SwiftUI
import AppKit

@main
struct KeyRendaKidouApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // メニューバーはMenuBarController（NSStatusItem）で自前管理する。
        // SwiftUIのMenuBarExtraは、アイコンをドラッグで取り外した状態がmacOSに記憶されると
        // 起動直後にアプリが終了させられるため使用しない。
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 起動中にFinderやSpotlightからもう一度開かれたら設定画面を表示する
    /// （メニューバーが満杯でアイコンが見えない場合の入り口として機能する）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dockに表示しない常駐アプリとして動作させる
        NSApp.setActivationPolicy(.accessory)

        MenuBarController.shared.setUp()
        AppState.shared.startup()

        // 権限がない初回起動時はオンボーディングとして設定画面を開く
        if !AppState.shared.hasPermission {
            SettingsWindowController.shared.show()
        }
    }
}
