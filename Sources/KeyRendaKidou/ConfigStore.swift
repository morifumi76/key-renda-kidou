import KeyRendaKidouCore
import Foundation
import Combine

/// 設定の読み書きを担当するクラス。
/// 保存先: ~/Library/Application Support/key-renda-kidou/config.json
final class ConfigStore: ObservableObject {

    @Published var config: AppConfig {
        didSet {
            save()
        }
    }

    private let fileURL: URL

    init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("key-renda-kidou", isDirectory: true)
        fileURL = supportDir.appendingPathComponent("config.json")

        // 読み込み（失敗したらデフォルト設定で開始）
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = loaded
        } else {
            config = AppConfig()
        }
    }

    /// 設定をJSONファイルへ保存する
    private func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("設定の保存に失敗しました: \(error.localizedDescription)")
        }
    }

    /// 設定を初期状態に戻す
    func reset() {
        config = AppConfig()
    }
}
