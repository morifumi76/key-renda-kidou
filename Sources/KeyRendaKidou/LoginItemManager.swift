import Foundation
import ServiceManagement

/// ログイン時自動起動の登録・解除（macOSのSMAppServiceを利用）
enum LoginItemManager {

    /// .appバンドルとして実行されているときだけ利用できる
    /// （swift run などバイナリ直接実行では登録できない）
    static var isAvailable: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 自動起動のON/OFFを切り替える。成功したらtrue
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("ログイン項目の変更に失敗しました: \(error.localizedDescription)")
            return false
        }
    }
}
