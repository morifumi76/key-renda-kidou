import Foundation

/// ノック判定エンジン（本アプリの心臓部）
///
/// 「ノック」＝対象キーを単独で押して離すこと。以下はノックとして数えない：
/// - 他のキーと組み合わせて押した場合（⌘C→⌘Vなど）→ カウントをリセット
/// - 長押し（一定時間以上の押しっぱなし）
/// - ノック間隔（knockInterval）を超えて押した場合 → 1回目から数え直し
///
/// このクラスはOSイベントに依存しない純粋な状態機械として実装し、
/// テストランナー（swift run knock-tests）で誤発動がないことを検証できるようにしている。
public final class KnockDetector {

    /// ノックと判定する間隔（秒）。前のノックのキーを離してから次に押すまでの許容時間
    public var knockInterval: TimeInterval = AppConfig.defaultKnockInterval

    /// これより長い押しっぱなしは「長押し」としてノックに数えない（秒）
    public let maxHoldDuration: TimeInterval = 0.5

    /// キーごとの必要ノック回数（2 or 3）。登録がないキーは発動しない
    public var requiredKnocks: [MonitoredKey: Int] = [:]

    /// 規定回数のノックが完了したときに呼ばれる
    public var onFire: ((MonitoredKey) -> Void)?

    public init() {}

    /// 押下中のキーの状態
    private struct HeldState {
        let downTime: TimeInterval
        /// 押下中に他のキー操作が混ざったらtrue（ノック無効）
        var contaminated: Bool
    }

    /// 現在押下中の対象キー
    private var held: [MonitoredKey: HeldState] = [:]
    /// キーごとの連打カウント（count, 最後に離した時刻）
    private var counts: [MonitoredKey: (count: Int, lastUpTime: TimeInterval)] = [:]

    // MARK: - イベント入力

    /// 対象キーが押された
    public func monitoredKeyDown(_ key: MonitoredKey, at time: TimeInterval) {
        if held.isEmpty {
            held[key] = HeldState(downTime: time, contaminated: false)
        } else {
            // 別の対象キーを押しながらの操作（⌘⇧など）は組み合わせ扱い → 全て無効化
            contaminateAllHeld()
            resetAllCounts()
            held[key] = HeldState(downTime: time, contaminated: true)
        }
    }

    /// 対象キーが離された
    public func monitoredKeyUp(_ key: MonitoredKey, at time: TimeInterval) {
        guard let state = held.removeValue(forKey: key) else { return }

        // 組み合わせ押しはノックにしない
        if state.contaminated {
            counts[key] = nil
            return
        }
        // 長押しはノックにしない
        if time - state.downTime > maxHoldDuration {
            counts[key] = nil
            return
        }

        // ノック成立。前のノックからの間隔で連打かどうかを判定する
        var newCount = 1
        if let prev = counts[key], state.downTime - prev.lastUpTime <= knockInterval {
            newCount = prev.count + 1
        }

        if let required = requiredKnocks[key], newCount >= required {
            counts[key] = nil
            onFire?(key)
        } else {
            counts[key] = (newCount, time)
        }
    }

    /// 対象外のキーが押された（通常のタイピング・ショートカットの相方など）
    public func otherKeyDown(at time: TimeInterval) {
        // 押下中の対象キーは組み合わせ扱いに（⌘Cの「C」がここに来る）
        contaminateAllHeld()
        // 進行中の連打カウントもリセット（単独の押して離すが途切れたため）
        resetAllCounts()
    }

    /// マウスクリック等のポインタ操作（⌘クリック対策）
    public func pointerActivity(at time: TimeInterval) {
        // 押下中の対象キーだけ無効化する。
        // カウントまではリセットしない（慣性スクロール等で連打が妨げられないように）
        contaminateAllHeld()
    }

    /// 状態を全消去（スリープ復帰時・無効化時など）
    public func reset() {
        held.removeAll()
        counts.removeAll()
    }

    // MARK: - 内部処理

    private func contaminateAllHeld() {
        for key in held.keys {
            held[key]?.contaminated = true
        }
    }

    private func resetAllCounts() {
        counts.removeAll()
    }
}
