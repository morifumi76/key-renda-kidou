import KeyRendaKidouCore
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 選択中のキーの設定パネル（トリガー択一＋アクション）
struct KeyDetailPanel: View {
    let key: MonitoredKey
    @EnvironmentObject var configStore: ConfigStore

    private var binding: KeyBinding? { configStore.config.binding(for: key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ヘッダー
            HStack(spacing: 8) {
                Text("選択中： \(key.displayName)")
                    .font(.headline)
                if let caution = key.caution {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .help(caution)
                }
                Spacer()
                if binding != nil {
                    Button("割り当てを解除", role: .destructive) {
                        configStore.config.setBinding(nil, for: key)
                    }
                }
            }

            if let caution = key.caution {
                Text("⚠️ \(caution)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if binding != nil {
                editForm
            } else {
                // 未登録のキー
                VStack(alignment: .leading, spacing: 8) {
                    Text("このキーはまだ登録されていません。")
                        .foregroundStyle(.secondary)
                    Button("このキーに登録する") {
                        configStore.config.setBinding(KeyBinding(), for: key)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            }
        }
        .frame(minHeight: 150, alignment: .top)
    }

    /// 登録済みキーの編集フォーム（変更は即時保存される）
    private var editForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // トリガー（2回押し／3回押しの択一）
            HStack(spacing: 12) {
                Text("トリガー：")
                Picker("", selection: triggerBinding) {
                    ForEach(TriggerCount.allCases) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }

            // アクション
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("アクション：")
                Picker("", selection: actionTypeBinding) {
                    ForEach(ActionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                if actionTypeBinding.wrappedValue == .openURL {
                    urlField
                } else {
                    appPickerField
                }
            }

            // バリデーション結果の表示
            validationStatus
        }
        .padding(12)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var urlField: some View {
        TextField("https://www.example.com", text: urlBinding)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
    }

    private var appPickerField: some View {
        HStack(spacing: 8) {
            if let action = binding?.action, !action.appPath.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(forFile: action.appPath))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(action.appName)
            } else {
                Text("アプリが未選択です")
                    .foregroundStyle(.secondary)
            }
            Button("アプリを選択…") {
                pickApp()
            }
        }
    }

    @ViewBuilder
    private var validationStatus: some View {
        if let action = binding?.action {
            if action.isValid {
                Label("設定は有効です。保存されました。", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                switch action.type {
                case .openURL:
                    Label(action.url.isEmpty
                          ? "URLを入力してください。"
                          : "URLの形式が正しくありません（例: https://www.yahoo.co.jp）。",
                          systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                case .launchApp:
                    Label("起動するアプリを選択してください。", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - 設定へのバインディング（変更は即時保存）

    private var triggerBinding: Binding<TriggerCount> {
        Binding(
            get: { binding?.trigger ?? .double },
            set: { newValue in
                var updated = binding ?? KeyBinding()
                updated.trigger = newValue
                configStore.config.setBinding(updated, for: key)
            }
        )
    }

    private var actionTypeBinding: Binding<ActionType> {
        Binding(
            get: { binding?.action.type ?? .openURL },
            set: { newValue in
                var updated = binding ?? KeyBinding()
                updated.action.type = newValue
                configStore.config.setBinding(updated, for: key)
            }
        )
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { binding?.action.url ?? "" },
            set: { newValue in
                var updated = binding ?? KeyBinding()
                updated.action.url = newValue
                configStore.config.setBinding(updated, for: key)
            }
        )
    }

    /// アプリ選択ダイアログ（手打ちさせない）
    private func pickApp() {
        let panel = NSOpenPanel()
        panel.title = "起動するアプリを選択"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            var updated = binding ?? KeyBinding()
            updated.action.appPath = url.path
            updated.action.appName = FileManager.default.displayName(atPath: url.path)
            configStore.config.setBinding(updated, for: key)
        }
    }
}
