import Testing
import Foundation
@testable import GridMonitorCore

struct DTOMappingTests {
    private let decoder = JSONDecoder()

    private func snapshot(from json: String) throws -> RealtimeSnapshot {
        let env = try decoder.decode(APIResponse<RealtimeDTO>.self, from: Data(json.utf8))
        return try #require(env.data).toSnapshot(now: Date(timeIntervalSince1970: 0))
    }

    @Test func gridOnSnapshotMapsFields() throws {
        let json = """
        {"code":200,"message":"Success","data":{
          "acRInVolt":"218.3","acRInFreq":"49.98","workModeStr":"Line Mode",
          "emsSoc":"99","emsVoltage":"54","emsCurrent":"9","dataTime":1780215900000}}
        """
        let s = try snapshot(from: json)
        #expect(s.grid.isPresent)
        #expect(s.grid.voltage == 218.3)
        #expect(s.grid.frequency == 49.98)
        #expect(s.grid.workMode == .line)
        #expect(s.battery.soc == 99)
        #expect(s.battery.voltage == 54)
    }

    @Test func gridOffWhenVoltageLowAndBatteryMode() throws {
        let json = """
        {"code":200,"message":"Success","data":{
          "acRInVolt":"0","acRInFreq":"0","workModeStr":"Battery Mode",
          "emsSoc":"80","dataTime":1780215900000}}
        """
        let s = try snapshot(from: json)
        #expect(!s.grid.isPresent)
        #expect(s.grid.workMode == .battery)
        #expect(s.battery.soc == 80)
    }

    @Test func socFallsBackToEmsSocAvgThenBattSoc() throws {
        let json = """
        {"code":200,"message":"Success","data":{"acRInVolt":"230","emsSocAvg":"55"}}
        """
        let s = try snapshot(from: json)
        #expect(s.battery.soc == 55)
    }

    @Test func alarmListMapsMainsFailure() throws {
        let json = """
        {"code":200,"message":"Success","data":{"dataList":[
          {"warringId":"1","deviceSn":"SN","warnCode":"4",
           "warringName":"Abnormal Mains Power Supply","warringType":"W","dataTime":1780127116000}]}}
        """
        let env = try decoder.decode(APIResponse<AlarmListData>.self, from: Data(json.utf8))
        let alarms = (try #require(env.data).dataList ?? []).compactMap { $0.toDomain() }
        #expect(alarms.count == 1)
        #expect(alarms[0].isMainsFailure)
    }

    @Test func jwtExpirationParsedFromBearerToken() {
        // payload: {"exp":1781770459}
        let token = "Bearer_eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3ODE3NzA0NTl9.sig"
        let session = LoginData(token: token).toSession()
        #expect(session.expiresAt == Date(timeIntervalSince1970: 1781770459))
    }
}
