import SwiftUI

/// アプリ設定画面
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var showArcConfigInfo = false

    var body: some View {
        NavigationStack {
            Form {
                temperatureSection
                humiditySection
                signalBatterySection
                autoSendSection
                arcConfigSection
                aboutSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    // MARK: - Temperature Section

    private var temperatureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("ベース温度: \(settings.temperatureBase, specifier: "%.1f") °C")
                    .font(.subheadline)
                Slider(
                    value: $settings.temperatureBase,
                    in: -40...85,
                    step: 0.5
                )
                .tint(.orange)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("変動幅: ± \(settings.temperatureVariation, specifier: "%.1f") °C")
                    .font(.subheadline)
                Slider(
                    value: $settings.temperatureVariation,
                    in: 0...10,
                    step: 0.5
                )
                .tint(.orange)
            }
            .padding(.vertical, 4)
        } header: {
            Label("温度設定", systemImage: "thermometer")
        } footer: {
            Text("iPhoneには温度センサーがないため、ベース値にランダムな変動を加えた値を送信します。")
                .font(.caption)
        }
    }

    // MARK: - Humidity Section

    private var humiditySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("ベース湿度: \(settings.humidityBase, specifier: "%.1f") %")
                    .font(.subheadline)
                Slider(
                    value: $settings.humidityBase,
                    in: 0...100,
                    step: 1
                )
                .tint(.blue)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("変動幅: ± \(settings.humidityVariation, specifier: "%.1f") %")
                    .font(.subheadline)
                Slider(
                    value: $settings.humidityVariation,
                    in: 0...20,
                    step: 1
                )
                .tint(.blue)
            }
            .padding(.vertical, 4)
        } header: {
            Label("湿度設定", systemImage: "humidity")
        } footer: {
            Text("iPhoneには湿度センサーがないため、ベース値にランダムな変動を加えた値を送信します。")
                .font(.caption)
        }
    }

    // MARK: - Signal / Battery Section

    private var signalBatterySection: some View {
        Section {
            Stepper(
                "電波強度 (rs): \(settings.rsValue == -1 ? "圏外" : String(settings.rsValue))",
                value: $settings.rsValue,
                in: -1...4
            )
            Stepper(
                "バッテリー (bat): \(settings.batValue == -1 ? "充電中" : String(settings.batValue))",
                value: $settings.batValue,
                in: -1...3
            )
        } header: {
            Label("電波強度・バッテリー設定", systemImage: "antenna.radiowaves.left.and.right")
        } footer: {
            Text("送信する電波強度と電池残量の値を設定します。rs: -1 (圏外) 〜 4、bat: -1 (充電中) / 1 〜 3 (電池残量)。")
                .font(.caption)
        }
    }

    // MARK: - Auto Send Section

    private var autoSendSection: some View {
        Section {
            Toggle("自動送信 (フォールバック)", isOn: $settings.defaultAutoSend)

            if settings.defaultAutoSend {
                VStack(alignment: .leading, spacing: 8) {
                    Text("送信間隔: \(settings.defaultSendingInterval) 秒")
                        .font(.subheadline)
                    Slider(
                        value: Binding(
                            get: { Double(settings.defaultSendingInterval) },
                            set: { settings.defaultSendingInterval = Int($0) }
                        ),
                        in: 5...3600,
                        step: 5
                    )
                    .tint(.green)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("フォールバック送信設定", systemImage: "clock.arrow.circlepath")
        } footer: {
            Text("SORACOM Arc が接続できない場合や、メタデータサービスから設定を取得できない場合に使用されます。")
                .font(.caption)
        }
    }

    // MARK: - Arc Config Section

    private var arcConfigSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("WireGuard 設定")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showArcConfigInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $settings.arcConfigJSON)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        } header: {
            Label("SORACOM Arc 設定", systemImage: "lock.shield")
        } footer: {
            Text("SORACOM コンソールの SIM 管理 > SIM 詳細 > バーチャル SIM から WireGuard 接続情報を取得して貼り付けてください。")
                .font(.caption)
        }
        .alert("WireGuard 設定について", isPresented: $showArcConfigInfo) {
            Button("OK") { }
        } message: {
            Text("SORACOM Arc (WireGuard VPN) への接続設定を WireGuard 形式で入力します。\n\n[Interface]\nPrivateKey = ...\nAddress = ...\n\n[Peer]\nPublicKey = ...\nAllowedIPs = ...\nEndpoint = ...\n\nSORACOM コンソールの SIM 管理 > SIM 詳細 > バーチャル SIM から WireGuard 接続情報を取得してください。\n\n詳細: https://users.soracom.io/ja-jp/docs/arc/")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("アプリについて") {
            LabeledContent("バージョン") {
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("ビルド") {
                Text(Bundle.main.buildNumber)
                    .foregroundStyle(.secondary)
            }
            Link(
                destination: URL(string: "https://github.com/kenichiro-kimura/soracom-gps-multiunit")!
            ) {
                Label("GitHub リポジトリ", systemImage: "arrow.up.right.square")
            }
        }
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}
