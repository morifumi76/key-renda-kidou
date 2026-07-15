import Foundation
import KeyRendaKidouCore

// ノック判定エンジンのテストランナー（要件書9章のテスト観点に対応）
// Xcodeなし環境のため swift test の代わりに `swift run knock-tests` で実行する

var passCount = 0
var failCount = 0

/// テスト1件を実行して結果を表示する
func test(_ name: String, _ body: () -> Bool) {
    if body() {
        passCount += 1
        print("✅ \(name)")
    } else {
        failCount += 1
        print("❌ \(name)")
    }
}

/// テスト用のセットアップ（左⌘に2回押し、右⌘に3回押しを登録）
func makeDetector() -> (KnockDetector, () -> [MonitoredKey]) {
    let detector = KnockDetector()
    detector.knockInterval = 0.3
    detector.requiredKnocks = [.commandLeft: 2, .commandRight: 3]
    var fired: [MonitoredKey] = []
    detector.onFire = { fired.append($0) }
    return (detector, { fired })
}

/// キーを1回「押して離す」ヘルパー（押下時間0.05秒）
func knock(_ detector: KnockDetector, _ key: MonitoredKey, at time: Double) {
    detector.monitoredKeyDown(key, at: time)
    detector.monitoredKeyUp(key, at: time + 0.05)
}

print("=== ノック判定エンジン テスト ===\n")

// MARK: - 基本動作

test("2回押し設定のキーは2回ノックで即発動する") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)
    knock(detector, .commandLeft, at: 0.2)
    return fired() == [.commandLeft]
}

test("3回押し設定のキーは2回では発動せず3回で発動する") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandRight, at: 0.0)
    knock(detector, .commandRight, at: 0.2)
    guard fired().isEmpty else { return false }
    knock(detector, .commandRight, at: 0.4)
    return fired() == [.commandRight]
}

test("未登録のキーは何回ノックしても発動しない") {
    let (detector, fired) = makeDetector()
    for i in 0..<6 {
        knock(detector, .option, at: Double(i) * 0.15)
    }
    return fired().isEmpty
}

// MARK: - 最重要：ショートカット操作との区別

test("⌘C→⌘Vを連発しても誤発動しない（最重要）") {
    let (detector, fired) = makeDetector()
    var t = 0.0
    // ⌘C → ⌘V を5セット連発する
    for _ in 0..<5 {
        detector.monitoredKeyDown(.commandLeft, at: t)          // ⌘を押す
        detector.otherKeyDown(at: t + 0.05)                     // Cを押す
        detector.monitoredKeyUp(.commandLeft, at: t + 0.15)     // ⌘を離す
        detector.monitoredKeyDown(.commandLeft, at: t + 0.25)   // ⌘を押す
        detector.otherKeyDown(at: t + 0.30)                     // Vを押す
        detector.monitoredKeyUp(.commandLeft, at: t + 0.40)     // ⌘を離す
        t += 0.5
    }
    return fired().isEmpty
}

test("⌘を押しっぱなしでC連打（⌘C⌘C…）でも誤発動しない") {
    let (detector, fired) = makeDetector()
    detector.monitoredKeyDown(.commandLeft, at: 0.0)
    detector.otherKeyDown(at: 0.1)
    detector.otherKeyDown(at: 0.2)
    detector.otherKeyDown(at: 0.3)
    detector.monitoredKeyUp(.commandLeft, at: 0.4)
    return fired().isEmpty
}

test("⌘⇧のように対象キー同士の組み合わせでも誤発動しない") {
    let (detector, fired) = makeDetector()
    var t = 0.0
    // ⌘⇧4（スクリーンショット）のような操作を2回
    for _ in 0..<2 {
        detector.monitoredKeyDown(.commandLeft, at: t)
        detector.monitoredKeyDown(.shiftLeft, at: t + 0.05)
        detector.otherKeyDown(at: t + 0.10)
        detector.monitoredKeyUp(.shiftLeft, at: t + 0.20)
        detector.monitoredKeyUp(.commandLeft, at: t + 0.25)
        t += 0.35
    }
    return fired().isEmpty
}

