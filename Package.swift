// swift-tools-version: 6.0
// key-renda-kidou: キー連打でアクションを起動するmacOS常駐ランチャー
import PackageDescription

let package = Package(
    name: "key-renda-kidou",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // ノック判定などのコアロジック（OSイベント非依存・テスト可能）
        .target(
            name: "KeyRendaKidouCore",
            path: "Sources/KeyRendaKidouCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // アプリ本体（メニューバー常駐・設定UI・キー監視）
        .executableTarget(
            name: "KeyRendaKidou",
            dependencies: ["KeyRendaKidouCore"],
            path: "Sources/KeyRendaKidou",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // ノック判定のテストランナー（Xcodeなし環境のため swift test の代わりに swift run knock-tests で実行）
        .executableTarget(
            name: "knock-tests",
            dependencies: ["KeyRendaKidouCore"],
            path: "Sources/KnockTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
