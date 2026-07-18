import KeyRendaKidouCore
import Foundation
import Combine
import AppKit

/// メニューバーアイコンの表示状態
enum MenuBarIconState {
    case normal      // 監視中
    case disabled    // 無効化中
    case warning     // 権限なし
    case fired       // アクション発動直後（一瞬だけ表示）

    var systemImageName: String {
        switch self {
        case .normal:   return "keyboard.fill"
        case .disabled: return "keyboard"
        case .warning:  return "exclamationmark.triangle.fill"
        case .fired:    return "bolt.fill"
        }
    }
}

/// アプリ全体の状態と各コンポーネントの橋渡しを行うクラス
final class AppState: ObservableObject {

    static let shared = AppState()

    let configStore = ConfigStore()
    let detector = KnockDetector()
    private(set) lazy var monitor = EventTapMonitor(detector: detector)

    @Published var iconState: MenuBarIconState = .normal
    @Published var hasPermission: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var permissionPollTimer: Timer?
    private var flashWorkItem: DispatchWorkItem?

    private init() {
        // 設定変更を判定エンジンへ即時反映する
        configStore.$config
            .sink { [weak self] config in
                self?.apply(config: config)
            }
            .store(in: &cancellables)

        // 発動時の処理
        detector.onFire = { [weak self] key in
            self?.fire(key)
        }

        // スリープ復帰後にタップと押下追跡を復旧させる
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.monitor.reviveIfNeeded()
        }

        // 画面ロック解除後も復旧させる
        // （ロック中はパスワード入力イベントが届かず、押下追跡が狂うことがあるため）
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.monitor.reviveIfNeeded()
        }
    }

    /// アプリ起動時に呼ぶ
    func startup() {
        // 設定上は自動起動ONなのにOSに未登録なら登録し直す
        // （バンドルID変更などで登録が外れた場合の自動復旧）
        if configStore.config.launchAtLogin,
           LoginItemManager.isAvailable,
           !LoginItemManager.isRegistered {
            LoginItemManager.setEnabled(true)
        }

        hasPermission = PermissionManager.hasInputMonitoringPermission
        if hasPermission {
            startMonitoring()
        } else {
            // システム設定の「入力監視」一覧に本アプリを載せるためリクエストしておく。
            // さらにイベントタップ生成も一度試みる（失敗しても、この試行が
            // 一覧への登録トリガーになる。リクエストAPIだけでは載らない場合がある）
            PermissionManager.requestPermission()
            _ = monitor.start()
            iconState = .warning
            startPermissionPolling()
        }
    }

    // MARK: - 監視制御

    private func startMonitoring() {
        let started = monitor.start()
        if started {
            apply(config: configStore.config)
            stopPermissionPolling()
        } else {
            // タップ生成失敗＝権限なしとみなす
            hasPermission = false
            iconState = .warning
            startPermissionPolling()
        }
    }

    /// 有効/無効の切り替え（メニューバーから呼ばれる）
    func setEnabled(_ enabled: Bool) {
        configStore.config.isEnabled = enabled
    }

    private func apply(config: AppConfig) {
        // 割り当てを判定エンジンに反映
        var required: [MonitoredKey: Int] = [:]
        for key in MonitoredKey.allCases {
            if let binding = config.binding(for: key), binding.action.isValid {
                required[key] = binding.trigger.rawValue
            }
        }
        detector.requiredKnocks = required
        detector.knockInterval = config.knockInterval

        // 有効/無効を反映
        if monitor.isRunning {
            monitor.setPaused(!config.isEnabled)
        }
        updateIcon()
    }

    private func updateIcon() {
        if !hasPermission {
            iconState = .warning
        } else if !configStore.config.isEnabled {
            iconState = .disabled
        } else {
            iconState = .normal
        }
    }

    // MARK: - 発動

    private func fire(_ key: MonitoredKey) {
        guard configStore.config.isEnabled,
              let binding = configStore.config.binding(for: key) else { return }
        ActionExecutor.execute(binding.action)
        flashIcon()
    }

    /// 発動フィードバック：メニューバーアイコンを一瞬変化させる
    private func flashIcon() {
        flashWorkItem?.cancel()
        iconState = .fired
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateIcon()
        }
        flashWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    // MARK: - 権限の監視

    /// 権限が付与されるまで定期的にチェックする
    private func startPermissionPolling() {
        guard permissionPollTimer == nil else { return }
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = PermissionManager.hasInputMonitoringPermission
            if granted != self.hasPermission {
                self.hasPermission = granted
                if granted {
                    self.startMonitoring()
                    self.updateIcon()
                }
            }
        }
    }

    private func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }
}