test("ノックの途中で他のキーをタイピングするとカウントがリセットされる") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)      // 1回目のノック
    detector.otherKeyDown(at: 0.1)              // 別のキーをタイプ
    knock(detector, .commandLeft, at: 0.2)      // これは1回目扱いになるはず
    guard fired().isEmpty else { return false }
    knock(detector, .commandLeft, at: 0.4)      // 2回目 → 発動
    return fired() == [.commandLeft]
}

test("⌘クリック（ポインタ操作との組み合わせ）では誤発動しない") {
    let (detector, fired) = makeDetector()
    var t = 0.0
    for _ in 0..<2 {
        detector.monitoredKeyDown(.commandLeft, at: t)
        detector.pointerActivity(at: t + 0.05)   // クリック
        detector.monitoredKeyUp(.commandLeft, at: t + 0.15)
        t += 0.3
    }
    return fired().isEmpty
}

// MARK: - 長押し・間隔

test("長押しはノックとしてカウントしない") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)              // 1回目のノック
    detector.monitoredKeyDown(.commandLeft, at: 0.2)
    detector.monitoredKeyUp(.commandLeft, at: 1.0)      // 0.8秒の長押し
    return fired().isEmpty
}

test("ノック間隔を超えた連打は1回目から数え直しになる") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)
    knock(detector, .commandLeft, at: 1.0)   // 間隔0.3秒を大きく超過
    knock(detector, .commandLeft, at: 2.0)
    guard fired().isEmpty else { return false }
    // 数え直し後、素早い2連打なら発動する
    knock(detector, .commandLeft, at: 3.0)
    knock(detector, .commandLeft, at: 3.2)
    return fired() == [.commandLeft]
}

test("発動後はカウントがリセットされ、連打し続けても連続発動しない") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)
    knock(detector, .commandLeft, at: 0.2)   // 発動（1回目）
    knock(detector, .commandLeft, at: 0.4)   // 新しい1回目
    guard fired() == [.commandLeft] else { return false }
    knock(detector, .commandLeft, at: 0.6)   // 2回目 → 2度目の発動
    return fired() == [.commandLeft, .commandLeft]
}

// MARK: - 英数・かな

test("英数キーの2回ノックで発動する") {
    let (detector, fired) = makeDetector()
    detector.requiredKnocks[.eisu] = 2
    knock(detector, .eisu, at: 0.0)
    knock(detector, .eisu, at: 0.2)
    return fired() == [.eisu]
}

test("⌘を押しながら英数を押しても誤発動しない") {
    let (detector, fired) = makeDetector()
    detector.requiredKnocks[.eisu] = 2
    var t = 0.0
    for _ in 0..<2 {
        detector.monitoredKeyDown(.commandLeft, at: t)
        knock(detector, .eisu, at: t + 0.05)   // ⌘押下中の英数
        detector.monitoredKeyUp(.commandLeft, at: t + 0.2)
        t += 0.3
    }
    return fired().isEmpty
}

// MARK: - リセット（スリープ復帰等）

test("リセット後は押しかけの状態が持ち越されない") {
    let (detector, fired) = makeDetector()
    knock(detector, .commandLeft, at: 0.0)
    detector.monitoredKeyDown(.commandLeft, at: 0.2)
    detector.reset()   // スリープ復帰などを想定
    // 離しイベントだけが後から届いても何も起きない
    detector.monitoredKeyUp(.commandLeft, at: 0.3)
    return fired().isEmpty
}

test("ノック間隔の設定値が反映される（0.5秒なら遅めの連打でも発動）") {
    let (detector, fired) = makeDetector()
    detector.knockInterval = 0.5
    knock(detector, .commandLeft, at: 0.0)
    knock(detector, .commandLeft, at: 0.45)   // 0.3秒設定なら失敗、0.5秒設定なら成功
    return fired() == [.commandLeft]
}

// MARK: - 結果

print("\n=== 結果: \(passCount)件成功 / \(failCount)件失敗 ===")
exit(failCount == 0 ? 0 : 1)
