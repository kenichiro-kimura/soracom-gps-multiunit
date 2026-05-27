# soracom-gps-multiunit

GPS マルチユニット SORACOM Edition シミュレータ

[GPS マルチユニット SORACOM Edition](https://users.soracom.io/ja-jp/guides/iot-devices/gps-multiunit/feature/) の機能を iPhone で再現するシミュレータアプリです。

## 機能

- 📱 GPS マルチユニットの外観を再現した UI
- 📍 iPhone の GPS から位置情報 (緯度/経度) を取得して送信
- 🏃 Core Motion から三軸加速度センサーデータを取得して送信
- 🌡️ 温度・湿度はセンサーで取得できないため、設定画面で指定したベース値にランダムな変動を加えた値を送信
- 🔄 SORACOM メタデータサービスから設定を取得し、自動送信と手動送信、送信間隔を切り替え
- 🔒 SORACOM Arc (WireGuard VPN) を使って [libsoratun](https://github.com/0x6b/libsoratun) 経由で安全に通信 (Arc が未設定・利用不可の場合はインターネット経由 UDP にフォールバック)
- 📊 SORACOM Unified Endpoint にデータを送信
- 📝 送信ログの表示

## 送信データ形式

GPS マルチユニット SORACOM Edition と同じ JSON 形式でデータを送信します:

```json
{
  "lat": 35.1,
  "lon": 139.1,
  "temp": 25.5,
  "humi": 60.0,
  "x": 0.0,
  "y": -200.0,
  "z": 980.0,
  "rs": 3,
  "bat": 3,
  "type": 0
}
```

`type` の値:
- `0`: タイマー自動送信 (periodic)
- `1`: スイッチ押下による手動送信 (manual)
- `2`: 加速度アラート (accelerationAlert)

## 必要環境

- iOS 17.6 以上
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

# iOS 向け静的ライブラリとしてビルド (iOS実機 + シミュレータ)して XCFramework を作成
cp <リポジトリルート>/SoracomGPSMultiunit/bin/buildlibsoratun.sh .
chmod +x buildlibsoratun.sh
./buildlibsoratun.sh
```

ビルドした `libsoratun.xcframework` を `SoracomGPSMultiunit/SoracomGPSMultiunit/Libsoratun/` に配置し、
Xcode プロジェクトの "Frameworks, Libraries, and Embedded Content" に追加してください。

### 2. WireGuard 接続情報の取得

1. [SORACOM コンソール](https://console.soracom.io/) にログインし、バーチャル SIM を作成
2. SIM 管理 > SIM 詳細 > バーチャル SIM から WireGuard 接続情報を取得
3. アプリの設定画面から WireGuard 接続情報を貼り付け

取得した WireGuard 設定は以下の形式になります:

```ini
[Interface]
PrivateKey = <プライベートキー>
Address = <クライアント IP アドレス>/32

[Peer]
PublicKey = <サーバー公開キー>
AllowedIPs = <許可 IP>
Endpoint = <サーバーエンドポイント>
```

### 3. ビルドと実行

```bash
cd SoracomGPSMultiunit
open SoracomGPSMultiunit.xcodeproj
```

Xcode でプロジェクトを開き、iPhone または シミュレータで実行してください。

> **Note**: libsoratun を追加せずにビルドした場合、または Arc 接続情報が未設定・設定不備の場合は、SORACOM Arc 接続は動作せず、インターネット経由の UDP 送信にフォールバックします。

## 使い方

1. アプリを起動すると GPS マルチユニットの外観が表示されます
2. 設定画面 (⚙️ アイコン) から以下を設定:
   - 温度・湿度のベース値と変動幅
   - 電波強度 (rs) とバッテリー残量 (bat) の値
   - SORACOM Arc の WireGuard 接続情報
3. SORACOM Arc に接続されると、メタデータサービスから自動送信設定を取得します
4. デバイスのボタン (矢印アイコン) をタップすると手動送信できます
5. 自動送信トグルをオンにすると設定間隔で自動送信されます

## アーキテクチャ

```text
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
