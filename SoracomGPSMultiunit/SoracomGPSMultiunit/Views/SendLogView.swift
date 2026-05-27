import SwiftUI

/// 送信ログ画面
struct SendLogView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sendLogs.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
            .navigationTitle("送信ログ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.sendLogs.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("消去", role: .destructive) {
                            viewModel.sendLogs.removeAll()
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "送信ログなし",
            systemImage: "doc.text",
            description: Text("データを送信するとここにログが表示されます。")
        )
    }

    private var logList: some View {
        List(viewModel.sendLogs) { log in
            SendLogRow(log: log)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Log Row

struct SendLogRow: View {
    let log: SendLog

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(log.success ? .green : .red)

                Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.subheadline.bold())

                Spacer()

                Text(sendTypeLabel(log.data.type))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            if !log.success, let error = log.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("センサー値を\(isExpanded ? "閉じる" : "表示")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                dataGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private var dataGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let temp = log.data.temp, let humi = log.data.humi {
                HStack(spacing: 16) {
                    DataCell(label: "温度", value: String(format: "%.1f°C", temp))
                    DataCell(label: "湿度", value: String(format: "%.1f%%", humi))
                }
            }
            if let x = log.data.x, let y = log.data.y, let z = log.data.z {
                HStack(spacing: 16) {
                    DataCell(label: "X", value: String(format: "%.0f mG", x))
                    DataCell(label: "Y", value: String(format: "%.0f mG", y))
                    DataCell(label: "Z", value: String(format: "%.0f mG", z))
                }
            }
            if let lat = log.data.lat, let lon = log.data.lon {
                HStack(spacing: 16) {
                    DataCell(label: "緯度", value: String(format: "%.5f", lat))
                    DataCell(label: "経度", value: String(format: "%.5f", lon))
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sendTypeLabel(_ type: SendType) -> String {
        switch type {
        case .periodic: return "自動"
        case .manual: return "手動"
        case .accelerationAlert: return "加速度"
        }
    }
}

// MARK: - Data Cell

struct DataCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
        }
    }
}

#Preview {
    let settings = AppSettings()
    let viewModel = MainViewModel(settings: settings, arcService: MockArcService())
    return SendLogView(viewModel: viewModel)
}
