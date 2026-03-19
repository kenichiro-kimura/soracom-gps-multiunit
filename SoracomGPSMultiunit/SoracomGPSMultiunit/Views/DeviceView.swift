import SwiftUI

/// GPS マルチユニット SORACOM Edition の外観を再現したビュー
struct DeviceView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 24) {
            deviceBody
            dataDisplayPanel
        }
    }

    // MARK: - デバイス本体

    private var deviceBody: some View {
        ZStack {
            // デバイス外装
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 280)
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)

            // デバイス内部パネル
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.14))
                .frame(width: 180, height: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )

            VStack(spacing: 16) {
                // SORACOM ロゴエリア
                VStack(spacing: 4) {
                    Text("SORACOM")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.6, blue: 1.0))
                    Text("GPS Multi Unit")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                }
                .padding(.top, 8)

                // LED インジケーター
                ledIndicators

                // センサー値表示
                sensorReadout

                // 手動送信ボタン
                manualSendButton

                Spacer(minLength: 4)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - LED インジケーター

    private var ledIndicators: some View {
        HStack(spacing: 12) {
            LedView(
                color: ledColor(for: viewModel.connectionStatus),
                label: "ARC",
                isActive: viewModel.connectionStatus == .connected
            )
            LedView(
                color: viewModel.isAutoSendEnabled ? .green : .gray,
                label: "AUTO",
                isActive: viewModel.isAutoSendEnabled
            )
            LedView(
                color: viewModel.isSending ? .yellow : .clear,
                label: "TX",
                isActive: viewModel.isSending
            )
        }
    }

    private func ledColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
    }

    // MARK: - センサー値表示

    private var sensorReadout: some View {
        VStack(spacing: 6) {
            if let data = viewModel.lastSensorData {
                SensorReadoutRow(label: "TEMP", value: String(format: "%.1f°C", data.temp))
                SensorReadoutRow(label: "HUMI", value: String(format: "%.1f%%", data.humi))
                SensorReadoutRow(
                    label: "ACCEL",
                    value: String(format: "%.2f/%.2f/%.2f", data.x, data.y, data.z)
                )
                if let lat = data.lat, let lon = data.lon {
                    SensorReadoutRow(label: "LAT", value: String(format: "%.5f", lat))
                    SensorReadoutRow(label: "LON", value: String(format: "%.5f", lon))
                } else {
                    SensorReadoutRow(label: "GPS", value: "N/A")
                }
            } else {
                Text("-- NO DATA --")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.2), lineWidth: 0.5)
                )
        )
        .frame(width: 158)
    }

    // MARK: - 手動送信ボタン

    private var manualSendButton: some View {
        Button(action: { viewModel.manualSend() }) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.35), Color(white: 0.22)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 28
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.45), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(viewModel.isSending ? .yellow : Color(white: 0.7))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSending)
        .sensoryFeedback(.impact, trigger: viewModel.isSending)
    }

    // MARK: - データ表示パネル

    private var dataDisplayPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ステータス")
                    .font(.headline)
                Spacer()
                StatusBadge(status: viewModel.connectionStatus)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        viewModel.isAutoSendEnabled
                            ? "自動送信: \(viewModel.sendingInterval)秒間隔"
                            : "手動送信",
                        systemImage: viewModel.isAutoSendEnabled
                            ? "clock.fill" : "hand.tap"
                    )
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isAutoSendEnabled ? .green : .secondary)

                    if let lastSent = viewModel.lastSentAt {
                        Text("最終送信: \(lastSent.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let error = viewModel.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

/// LED ランプビュー
struct LedView: View {
    let color: Color
    let label: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.1))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(isActive ? color : Color(white: 0.15))
                    .frame(width: 10, height: 10)
                    .shadow(color: isActive ? color.opacity(0.8) : .clear, radius: 4)
            }
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
        }
    }
}

/// センサー値の1行表示
struct SensorReadoutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.0, green: 0.6, blue: 1.0))
                .frame(width: 46, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(white: 0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// 接続ステータスバッジ
struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(badgeColor.opacity(0.3), lineWidth: 1))
    }

    private var badgeColor: Color {
        switch status {
        case .disconnected: return .secondary
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    let settings = AppSettings()
    let viewModel = MainViewModel(settings: settings, arcService: MockArcService())
    return DeviceView(viewModel: viewModel)
        .padding()
        .background(Color(uiColor: .systemBackground))
}
