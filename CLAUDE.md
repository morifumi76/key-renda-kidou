# key-renda-kidou プロジェクト固有ルール

## プロジェクト概要

キー連打（ノック）でアクションを起動するmacOS用メニューバー常駐ランチャー。
Swift + SwiftUI 製。詳細な要件は `docs/specs/requirements.md` を参照。

## 開発環境の制約（重要）

- **このMacにはXcodeが入っていない**（コマンドラインツールのみ）
  - `xcodebuild` は使えない。ビルドは `swift build` / `scripts/build-app.sh` を使う
  - XCTest / Swift Testing が使えないため、テストは実行ファイル形式（`swift run knock-tests`）
- .appバンドルは `scripts/build-app.sh` で組み立てる（ad-hoc署名）
- 再ビルドすると署名が変わるため、macOSの「入力監視」権限の再許可が必要になる場合がある

## よく使うコマンド

```bash
swift build                     # ビルド
swift run knock-tests           # ノック判定エンジンのテスト
scripts/build-app.sh --install  # .app作成 → ~/Applications へ設置＆起動
```

## アーキテクチャ

- `Sources/KeyRendaKidouCore/` … OSイベントに依存しない純粋ロジック（public API）
  - `KnockDetector.swift` … ノック判定の状態機械。**本アプリの心臓部**
  - `MonitoredKey.swift` … 対象9キーの定義（キーコード・表示名・注意事項）
  - `AppConfig.swift` … 設定のデータモデル（Codable）
- `Sources/KeyRendaKidou/` … アプリ本体
  - `EventTapMonitor.swift` … CGEventTapでキー監視 → KnockDetectorへ流す
  - `AppState.swift` … 全体の状態管理・コンポーネントの橋渡し
  - `Views/` … 設定画面（キーボード見た目UI）
- `Sources/KnockTests/` … テストランナー（Testingフレームワークが使えない環境のため）

## 変更時の注意

- **KnockDetectorを変更したら必ず `swift run knock-tests` を実行すること**
  - 特に「⌘C→⌘Vを連発しても誤発動しない」が最重要仕様
- コアロジック（KeyRendaKidouCore）にAppKit/SwiftUI依存を持ち込まない
- 設定ファイルの形式を変えるときは後方互換性に注意（読み込み失敗時はデフォルト設定にフォールバックする仕様）
