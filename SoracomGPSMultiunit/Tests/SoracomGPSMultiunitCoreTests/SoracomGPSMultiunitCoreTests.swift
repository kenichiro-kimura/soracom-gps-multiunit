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

    private let fullMetadataJSON = """
    {
        "SensorData": {
            "acc": {"i1": "ON"},
            "loc": {"i1": "ON"},
            "tem": {"i1": "ON"},
            "hum": {"i1": "ON"},
            "bat": {"i1": "ON"}
        },
        "Common": {
            "C1": ["null","null","null","null","null","1981/04/01","1981/04/01","1981/04/01","null","null"],
            "C2": ["null","null","null","null","null","2059/12/31","2059/12/31","2059/12/31","null","null"],
            "C3": ["null","null","null","null","null","00:00","00:00","00:00","null","null"],
            "C4": ["null","null","null","null","null","23:59","23:59","23:59","null","null"],
            "C5": [-20000,-20000,-20000,-20000,-20000,10,1440,2160,-20000,-20000],
            "C6": ["null","null","null","null","null",["SUN","MON","TUE","WED","THU","FRI","SAT"],["SUN","MON","TUE","WED","THU","FRI","SAT"],["SUN","MON","TUE","WED","THU","FRI","SAT"],"null","null"],
            "C7": "5,6,7"
        },
        "Setting": {
            "itr": {"i2": 620}
        }
    }
    """

    func testMetadataConfigDecoding() throws {
        let config = try JSONDecoder().decode(MetadataConfig.self,
                                             from: fullMetadataJSON.data(using: .utf8)!)

        XCTAssertTrue(config.sendLocation)
        XCTAssertTrue(config.sendTemperature)
        XCTAssertTrue(config.sendHumidity)
        XCTAssertTrue(config.sendAcceleration)
        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingIntervalSeconds, 600)  // 10 分 × 60 秒
        XCTAssertEqual(config.accelerometerThreshold, 620)
    }

    func testMetadataConfigSensorDisabled() throws {
        let json = """
        {
            "SensorData": {
                "acc": {"i1": "OFF"},
                "loc": {"i1": "OFF"},
                "tem": {"i1": "ON"},
                "hum": {"i1": "ON"},
                "bat": {"i1": "ON"}
            },
            "Common": {
                "C1": ["null","null","null","null","null","1981/04/01","null","null","null","null"],
                "C2": ["null","null","null","null","null","2059/12/31","null","null","null","null"],
                "C3": ["null","null","null","null","null","00:00","null","null","null","null"],
                "C4": ["null","null","null","null","null","23:59","null","null","null","null"],
                "C5": [-20000,-20000,-20000,-20000,-20000,60,-20000,-20000,-20000,-20000],
                "C6": ["null","null","null","null","null",["MON","TUE","WED","THU","FRI"],"null","null","null","null"],
                "C7": "5"
            },
            "Setting": {
                "itr": {"i2": 500}
            }
        }
        """
        let config = try JSONDecoder().decode(MetadataConfig.self, from: json.data(using: .utf8)!)

        XCTAssertFalse(config.sendLocation)
        XCTAssertFalse(config.sendAcceleration)
        XCTAssertTrue(config.sendTemperature)
        XCTAssertEqual(config.sendingIntervalSeconds, 3600)  // 60 分 × 60 秒
        XCTAssertEqual(config.accelerometerThreshold, 500)
    }

    func testMetadataConfigEquality() throws {
        let data = fullMetadataJSON.data(using: .utf8)!
        let c1 = try JSONDecoder().decode(MetadataConfig.self, from: data)
        let c2 = try JSONDecoder().decode(MetadataConfig.self, from: data)
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
        {
            "privateKey": "base64key==",
            "arcSessionStatus": {
                "arcServerPeerPublicKey": "base64pub==",
                "arcServerEndpoint": "10.0.0.1:11010",
                "arcAllowedIPs": ["100.127.0.0/16", "192.168.0.0/24"],
                "arcClientPeerIpAddress": "10.0.0.2"
            }
        }
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
        let service = MetadataService(arcService: mock)
        let config = try await service.fetchConfig()

        XCTAssertTrue(config.autoSend)
        XCTAssertEqual(config.sendingIntervalSeconds, 1800)
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
