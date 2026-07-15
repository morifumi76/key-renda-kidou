import Foundation
import IOKit.hid
import AppKit

/// キー監視に必要な「入力監視」権限の確認・案内
enum PermissionManager {

    /// 入力監視の権限が付与されているか
    static var hasInputMonitoringPermission: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// 権限をリクエストする（システムのダイアログが表示され、
    /// システム設定の「入力監視」一覧に本アプリが登録される）
    static func requestPermission() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// システム設定の「プライバシーとセキュリティ → 入力監視」を開く
    static func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
