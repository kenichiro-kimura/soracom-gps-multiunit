import XCTest
@testable import SoracomGPSMultiunit

final class SoracomGPSMultiunitTests: XCTestCase {

    // MARK: - SensorData Tests

    func testSensorDataEncoding() throws {
        let data = SensorData(
            lat: 35.12345,
            lon: 139.12345,
            temp: 25.5,
            humi: 60.0,
            x: 10.0,
            y: -20.0,
            z: 980.0,
            bat: nil,
            rs: nil,
            type: .periodic
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["lat"] as? Double, 35.12345)
        XCTAssertEqual(json?["lon"] as? Double, 139.12345)
        XCTAssertEqual(json?["temp"] as? Double, 25.5)
        XCTAssertEqual(json?["humi"] as? Double, 60.0)
        XCTAssertEqual(json?["type"] as? Int, 0)
    }

    func testSensorDataDecoding() throws {
        let json = """
        {
            "lat": 35.12345,
            "lon": 139.12345,
            "temp": 25.5,
            "humi": 60.0,
            "x": 10,
            "y": -20,
            "z": 980,
            "type": 1
        }
        """
        let data = try JSONDecoder().decode(SensorData.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(data.lat, 35.12345)
        XCTAssertEqual(data.temp, 25.5)
        XCTAssertEqual(data.type, .manual)
        XCTAssertNil(data.bat)
        XCTAssertNil(data.rs)
    }

    func testSendTypeRawValues() {
        XCTAssertEqual(SendType.periodic.rawValue, 0)
        XCTAssertEqual(SendType.manual.rawValue, 1)
        XCTAssertEqual(SendType.accelerationAlert.rawValue, 2)
    }

    // MARK: - MetadataConfig Tests

    func testMetadataConfigDecoding() throws {
        let json = """
        {
            "SensorData": {
                "acc": {"i1": "ON"},
                "loc": {"i1": "OFF"},
                "tem": {"i1": "ON"},
                "hum": {"i1": "ON"},
                "bat": {"i1": "ON"}
            },
            "Common": {
                "C1": ["null"],
                "C2": ["null"],
                "C3": ["null"],
                "C4": ["null"],
                "C5": [30],
                "C6": ["null"],
                "C7": "0"
            },
            "Setting": {
                "itr": {"i2": 620}
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(MetadataConfig.self, from: json.data(using: .utf8)!)

        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingIntervalSeconds, 1800)
        XCTAssertFalse(config.sendLocation)
    }

    func testMetadataConfigDisablesAutoSendForInactiveSchedule() throws {
        let json = """
        {
            "SensorData": {
                "acc": {"i1": "OFF"},
                "loc": {"i1": "ON"},
                "tem": {"i1": "ON"},
                "hum": {"i1": "OFF"},
                "bat": {"i1": "ON"}
            },
            "Common": {
                "C1": ["null"],
                "C2": ["null"],
                "C3": ["null"],
                "C4": ["null"],
                "C5": [-20000],
                "C6": ["null"],
                "C7": "0"
            },
            "Setting": {
                "itr": {"i2": 500}
            }
        }
        """
        let config = try JSONDecoder().decode(MetadataConfig.self, from: json.data(using: .utf8)!)

        XCTAssertFalse(config.autoSend)
        XCTAssertNil(config.sendingIntervalSeconds)
        XCTAssertTrue(config.sendLocation)
    }

    // MARK: - AppSettings Tests

    func testAppSettingsDefaults() {
        let suiteName = "SoracomGPSMultiunitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: defaults)
        XCTAssertEqual(settings.temperatureBase, 25.0)
        XCTAssertEqual(settings.temperatureVariation, 2.0)
        XCTAssertEqual(settings.humidityBase, 60.0)
        XCTAssertEqual(settings.humidityVariation, 5.0)
        XCTAssertEqual(settings.defaultSendingInterval, 60)
        XCTAssertFalse(settings.defaultAutoSend)
    }

    // MARK: - SoracomArcService Tests

    func testLibsoratunArcServiceConfigurationWithEmptyJSON() {
        let service = LibsoratunArcService()
        XCTAssertFalse(service.isConfigured)

        XCTAssertThrowsError(try service.configure(with: "")) { error in
            XCTAssertTrue(error is SoracomArcError)
        }
    }

    func testLibsoratunArcServiceConfigurationWithInvalidJSON() {
        let service = LibsoratunArcService()
        XCTAssertThrowsError(try service.configure(with: "not valid json")) { error in
            guard let arcError = error as? SoracomArcError,
                  case .invalidConfiguration = arcError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
        }
    }

    func testLibsoratunArcServiceConfigurationWithValidJSON() throws {
        let service = LibsoratunArcService()
        let validJSON = """
        [Interface]
        PrivateKey = base64key==
        Address = 10.0.0.2/32

        [Peer]
        PublicKey = base64pub==
        AllowedIPs = 100.127.0.0/16, 192.168.0.0/24
        Endpoint = 10.0.0.1:11010
        """
        XCTAssertNoThrow(try service.configure(with: validJSON))
        XCTAssertTrue(service.isConfigured)
    }

    func testMockArcServiceSend() async throws {
        let mock = MockArcService()
        mock.mockResponse = "{\"result\": \"ok\"}"
        let response = try await mock.sendHTTP(path: "/", method: "POST", body: "{}")
        XCTAssertEqual(response, "{\"result\": \"ok\"}")
    }

    func testMockArcServiceSendFailure() async {
        let mock = MockArcService()
        mock.shouldFail = true
        do {
            _ = try await mock.sendHTTP(path: "/", method: "POST", body: "{}")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SoracomArcError)
        }
    }

    // MARK: - MainViewModel Tests

    @MainActor
    func testMainViewModelInitialState() {
        let settings = AppSettings()
        let viewModel = MainViewModel(settings: settings, arcService: MockArcService())

        XCTAssertNil(viewModel.lastSensorData)
        XCTAssertNil(viewModel.lastSentAt)
        XCTAssertFalse(viewModel.isAutoSendEnabled)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertTrue(viewModel.sendLogs.isEmpty)
    }

    @MainActor
    func testMainViewModelManualSend() async {
        let settings = AppSettings()
        let mock = MockArcService()
        let viewModel = MainViewModel(settings: settings, arcService: mock)

        viewModel.manualSend()
        // Allow async task to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.lastSensorData)
        XCTAssertEqual(viewModel.sendLogs.count, 1)
        XCTAssertTrue(viewModel.sendLogs[0].success)
        XCTAssertEqual(viewModel.lastSensorData?.type, .manual)
    }

    @MainActor
    func testTemperatureGeneration() {
        let settings = AppSettings()
        settings.temperatureBase = 20.0
        settings.temperatureVariation = 1.0
        let viewModel = MainViewModel(settings: settings, arcService: MockArcService())

        // Generate multiple times and check within range
        for _ in 0..<100 {
            viewModel.manualSend()
        }
        // Temperature should always be within base ± variation
        if let data = viewModel.lastSensorData, let temp = data.temp {
            XCTAssertGreaterThanOrEqual(temp, settings.temperatureBase - settings.temperatureVariation - 0.1)
            XCTAssertLessThanOrEqual(temp, settings.temperatureBase + settings.temperatureVariation + 0.1)
        }
    }

    // MARK: - ConnectionStatus Tests

    func testConnectionStatusDisplayText() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayText, "未接続")
        XCTAssertEqual(ConnectionStatus.connecting.displayText, "接続中...")
        XCTAssertEqual(ConnectionStatus.connected.displayText, "接続済み")
        XCTAssertEqual(ConnectionStatus.failed("err").displayText, "接続失敗")
    }
}
