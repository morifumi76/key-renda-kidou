import AppKit
import Combine

/// メニューバーアイコンとメニューを自前で管理するクラス。
///
/// SwiftUIのMenuBarExtraは「アイコンをドラッグで取り外した」等のmacOS側の記憶によって
/// 起動直後にアプリが終了させられることがあるため使わず、NSStatusItemを直接扱う。
final class MenuBarController: NSObject, NSMenuDelegate {

    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    /// アプリ起動時に呼ぶ
    func setUp() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // ドラッグでの取り外し（＝アプリ終了の事故）を許可しない
        item.behavior = []
        // 既定の識別名「Item-0」にはmacOS側に「非表示」が記憶されてしまっているため、
        // 新しい識別名を付けてまっさらな状態で登録する
        item.autosaveName = "knock-icon-v2"
        item.isVisible = true

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        statusItem = item
        updateIcon(AppState.shared.iconState)

        // アイコン状態の変化（発動フィードバック・警告など）を反映する
        AppState.shared.$iconState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateIcon(state)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(_ state: MenuBarIconState) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: state.systemImageName,
            accessibilityDescription: "key-renda-kidou"
        )
    }

    // MARK: - メニュー（開くたびに最新状態で組み立てる）

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AppState.shared.hasPermission {
            let warning = NSMenuItem(
                title: "⚠️ 入力監視の許可が必要です…",
                action: #selector(openSettings),
                keyEquivalent: ""
            )
            warning.target = self
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        let toggle = NSMenuItem(
            title: "有効にする",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = AppState.shared.configStore.config.isEnabled ? .on : .off
        menu.addItem(toggle)

        let settings = NSMenuItem(
            title: "設定を開く…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "key-renda-kidou を終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - メニューアクション

    @objc private func toggleEnabled() {
        let current = AppState.shared.configStore.config.isEnabled
        AppState.shared.setEnabled(!current)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
