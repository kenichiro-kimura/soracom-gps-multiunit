# soracom-gps-multiunit

GPS マルチユニット SORACOM Edition シミュレータ

[GPS マルチユニット SORACOM Edition](https://users.soracom.io/ja-jp/guides/iot-devices/gps-multiunit/feature/) の機能を iPhone で再現するシミュレータアプリです。

## 機能

- 📱 GPS マルチユニットの外観を再現した UI
- 📍 iPhone の GPS から位置情報 (緯度/経度/高度/速度) を取得して送信
- 🏃 Core Motion から三軸加速度センサーデータを取得して送信
- 🌡️ 温度・湿度はセンサーで取得できないため、設定画面で指定したベース値にランダムな変動を加えた値を送信
- 🔄 SORACOM メタデータサービスから設定を取得し、自動送信と手動送信、送信間隔を切り替え
- 🔒 SORACOM Arc (WireGuard VPN) を使って [libsoratun](https://github.com/0x6b/libsoratun) 経由で安全に通信
- 📊 SORACOM Unified Endpoint にデータを送信
- 📝 送信ログの表示

## 送信データ形式

GPS マルチユニット SORACOM Edition と同じ JSON 形式でデータを送信します:

```json
{
  "lat": 35.12345,
  "lon": 139.12345,
  "alt": 10.0,
  "speed": 0.0,
  "temp": 25.5,
  "humi": 60.0,
  "x": 0.01,
  "y": -0.02,
  "z": 0.98,
  "type": 0
}
```

`type` の値:
- `0`: タイマー自動送信 (periodic)
- `1`: スイッチ押下による手動送信 (manual)
- `2`: 加速度アラート (accelerationAlert)

## 必要環境

- iOS 16.0 以上
- Xcode 15.0 以上
- SORACOM アカウント (仮想 SIM)
- libsoratun iOS 向けビルド (後述)

## セットアップ

### 1. libsoratun のビルド

本アプリは SORACOM Arc への接続に [libsoratun](https://github.com/0x6b/libsoratun) を使用します。
iOS 向けにビルドして XCFramework として追加する必要があります。

```bash
# Go と gomobile のインストール
brew install go
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# libsoratun をクローン
git clone https://github.com/0x6b/libsoratun
cd libsoratun

# iOS 向け静的ライブラリとしてビルド (iOS実機 + シミュレータ)
CGO_ENABLED=1 GOOS=ios GOARCH=arm64 go build -buildmode=c-archive -o libsoratun-ios.a .
CGO_ENABLED=1 GOOS=ios GOARCH=amd64 GOFLAGS=-tags=ios go build -buildmode=c-archive -o libsoratun-sim.a .

# XCFramework を作成
xcodebuild -create-xcframework \
  -library libsoratun-ios.a -headers . \
  -library libsoratun-sim.a -headers . \
  -output libsoratun.xcframework
```

ビルドした `libsoratun.xcframework` を `SoracomGPSMultiunit/SoracomGPSMultiunit/Libsoratun/` に配置し、
Xcode プロジェクトの "Frameworks, Libraries, and Embedded Content" に追加してください。

### 2. arc.json の取得

1. [SORACOM コンソール](https://console.soracom.io/) にログインし、仮想 SIM を作成
2. [soratun](https://github.com/soracom/soratun/) をインストール
3. `soratun arc gen-config` で `arc.json` を生成
4. アプリの設定画面から `arc.json` の内容を貼り付け

### 3. ビルドと実行

```bash
cd SoracomGPSMultiunit
open SoracomGPSMultiunit.xcodeproj
```

Xcode でプロジェクトを開き、iPhone または シミュレータで実行してください。

> **Note**: libsoratun を追加せずにビルドした場合、SORACOM Arc 接続は動作しませんが、UI の確認は可能です。

## 使い方

1. アプリを起動すると GPS マルチユニットの外観が表示されます
2. 設定画面 (⚙️ アイコン) から以下を設定:
   - 温度・湿度のベース値と変動幅
   - arc.json の内容
3. SORACOM Arc に接続されると、メタデータサービスから自動送信設定を取得します
4. デバイスのボタン (矢印アイコン) をタップすると手動送信できます
5. 自動送信トグルをオンにすると設定間隔で自動送信されます

## アーキテクチャ

```
SoracomGPSMultiunit/
├── Models/
│   ├── SensorData.swift        # センサーデータモデル
│   ├── MetadataConfig.swift    # メタデータ設定モデル
│   └── AppSettings.swift       # アプリ設定
├── Services/
│   ├── LocationService.swift   # Core Location (GPS)
│   ├── MotionService.swift     # Core Motion (加速度)
│   ├── SoracomArcService.swift # SORACOM Arc (libsoratun)
│   ├── MetadataService.swift   # メタデータサービス
│   └── DataSendingService.swift # Unified Endpoint 送信
├── ViewModels/
│   └── MainViewModel.swift     # メインロジック
├── Views/
│   ├── DeviceView.swift        # デバイス外観 UI
│   ├── SettingsView.swift      # 設定画面
│   └── SendLogView.swift       # 送信ログ
├── Libsoratun/
│   ├── Libsoratun.h            # libsoratun C API 宣言
│   └── SoracomGPSMultiunit-Bridging-Header.h
└── ContentView.swift           # ルートビュー
```

## ライセンス

MIT License
