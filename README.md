# soracom-gps-multiunit

GPS マルチユニット SORACOM Edition シミュレータ

[GPS マルチユニット SORACOM Edition](https://users.soracom.io/ja-jp/guides/iot-devices/gps-multiunit/feature/) の機能をスマートフォンで再現するシミュレータアプリです。iOS 版に加えて、ネイティブ Kotlin で実装した Android 版を同梱しています。

## 機能

- 📱 GPS マルチユニットの外観を再現した UI
- 📍 スマートフォンの GPS から位置情報 (緯度/経度) を取得して送信
- 🏃 スマートフォンの加速度センサーデータを取得して送信
- 🌡️ 温度・湿度はセンサーで取得できないため、設定画面で指定したベース値にランダムな変動を加えた値を送信
- 🔄 自動送信と手動送信、送信間隔の切り替え
- 🔒 iOS / Android 版ともに SORACOM Arc (WireGuard VPN) を使って [libsoratun](https://github.com/0x6b/libsoratun) 経由で安全に通信 (Arc が未設定・利用不可の場合はインターネット経由 UDP にフォールバック)
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

- iOS 17.6 以上 / Xcode 15.0 以上
- Android Studio Koala 以降 または Android SDK 35 以上
- SORACOM アカウント (仮想 SIM)
- libsoratun ビルド成果物 (iOS / Android で任意、後述)

## セットアップ

### 1. libsoratun のビルド

本アプリは SORACOM Arc への接続に [libsoratun](https://github.com/0x6b/libsoratun) を使用します。
iOS / Android でそれぞれの形式にビルドして追加します。

#### iOS 向け

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

#### Android 向け

```bash
# Go と Android NDK を用意
brew install go

# libsoratun をクローン
git clone https://github.com/0x6b/libsoratun
cd libsoratun

# Android 向け共有ライブラリをビルド
cp <リポジトリルート>/android/bin/buildlibsoratun.sh .
chmod +x buildlibsoratun.sh
ANDROID_NDK_HOME=<Android NDK のパス> ./buildlibsoratun.sh
```

ビルド後、`android-libs/jniLibs/<ABI>/libsoratun.so` が生成されます。`arm64-v8a` / `armeabi-v7a` / `x86_64` の各ディレクトリを `android/app/src/main/jniLibs/` にコピーしてください。

```bash
mkdir -p <リポジトリルート>/android/app/src/main/jniLibs
cp -R android-libs/jniLibs/* <リポジトリルート>/android/app/src/main/jniLibs/
```

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

### 3. iOS 版のビルドと実行

```bash
cd SoracomGPSMultiunit
open SoracomGPSMultiunit.xcodeproj
```

Xcode でプロジェクトを開き、iPhone または シミュレータで実行してください。

> **Note**: libsoratun を追加せずにビルドした場合、または Arc 接続情報が未設定・設定不備の場合は、SORACOM Arc 接続は動作せず、インターネット経由の UDP 送信にフォールバックします。

### 4. Android 版のビルドと実行

```bash
cd android
./gradlew assembleDebug
```

Android Studio で `android/` を開くか、上記コマンドで APK をビルドしてください。Android 版は Jetpack Compose で UI を実装しており、GPS / 加速度センサー / 温湿度の疑似値 / 送信ログ / SORACOM Arc 設定 / UDP 送信設定を Kotlin でネイティブ実装しています。

> **Note**: Android 版は `android/app/src/main/jniLibs/` に `libsoratun.so` を配置すると JNI 経由で SORACOM Arc 送信を試みます。Arc 設定が未入力・不正、または `.so` が未配置の場合はインターネット経由 UDP にフォールバックします。

## 使い方

1. アプリを起動すると GPS マルチユニットの外観と最新のセンサー値が表示されます
2. 設定画面から以下を設定します:
   - 温度・湿度のベース値と変動幅
   - 電波強度 (rs) とバッテリー残量 (bat) の値
   - 自動送信の有効/無効と送信間隔
   - SORACOM Arc の WireGuard 接続情報または soratun の arc.json
3. デバイスのボタン (矢印アイコン) をタップすると手動送信できます
4. 自動送信をオンにすると設定間隔で送信されます
5. 送信ログ画面で過去 100 件までの送信結果を確認できます

## アーキテクチャ

```text
SoracomGPSMultiunit/                # iOS / Swift 実装
├── Models/
├── Services/
├── ViewModels/
├── Views/
└── ContentView.swift

android/                           # Android / Kotlin 実装
├── app/src/main/java/...
│   ├── MainActivity.kt           # ルート UI (Compose)
│   ├── MainViewModel.kt          # センサー収集・送信ロジック
│   ├── DataSendingService.kt     # Arc 優先 + UDP フォールバック送信
│   ├── SoracomArcService.kt      # Arc 設定変換と libsoratun JNI 呼び出し
│   ├── SensorData.kt            # 送信ペイロード
│   ├── SensorValueGenerator.kt  # 温湿度疑似値
│   ├── SettingsRepository.kt    # SharedPreferences 保存
│   └── UdpSendingService.kt     # Unified Endpoint 送信
├── app/src/main/cpp/             # JNI ブリッジ
├── app/src/test/java/...         # Android ロジックのユニットテスト
└── bin/buildlibsoratun.sh        # libsoratun Android 向けビルド補助
```

## ライセンス

MIT License
