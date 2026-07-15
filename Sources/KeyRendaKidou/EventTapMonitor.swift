import KeyRendaKidouCore
import Foundation
import CoreGraphics
import AppKit

/// CGEventTap（macOSのグローバルキーイベント監視）でキー入力を受け取り、
/// KnockDetectorへ流し込むクラス。
///
/// - 修飾キー（⌘⇧⌃⌥fn）は flagsChanged イベントで届く
/// - 英数・かなは通常の keyDown / keyUp イベントで届く
/// - 監視には「入力監視」権限が必要（権限がないとタップ生成に失敗する）
final class EventTapMonitor {

    let detector: KnockDetector

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// 押下中と認識している修飾キーコード（flagsChangedは押し/離しの区別がないためトグルで追跡）
    private var heldModifierKeyCodes: Set<Int64> = []
    /// 対象外の修飾キー（Caps Lock等）の押下追跡用
    private var heldOtherModifierKeyCodes: Set<Int64> = []

    /// タップが動作中か
    private(set) var isRunning = false

    init(detector: KnockDetector) {
        self.detector = detector
    }

    /// 監視を開始する。権限がない場合は false を返す
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<EventTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    /// 監視を完全に停止する
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        heldModifierKeyCodes.removeAll()
        heldOtherModifierKeyCodes.removeAll()
        detector.reset()
    }

    /// 一時停止/再開（メニューの有効/無効切り替え用）
    func setPaused(_ paused: Bool) {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: !paused)
        if paused {
            heldModifierKeyCodes.removeAll()
            heldOtherModifierKeyCodes.removeAll()
            detector.reset()
        }
    }

    /// スリープ復帰後などにタップが生きているか確認し、必要なら再有効化する
    func reviveIfNeeded() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            detector.reset()
        }
    }

    // MARK: - イベント処理

    private func handle(type: CGEventType, event: CGEvent) {
        // システムによるタップの自動無効化（タイムアウト等）から復帰する
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            detector.reset()
            return
        }

        // イベントの時刻（ナノ秒 → 秒）。単調増加の時計なのでノック間隔の計測に適する
        let time = TimeInterval(event.timestamp) / 1_000_000_000

        switch type {
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if let key = MonitoredKey.from(keyCode: keyCode), key.isModifier {
                // 押し/離しはトグルで判定する
                if heldModifierKeyCodes.contains(keyCode) {
                    heldModifierKeyCodes.remove(keyCode)
                    detector.monitoredKeyUp(key, at: time)
                } else {
                    heldModifierKeyCodes.insert(keyCode)
                    detector.monitoredKeyDown(key, at: time)
                }
            } else {
                // 対象外の修飾キー（Caps Lock等）。押した瞬間だけ「他のキー」として扱う
                if heldOtherModifierKeyCodes.contains(keyCode) {
                    heldOtherModifierKeyCodes.remove(keyCode)
                } else {
                    heldOtherModifierKeyCodes.insert(keyCode)
                    detector.otherKeyDown(at: time)
                }
            }

        case .keyDown:
            // 押しっぱなしによる自動リピートは無視する
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            guard !isAutorepeat else { return }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if let key = MonitoredKey.from(keyCode: keyCode), !key.isModifier {
                // 英数・かな
                detector.monitoredKeyDown(key, at: time)
            } else {
                // 通常のタイピング（⌘Cの「C」もここ）
                detector.otherKeyDown(at: time)
            }

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if let key = MonitoredKey.from(keyCode: keyCode), !key.isModifier {
                detector.monitoredKeyUp(key, at: time)
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // ⌘クリック等の誤発動防止
            detector.pointerActivity(at: time)

        default:
            break
        }
    }
}
