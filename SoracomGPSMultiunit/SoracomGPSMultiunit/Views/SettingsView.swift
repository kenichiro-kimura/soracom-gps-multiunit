import SwiftUI

/// アプリ設定画面
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var arcConfigText: String
    @State private var showArcConfigInfo = false
    @State private var arcConfigSaveError: String?

    init(settings: AppSettings) {
        self.settings = settings
        _arcConfigText = State(initialValue: settings.arcConfigJSON)
    }

    var body: some View {
        NavigationStack {
            Form {
                temperatureSection
                humiditySection
                signalBatterySection
                fixedLocationSection
                autoSendSection
                arcConfigSection
                aboutSection
            }
            .navigationTitle("settings_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings_done", action: saveAndDismiss)
                }
            }
        }
        .alert("settings_save_failed", isPresented: Binding(
            get: { arcConfigSaveError != nil },
            set: { if !$0 { arcConfigSaveError = nil } }
        )) {
            Button("OK") {
                arcConfigSaveError = nil
            }
        } message: {
            Text(arcConfigSaveError ?? "")
        }
    }

    // MARK: - Temperature Section

    private var temperatureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedSetting("settings_base_temperature", decimal(settings.temperatureBase)))
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
                Text(formattedSetting("settings_temperature_variation", decimal(settings.temperatureVariation)))
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
            Label("settings_temperature", systemImage: "thermometer")
        } footer: {
            Text("settings_temperature_help")
                .font(.caption)
        }
    }

    // MARK: - Humidity Section

    private var humiditySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedSetting("settings_base_humidity", decimal(settings.humidityBase)))
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
                Text(formattedSetting("settings_humidity_variation", decimal(settings.humidityVariation)))
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
            Label("settings_humidity", systemImage: "humidity")
        } footer: {
            Text("settings_humidity_help")
                .font(.caption)
        }
    }

    // MARK: - Signal / Battery Section

    private var signalBatterySection: some View {
        Section {
            Stepper(
                formattedSetting("settings_signal", settings.rsValue == -1 ? String(localized: "settings_no_service") : String(settings.rsValue)),
                value: $settings.rsValue,
                in: -1...4
            )
            Stepper(
                formattedSetting("settings_battery", settings.batValue == -1 ? String(localized: "settings_charging") : String(settings.batValue)),
                value: $settings.batValue,
                in: -1...3
            )
        } header: {
            Label("settings_signal_battery", systemImage: "antenna.radiowaves.left.and.right")
        } footer: {
            Text("settings_signal_battery_help")
                .font(.caption)
        }
    }

    // MARK: - Auto Send Section

    // MARK: - Fixed Location Section

    private var fixedLocationSection: some View {
        Section {
            Toggle("settings_fixed_location", isOn: $settings.useFixedLocation)
        } header: {
            Label("settings_location", systemImage: "location.fill")
        } footer: {
            Text("settings_fixed_location_help")
                .font(.caption)
        }
    }

    private var autoSendSection: some View {
        Section {
            Toggle("settings_auto_send", isOn: $settings.defaultAutoSend)

            if settings.defaultAutoSend {
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedSetting("settings_interval", String(settings.defaultSendingInterval)))
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
            Label("settings_auto_send_title", systemImage: "clock.arrow.circlepath")
        } footer: {
            Text("settings_auto_send_help")
                .font(.caption)
        }
    }

    // MARK: - Arc Config Section

    private var arcConfigSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("settings_wireguard")
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

                TextEditor(text: $arcConfigText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Toggle("settings_udp_fallback", isOn: $settings.arcUdpFallbackEnabled)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
        } header: {
            Label("settings_arc", systemImage: "lock.shield")
        } footer: {
            Text(String(localized: "settings_arc_help") + "\n\n" + String(localized: "settings_udp_fallback_help"))
                .font(.caption)
        }
        .alert("settings_wireguard_about", isPresented: $showArcConfigInfo) {
            Button("OK") { }
        } message: {
            Text(wireGuardInfo)
        }
    }

    private var wireGuardInfo: String {
        [
            String(localized: "settings_wireguard_intro"),
            """
            [Interface]
            PrivateKey = ...
            Address = ...

            [Peer]
            PublicKey = ...
            AllowedIPs = ...
            Endpoint = ...
            """,
            String(localized: "settings_arc_help"),
            String(localized: "settings_details") + ": https://users.soracom.io/ja-jp/docs/arc/"
        ].joined(separator: "\n\n")
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("settings_about") {
            LabeledContent("settings_version") {
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("settings_build") {
                Text(Bundle.main.buildNumber)
                    .foregroundStyle(.secondary)
            }
            Link(
                destination: URL(string: "https://github.com/kenichiro-kimura/soracom-gps-multiunit")!
            ) {
                Label("settings_github", systemImage: "arrow.up.right.square")
            }
        }
    }
    
    private var licenseSeciton: some View {
        Section("settings_license") {
            Text("settings_logo_notice")
                .font(.caption)

            Link(
                destination: URL(string: "https://github.com/soracomug/logo")!
            ) {
                Label("settings_logo_source", systemImage: "arrow.up.right.square")
            }

            Link(
                destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!
            ) {
                Label("settings_cc_license", systemImage: "arrow.up.right.square")
            }
        }
    }

    private func decimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale.current, value)
    }

    private func formattedSetting(_ key: String, _ value: String) -> String {
        String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, value)
    }

    private func saveAndDismiss() {
        do {
            try settings.saveArcConfigJSON(arcConfigText)
            dismiss()
        } catch {
            arcConfigSaveError = error.localizedDescription
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
