import Foundation
import CoreGraphics

/// 監視対象の9キー
/// 左右⌘⇧はキーコードで区別できる（JIS配列MacBook）
public enum MonitoredKey: String, CaseIterable, Codable, Identifiable {
    case commandLeft
    case commandRight
    case shiftLeft
    case shiftRight
    case control
    case option
    case fn
    case eisu   // 英数
    case kana   // かな

    public var id: String { rawValue }

    /// macOSのハードウェアキーコード
    public var keyCode: CGKeyCode {
        switch self {
        case .commandLeft:  return 55
        case .commandRight: return 54
        case .shiftLeft:    return 56
        case .shiftRight:   return 60
        case .control:      return 59
        case .option:       return 58
        case .fn:           return 63
        case .eisu:         return 102
        case .kana:         return 104
        }
    }

    /// 修飾キーかどうか（英数・かなは通常のkeyDown/keyUpイベントとして届く）
    public var isModifier: Bool {
        switch self {
        case .eisu, .kana: return false
        default:           return true
        }
    }

    /// flagsChangedイベントの実フラグから押下状態を判定するためのデバイス固有ビット
    /// （IOKitのNX_DEVICE*KEYMASK。左右のキーを個別に判定できる）
    public var deviceFlagMask: UInt64? {
        switch self {
        case .control:      return 0x0000_0001 // NX_DEVICELCTLKEYMASK
        case .shiftLeft:    return 0x0000_0002 // NX_DEVICELSHIFTKEYMASK
        case .shiftRight:   return 0x0000_0004 // NX_DEVICERSHIFTKEYMASK
        case .commandLeft:  return 0x0000_0008 // NX_DEVICELCMDKEYMASK
        case .commandRight: return 0x0000_0010 // NX_DEVICERCMDKEYMASK
        case .option:       return 0x0000_0020 // NX_DEVICELALTKEYMASK
        case .fn:           return 0x0080_0000 // NX_SECONDARYFNMASK
        case .eisu, .kana:  return nil
        }
    }

    /// 設定画面などで表示する正式名称
    public var displayName: String {
        switch self {
        case .commandLeft:  return "⌘ Command（左）"
        case .commandRight: return "⌘ Command（右）"
        case .shiftLeft:    return "⇧ Shift（左）"
        case .shiftRight:   return "⇧ Shift（右）"
        case .control:      return "⌃ Control"
        case .option:       return "⌥ Option"
        case .fn:           return "fn 🌐（地球儀）"
        case .eisu:         return "英数"
        case .kana:         return "かな"
        }
    }

    /// キーボードUIのキートップに表示する短いラベル
    public var shortLabel: String {
        switch self {
        case .commandLeft, .commandRight: return "⌘"
        case .shiftLeft, .shiftRight:     return "⇧"
        case .control:                    return "⌃"
        case .option:                     return "⌥"
        case .fn:                         return "fn 🌐"
        case .eisu:                       return "ABC"
        case .kana:                       return "あいう"
        }
    }

    /// 注意事項（ツールチップで案内する）
    public var caution: String? {
        switch self {
        case .fn:
            return "macOS標準の機能（絵文字表示など）と競合します。システム設定 → キーボード →「🌐キーを押して」を「何もしない」に変更してください。"
        case .eisu:
            return "押すたびに入力モードが切り替わる副作用があります（連打後は英数モードになります）。"
        case .kana:
            return "押すたびに入力モードが切り替わる副作用があります（連打後はかなモードになります）。"
        default:
            return nil
        }
    }

    /// キーコードから監視対象キーを引く
    public static func from(keyCode: Int64) -> MonitoredKey? {
        allCases.first { Int64($0.keyCode) == keyCode }
    }
}
