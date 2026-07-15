import Foundation

/// トリガー種別（2回押し or 3回押しの択一）
public enum TriggerCount: Int, Codable, CaseIterable, Identifiable {
    case double = 2
    case triple = 3

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .double: return "2回押し"
        case .triple: return "3回押し"
        }
    }
}

/// アクション種別
public enum ActionType: String, Codable, CaseIterable, Identifiable {
    case openURL
    case launchApp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openURL:   return "URLを開く"
        case .launchApp: return "アプリを起動"
        }
    }
}

/// キーに割り当てるアクション
public struct KeyAction: Codable, Equatable {
    public var type: ActionType
    /// type == .openURL のときのURL文字列
    public var url: String
    /// type == .launchApp のときのアプリのフルパス（例: /Applications/Safari.app）
    public var appPath: String
    /// 表示用のアプリ名
    public var appName: String

    public init(type: ActionType = .openURL, url: String = "", appPath: String = "", appName: String = "") {
        self.type = type
        self.url = url
        self.appPath = appPath
        self.appName = appName
    }

    /// アクションとして実行可能な状態か
    public var isValid: Bool {
        switch type {
        case .openURL:
            return KeyAction.isValidURL(url)
        case .launchApp:
            return !appPath.isEmpty && FileManager.default.fileExists(atPath: appPath)
        }
    }

    /// URL形式のバリデーション（スキーム＋ホストがあるURLのみ許可）
    public static func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "http" || scheme == "https" {
            return url.host != nil
        }
        // notion:// などのカスタムスキームも許可する
        return true
    }
}

/// 1キー分の割り当て（トリガー＋アクション）
public struct KeyBinding: Codable, Equatable {
    public var trigger: TriggerCount
    public var action: KeyAction

    public init(trigger: TriggerCount = .double, action: KeyAction = KeyAction()) {
        self.trigger = trigger
        self.action = action
    }
}

/// アプリ全体の設定（JSONファイル1個に保存）
public struct AppConfig: Codable, Equatable {
    /// ノックと判定する間隔（秒）
    public var knockInterval: Double
    /// キー監視の有効/無効
    public var isEnabled: Bool
    /// ログイン時自動起動
    public var launchAtLogin: Bool
    /// キーごとの割り当て（キーはMonitoredKeyのrawValue）
    public var bindings: [String: KeyBinding]

    public static let defaultKnockInterval = 0.3
    public static let minKnockInterval = 0.2
    public static let maxKnockInterval = 0.5

    public init(
        knockInterval: Double = AppConfig.defaultKnockInterval,
        isEnabled: Bool = true,
        launchAtLogin: Bool = false,
        bindings: [String: KeyBinding] = [:]
    ) {
        self.knockInterval = knockInterval
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin
        self.bindings = bindings
    }

    public func binding(for key: MonitoredKey) -> KeyBinding? {
        bindings[key.rawValue]
    }

    public mutating func setBinding(_ binding: KeyBinding?, for key: MonitoredKey) {
        bindings[key.rawValue] = binding
    }
}
