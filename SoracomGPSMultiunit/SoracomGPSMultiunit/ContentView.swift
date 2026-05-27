import SwiftUI

/// ルートビュー
struct ContentView: View {
    @StateObject private var settings: AppSettings
    @StateObject private var viewModel: MainViewModel

    @State private var selectedTab = 0
    @State private var showSettings = false

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: MainViewModel(settings: settings))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // メインデバイス画面
            deviceTab

            // 送信ログ画面
            logTab
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Tabs

    private var deviceTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    DeviceView(viewModel: viewModel)
                        .padding(.top, 16)

                    autoSendControl
                        .padding(.horizontal)
                        .padding(.top, 12)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("GPS Multi Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    refreshButton
                }
            }
        }
        .tabItem {
            Label("デバイス", systemImage: "sensor.tag.radiowaves.forward")
        }
        .tag(0)
    }

    private var logTab: some View {
        SendLogView(viewModel: viewModel)
            .tabItem {
                Label("ログ", systemImage: "list.bullet.rectangle")
            }
            .badge(viewModel.sendLogs.filter { !$0.success }.count)
            .tag(1)
    }

    // MARK: - Auto Send Control

    private var autoSendControl: some View {
        HStack {
            Label(
                viewModel.isAutoSendEnabled
                    ? "自動送信中 (\(viewModel.sendingInterval)秒)"
                    : "自動送信: オフ",
                systemImage: "clock.arrow.2.circlepath"
            )
            .font(.subheadline)
            .foregroundStyle(viewModel.isAutoSendEnabled ? .primary : .secondary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.isAutoSendEnabled },
                set: { _ in viewModel.toggleAutoSend() }
            ))
            .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.fetchMetadataConfig()
            }
        } label: {
            if viewModel.isLoadingMetadata {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isLoadingMetadata || !viewModel.arcService.isConfigured)
    }
}

#Preview {
    ContentView()
}
