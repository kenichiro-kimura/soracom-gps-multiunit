import XCTest
@testable import SoracomGPSMultiunitCore

final class SensorDataTests: XCTestCase {

    func testSensorDataEncodingIncludesAllFields() throws {
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

    func testSensorDataDecodingFromJSON() throws {
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

    func testSensorDataEquality() {
        let data1 = SensorData(temp: 25.0, humi: 60.0, x: 0.0, y: 0.0, z: 1000.0, type: .periodic)
        let data2 = SensorData(temp: 25.0, humi: 60.0, x: 0.0, y: 0.0, z: 1000.0, type: .periodic)
        XCTAssertEqual(data1, data2)
    }
}

final class MetadataConfigTests: XCTestCase {

    func testMetadataConfigDefaultValues() {
        let config = MetadataConfig()
        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingInterval, 60)
        XCTAssertTrue(config.sendLocation)
    }

    func testMetadataConfigDecoding() throws {
        let json = """
        {
            "autoSend": false,
            "sendingInterval": 30,
            "sendLocation": false
        }
        """
        let config = try JSONDecoder().decode(MetadataConfig.self, from: json.data(using: .utf8)!)

        XCTAssertFalse(config.autoSend)
        XCTAssertEqual(config.sendingInterval, 30)
        XCTAssertFalse(config.sendLocation)
    }

    func testMetadataConfigEquality() {
        let c1 = MetadataConfig(autoSend: true, sendingInterval: 60, sendLocation: true)
        let c2 = MetadataConfig(autoSend: true, sendingInterval: 60, sendLocation: true)
        XCTAssertEqual(c1, c2)
    }
}

final class SoracomArcServiceTests: XCTestCase {

    func testLibsoratunArcServiceNotConfiguredByDefault() {
        let service = LibsoratunArcService()
        XCTAssertFalse(service.isConfigured)
    }

    func testLibsoratunArcServiceConfigureWithEmptyStringThrows() {
        let service = LibsoratunArcService()
        XCTAssertThrowsError(try service.configure(with: "")) { error in
            guard let arcError = error as? SoracomArcError,
                  case .notConfigured = arcError else {
                XCTFail("Expected notConfigured error, got: \(error)")
                return
            }
        }
    }

    func testLibsoratunArcServiceConfigureWithInvalidJSONThrows() {
        let service = LibsoratunArcService()
        XCTAssertThrowsError(try service.configure(with: "not valid json")) { error in
            guard let arcError = error as? SoracomArcError,
                  case .invalidConfiguration = arcError else {
                XCTFail("Expected invalidConfiguration error, got: \(error)")
                return
            }
        }
    }

    func testLibsoratunArcServiceConfigureWithValidJSONSucceeds() throws {
        let service = LibsoratunArcService()
        let validJSON = """
        {"privateKey": "base64key==", "endpoint": "10.0.0.1:11010"}
        """
        XCTAssertNoThrow(try service.configure(with: validJSON))
        XCTAssertTrue(service.isConfigured)
    }

    func testMockArcServiceSuccessfulSend() async throws {
        let mock = MockArcService()
        mock.mockResponse = "{\"result\": \"ok\"}"
        let response = try await mock.sendHTTP(path: "/", method: "POST", body: "{}")
        XCTAssertEqual(response, "{\"result\": \"ok\"}")
    }

    func testMockArcServiceFailure() async {
        let mock = MockArcService()
        mock.shouldFail = true
        do {
            _ = try await mock.sendHTTP(path: "/", method: "POST", body: "{}")
            XCTFail("Expected error to be thrown")
        } catch let error as SoracomArcError {
            guard case .sendFailed = error else {
                XCTFail("Expected sendFailed error, got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected SoracomArcError, got: \(error)")
        }
    }
}

final class MetadataServiceTests: XCTestCase {

    func testFetchConfigSuccess() async throws {
        let mock = MockArcService()
        mock.mockResponse = """
        {"autoSend": true, "sendingInterval": 30, "sendLocation": false}
        """
        let service = MetadataService(arcService: mock)
        let config = try await service.fetchConfig()

        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingInterval, 30)
        XCTAssertFalse(config.sendLocation)
    }

    func testFetchConfigWithArcFailureThrows() async {
        let mock = MockArcService()
        mock.shouldFail = true
        let service = MetadataService(arcService: mock)

        do {
            _ = try await service.fetchConfig()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is SoracomArcError)
        }
    }
}

final class DataSendingServiceTests: XCTestCase {

    func testSendSensorDataSuccess() async throws {
        let mock = MockArcService()
        mock.mockResponse = "{}"
        let service = DataSendingService(arcService: mock)

        let data = SensorData(
            lat: 35.0, lon: 139.0, temp: 25.0, humi: 60.0,
            x: 0.0, y: 0.0, z: 1000.0, type: .manual
        )
        let response = try await service.send(data)
        XCTAssertEqual(response, "{}")
    }
}

final class SensorValueGeneratorTests: XCTestCase {

    func testTemperatureWithinRange() {
        let gen = SensorValueGenerator(
            temperatureBase: 20.0,
            temperatureVariation: 2.0,
            humidityBase: 60.0,
            humidityVariation: 5.0
        )

        for _ in 0..<1000 {
            let temp = gen.generateTemperature()
            XCTAssertGreaterThanOrEqual(temp, 18.0 - 0.05)
            XCTAssertLessThanOrEqual(temp, 22.0 + 0.05)
        }
    }

    func testHumidityWithinRange() {
        let gen = SensorValueGenerator(
            temperatureBase: 20.0,
            temperatureVariation: 2.0,
            humidityBase: 60.0,
            humidityVariation: 5.0
        )

        for _ in 0..<1000 {
            let humi = gen.generateHumidity()
            XCTAssertGreaterThanOrEqual(humi, 55.0 - 0.05)
            XCTAssertLessThanOrEqual(humi, 65.0 + 0.05)
        }
    }

    func testHumidityClampedToValidRange() {
        // ベース値が0に近く、大きな変動幅でも0を下回らない
        let gen = SensorValueGenerator(
            temperatureBase: 20.0,
            temperatureVariation: 2.0,
            humidityBase: 2.0,
            humidityVariation: 10.0
        )

        for _ in 0..<1000 {
            let humi = gen.generateHumidity()
            XCTAssertGreaterThanOrEqual(humi, 0.0)
            XCTAssertLessThanOrEqual(humi, 100.0)
        }
    }

    func testTemperatureRounding() {
        let gen = SensorValueGenerator(
            temperatureBase: 25.12345,
            temperatureVariation: 0.0,
            humidityBase: 60.0,
            humidityVariation: 0.0
        )
        let temp = gen.generateTemperature()
        // 小数点第1位まで
        XCTAssertEqual(temp, 25.1)
    }
}

final class ComparableClampedTests: XCTestCase {

    func testClampedBelowRange() {
        XCTAssertEqual((-10.0).clamped(to: 0...100), 0.0)
    }

    func testClampedAboveRange() {
        XCTAssertEqual(110.0.clamped(to: 0...100), 100.0)
    }

    func testClampedWithinRange() {
        XCTAssertEqual(50.0.clamped(to: 0...100), 50.0)
    }

    func testConnectionStatusDisplayText() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayText, "未接続")
        XCTAssertEqual(ConnectionStatus.connecting.displayText, "接続中...")
        XCTAssertEqual(ConnectionStatus.connected.displayText, "接続済み")
        XCTAssertEqual(ConnectionStatus.failed("err").displayText, "接続失敗")
    }
}
