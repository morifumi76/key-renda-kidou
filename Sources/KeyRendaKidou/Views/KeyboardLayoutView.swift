import KeyRendaKidouCore
import SwiftUI

/// JIS配列キーボードの見た目そのままに9キーを配置したビュー
struct KeyboardLayoutView: View {
    @Binding var selectedKey: MonitoredKey?
    @EnvironmentObject var configStore: ConfigStore

    var body: some View {
        VStack(spacing: 6) {
            // 上段: Shift行（左右の⇧のみ対象。間は対象外キーのイメージ）
            HStack(spacing: 6) {
                KeyCapView(key: .shiftLeft, selectedKey: $selectedKey)
                    .frame(width: 96, height: 52)
                InertKeyView(label: "Z 〜 ？（対象外）")
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                KeyCapView(key: .shiftRight, selectedKey: $selectedKey)
                    .frame(width: 96, height: 52)
            }

            // 下段: fn ⌃ ⌥ ⌘ 英数 スペース かな ⌘
            HStack(spacing: 6) {
                KeyCapView(key: .fn, selectedKey: $selectedKey)
                    .frame(width: 60, height: 52)
                KeyCapView(key: .control, selectedKey: $selectedKey)
                    .frame(width: 60, height: 52)
                KeyCapView(key: .option, selectedKey: $selectedKey)
                    .frame(width: 60, height: 52)
                KeyCapView(key: .commandLeft, selectedKey: $selectedKey)
                    .frame(width: 72, height: 52)
                KeyCapView(key: .eisu, selectedKey: $selectedKey)
                    .frame(width: 64, height: 52)
                InertKeyView(label: "スペース（対象外）")
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                KeyCapView(key: .kana, selectedKey: $selectedKey)
                    .frame(width: 64, height: 52)
                KeyCapView(key: .commandRight, selectedKey: $selectedKey)
                    .frame(width: 72, height: 52)
            }

            // 凡例
            HStack(spacing: 16) {
                LegendDot(color: .accentColor, text: "登録済み")
                LegendDot(color: Color.gray.opacity(0.4), text: "未登録")
                Spacer()
                Text("キーをクリックして設定します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// 1つのキートップ
struct KeyCapView: View {
    let key: MonitoredKey
    @Binding var selectedKey: MonitoredKey?
    @EnvironmentObject var configStore: ConfigStore

    private var binding: KeyBinding? { configStore.config.binding(for: key) }
    private var isSelected: Bool { selectedKey == key }
    private var isBound: Bool { binding != nil }

    var body: some View {
        Button {
            selectedKey = key
        } label: {
            VStack(spacing: 2) {
                Text(key.shortLabel)
                    .font(.system(size: 15, weight: .medium))
                if let binding {
                    Text(binding.trigger.displayName)
                        .font(.system(size: 9))
                        .opacity(0.85)
                } else {
                    Text("未登録")
                        .font(.system(size: 9))
                        .opacity(0.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isBound ? Color.accentColor.opacity(0.85) : Color.gray.opacity(0.18))
            )
            .foregroundStyle(isBound ? Color.white : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        var text = key.displayName
        if let caution = key.caution {
            text += "\n⚠️ \(caution)"
        }
        return text
    }
}

/// 対象外キーの見た目（クリック不可）
struct InertKeyView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
    }
}

/// 凡例の丸
struct LegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// 全9キーの一覧表ビュー
struct KeyListView: View {
    @Binding var selectedKey: MonitoredKey?
    @EnvironmentObject var configStore: ConfigStore

    var body: some View {
        VStack(spacing: 0) {
            ForEach(MonitoredKey.allCases) { key in
                KeyListRow(key: key, selectedKey: $selectedKey)
                if key != MonitoredKey.allCases.last {
                    Divider()
                }
            }
        }
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct KeyListRow: View {
    let key: MonitoredKey
    @Binding var selectedKey: MonitoredKey?
    @EnvironmentObject var configStore: ConfigStore

    private var binding: KeyBinding? { configStore.config.binding(for: key) }

    var body: some View {
        Button {
            selectedKey = key
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(binding != nil ? Color.accentColor : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)

                Text(key.displayName)
                    .frame(width: 160, alignment: .leading)

                if let binding {
                    Text(binding.trigger.displayName)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(actionSummary(binding.action))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("未登録")
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if key.caution != nil {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .help(key.caution ?? "")
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(selectedKey == key ? Color.accentColor.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func actionSummary(_ action: KeyAction) -> String {
        switch action.type {
        case .openURL:
            return "URL: \(action.url.isEmpty ? "（未入力）" : action.url)"
        case .launchApp:
            return "アプリ: \(action.appName.isEmpty ? "（未選択）" : action.appName)"
        }
    }
}
