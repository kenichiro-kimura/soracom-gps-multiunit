import SwiftUI

/// GPS マルチユニット SORACOM Edition の外観を再現したビュー
struct DeviceView: View {
    @ObservedObject var viewModel: MainViewModel

    // SORACOM ティール/シアン カラー
    private let soracomTeal = Color(red: 0.31, green: 0.85, blue: 0.85)

    var body: some View {
        VStack(spacing: 20) {
            deviceCard
            dataDisplayPanel
        }
    }

    // MARK: - デバイスカード（横向き）

    private var deviceCard: some View {
        ZStack {
            // カード背景（ティール）
            RoundedRectangle(cornerRadius: 20)
                .fill(soracomTeal)

            // 白い幾何学的形状（左側 - デバイスのブランドデザイン）
            SoracomAngularShape()
                .fill(Color.white.opacity(0.88))
                .padding(.trailing, 90)
                .padding(10)

            // 右側: LED・ボタン・コネクター
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    statusLed
                    sendButton
                    connectors
                }
                .padding(.trailing, 16)
            }

            // 左下: SORACOM ブランディング
            VStack(alignment: .leading) {
                Spacer()
                HStack {
                    branding
                    Spacer()
                }
            }
        }
        .frame(width: 320, height: 202)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: soracomTeal.opacity(0.40), radius: 14, x: 0, y: 7)
    }

    // MARK: - ステータス LED（小さい円形）

    private var statusLed: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.55))
                .frame(width: 20, height: 20)
            Circle()
                .fill(ledColor(for: viewModel.connectionStatus))
                .frame(width: 12, height: 12)
                .shadow(
                    color: viewModel.connectionStatus == .connected
                        ? Color.green.opacity(0.8)
                        : (viewModel.connectionStatus == .failed
                            ? Color.red.opacity(0.8) : .clear),
                    radius: 5
                )
        }
    }

    // MARK: - 手動送信ボタン（大きい角丸四角）

    private var sendButton: some View {
        Button(action: { viewModel.manualSend() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.08))
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.28), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                Image(systemName: viewModel.isSending ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(viewModel.isSending ? .yellow : Color(white: 0.75))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSending)
        .sensoryFeedback(.impact, trigger: viewModel.isSending)
    }

    // MARK: - コネクターバー（2本）

    private var connectors: some View {
        VStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.12))
                    .frame(width: 34, height: 11)
            }
        }
    }

    // MARK: - SORACOM ブランディング

    private var branding: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SORACOM")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            Text("Edition")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.9))
            Image(systemName: "star.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)
        }
        .padding(.leading, 16)
        .padding(.bottom, 12)
    }

    // MARK: - ヘルパー

    private func ledColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
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

            if let data = viewModel.lastSensorData {
                Divider()
                sensorSection(data: data)
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

    private func sensorSection(data: SensorData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 20) {
                sensorPair(
                    label: "温度",
                    value: String(format: "%.1f°C", data.temp),
                    icon: "thermometer.medium"
                )
                sensorPair(
                    label: "湿度",
                    value: String(format: "%.1f%%", data.humi),
                    icon: "drop.fill"
                )
            }
            sensorPair(
                label: "加速度",
                value: String(format: "X:%.2f Y:%.2f Z:%.2f", data.x, data.y, data.z),
                icon: "gyroscope"
            )
            if let lat = data.lat, let lon = data.lon {
                sensorPair(
                    label: "GPS",
                    value: String(format: "%.5f, %.5f", lat, lon),
                    icon: "location.fill"
                )
            } else {
                sensorPair(label: "GPS", value: "信号なし", icon: "location.slash")
            }
        }
    }

    private func sensorPair(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(soracomTeal)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - SORACOM Angular Shape

/// デバイス前面の白い幾何学的形状（ライトニングボルト型）
struct SoracomAngularShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // 上部を右方向に広く取り、中央でくびれて下部へ繋がる Z 字型
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w * 0.80, y: 0))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.44, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Supporting Views

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
