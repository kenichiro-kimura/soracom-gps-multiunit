import XCTest
@testable import SoracomGPSMultiunit

final class SoracomGPSMultiunitTests: XCTestCase {

    // MARK: - SensorData Tests

    func testSensorDataEncoding() throws {
        let data = SensorData(
            lat: 35.12345,
            lon: 139.12345,
            alt: 10.0,
            speed: 0.0,
            temp: 25.5,
            humi: 60.0,
            x: 0.01,
            y: -0.02,
            z: 0.98,
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
            "alt": 10.0,
            "speed": 0.0,
            "temp": 25.5,
            "humi": 60.0,
            "x": 0.01,
            "y": -0.02,
            "z": 0.98,
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
            "autoSend": true,
            "sendingInterval": 30,
            "sendLocation": false
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(MetadataConfig.self, from: json.data(using: .utf8)!)

        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingInterval, 30)
        XCTAssertFalse(config.sendLocation)
    }

    func testMetadataConfigDefaults() {
        let config = MetadataConfig()
        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingInterval, 60)
        XCTAssertTrue(config.sendLocation)
    }

    // MARK: - AppSettings Tests

    func testAppSettingsDefaults() {
        let settings = AppSettings()
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
        {
            "privateKey": "base64key==",
            "publicKey": "base64key==",
            "endpoint": "10.0.0.1:11010"
        }
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
        if let data = viewModel.lastSensorData {
            XCTAssertGreaterThanOrEqual(data.temp, settings.temperatureBase - settings.temperatureVariation - 0.1)
            XCTAssertLessThanOrEqual(data.temp, settings.temperatureBase + settings.temperatureVariation + 0.1)
        }
    }

    // MARK: - Comparable Extension Tests

    func testClampedExtension() {
        XCTAssertEqual((-10.0).clamped(to: 0...100), 0.0)
        XCTAssertEqual(110.0.clamped(to: 0...100), 100.0)
        XCTAssertEqual(50.0.clamped(to: 0...100), 50.0)
    }

    // MARK: - ConnectionStatus Tests

    func testConnectionStatusDisplayText() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayText, "未接続")
        XCTAssertEqual(ConnectionStatus.connecting.displayText, "接続中...")
        XCTAssertEqual(ConnectionStatus.connected.displayText, "接続済み")
        XCTAssertEqual(ConnectionStatus.failed("err").displayText, "接続失敗")
    }
}
