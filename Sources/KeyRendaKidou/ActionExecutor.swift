import KeyRendaKidouCore
import Foundation
import AppKit

/// 割り当てられたアクションを実行する
enum ActionExecutor {

    static func execute(_ action: KeyAction) {
        switch action.type {
        case .openURL:
            guard let url = URL(string: action.url), action.isValid else {
                NSLog("無効なURLのため開けませんでした: \(action.url)")
                return
            }
            NSWorkspace.shared.open(url)

        case .launchApp:
            let appURL = URL(fileURLWithPath: action.appPath)
            guard FileManager.default.fileExists(atPath: action.appPath) else {
                NSLog("アプリが見つかりませんでした: \(action.appPath)")
                return
            }
            // openApplicationは未起動なら起動、起動中ならアクティブ化してくれる
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    NSLog("アプリの起動に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
}
