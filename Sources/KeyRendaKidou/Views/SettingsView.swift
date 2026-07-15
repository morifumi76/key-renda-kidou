import KeyRendaKidouCore
import SwiftUI

/// 設定画面のルートビュー
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var configStore: ConfigStore

    /// キーボード表示 / 一覧表示の切り替え
    enum ViewMode: String, CaseIterable, Identifiable {
        case keyboard = "キーボード表示"
        case list = "一覧表示"
        var id: String { rawValue }
    }

    @State private var viewMode: ViewMode = .keyboard
    @State private var selectedKey: MonitoredKey? = nil
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !appState.hasPermission {
                PermissionBanner()
            }

            // 表示切り替え
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // キー選択エリア
            Group {
                switch viewMode {
                case .keyboard:
                    KeyboardLayoutView(selectedKey: $selectedKey)
                case .list:
                    KeyListView(selectedKey: $selectedKey)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // 選択中キーの設定パネル
            if let key = selectedKey {
                KeyDetailPanel(key: key)
            } else {
                Text("キーをクリックすると、そのキーの設定がここに表示されます")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            }

            Divider()

            generalSettings
        }
        .padding(20)
        .frame(width: 680)
    }

    /// 全体設定（ノック間隔・自動起動・リセット）
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ノック間隔")
                Slider(
                    value: $configStore.config.knockInterval,
                    in: AppConfig.minKnockInterval...AppConfig.maxKnockInterval,
                    step: 0.05
                )
                .frame(width: 240)
                Text(String(format: "%.2f秒", configStore.config.knockInterval))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .help("連打と判定する間隔です。短くするほど素早い連打が必要になります。")

            HStack(spacing: 16) {
                Toggle("ログイン時に自動起動する", isOn: Binding(
                    get: { configStore.config.launchAtLogin },
                    set: { newValue in
                        if LoginItemManager.setEnabled(newValue) {
                            configStore.config.launchAtLogin = newValue
                        }
                    }
                ))
                .disabled(!LoginItemManager.isAvailable)
                .help(LoginItemManager.isAvailable
                      ? "Macにログインしたとき自動でこのアプリを起動します。"
                      : ".appバンドルとして起動しているときのみ設定できます。")

                Spacer()

                Button("設定をリセット", role: .destructive) {
                    showResetConfirmation = true
                }
                .confirmationDialog(
                    "すべての設定を初期状態に戻しますか？",
                    isPresented: $showResetConfirmation
                ) {
                    Button("リセットする", role: .destructive) {
                        configStore.reset()
                        selectedKey = nil
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("キーの割り当てとノック間隔がすべて消去されます。")
                }
            }
        }
    }
}

/// 権限がないときに表示する案内バナー
struct PermissionBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("キー監視の許可が必要です", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("キー連打を検知するには、macOSの「入力監視」の許可が必要です。\nシステム設定 → プライバシーとセキュリティ → 入力監視 で key-renda-kidou をオンにしてください。\n（許可後、反映されない場合はアプリを再起動してください）")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("システム設定を開く") {
                    PermissionManager.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("許可をリクエスト") {
                    PermissionManager.requestPermission()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}
