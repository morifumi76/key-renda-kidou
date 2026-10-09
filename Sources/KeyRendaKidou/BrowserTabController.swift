import Foundation
import AppKit

/// 既定ブラウザの「今開いているタブ」のURLを書き換える（AppleScript経由）
/// 初回実行時にmacOSの「オートメーション」許可ダイアログが表示される
enum BrowserTabController {

    /// 今のタブを操作できるブラウザ（バンドルIDは小文字で比較する）
    private enum SupportedBrowser {
        case chrome
        case safari

        init?(bundleID: String) {
            switch bundleID.lowercased() {
            case "com.google.chrome": self = .chrome
            case "com.apple.safari":  self = .safari
            default: return nil
            }
        }

        /// 前面ウィンドウの今のタブを指定URLへ移動するスクリプト
        /// ウィンドウが無いときは "no-window" を返す
        func script(for url: String) -> String {
            let (appID, tabName): (String, String) = switch self {
            case .chrome: ("com.google.Chrome", "active tab")
            case .safari: ("com.apple.Safari", "current tab")
            }
            return """
            tell application id "\(appID)"
                if (count of windows) is 0 then return "no-window"
                set URL of \(tabName) of front window to "\(url)"
                activate
            end tell
            return "ok"
            """
        }
    }

    private static let resultOK = "ok"

    /// AppleScriptは同じスレッドで実行する必要があるため専用キューを使う
    /// （メインスレッドで実行すると許可ダイアログの間キー監視が止まってしまう）
    private static let scriptQueue = DispatchQueue(label: "com.johosauce.key-renda-kidou.browser-tab")

    /// 今のタブでURLを開く。できなかった場合はcompletionにfalseを返す
    static func openInCurrentTab(_ url: URL, completion: @escaping (Bool) -> Void) {
        // Web以外のURL（notion:// など）はタブ操作の対象外
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let browserURL = NSWorkspace.shared.urlForApplication(toOpen: url),
              let bundleID = Bundle(url: browserURL)?.bundleIdentifier,
              let browser = SupportedBrowser(bundleID: bundleID) else {
            completion(false)
            return
        }

        let source = browser.script(for: escapeForAppleScript(url.absoluteString))
        scriptQueue.async {
            let succeeded = runScript(source)
            DispatchQueue.main.async { completion(succeeded) }
        }
    }

    private static func runScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            // 許可されていない場合（エラー -1743）などはここに来る
            NSLog("今のタブでURLを開けませんでした: \(errorInfo)")
            return false
        }
        return result.stringValue == resultOK
    }

    /// AppleScriptの文字列リテラルに埋め込めるようにエスケープする
    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
