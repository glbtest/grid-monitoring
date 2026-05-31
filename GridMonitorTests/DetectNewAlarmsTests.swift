import Testing
import Foundation
@testable import GridMonitor

struct DetectNewAlarmsTests {

    private func alarm(_ id: String, name: String = "Abnormal Mains Power Supply",
                       code: String = "4", at seconds: TimeInterval) -> Alarm {
        Alarm(id: id, deviceSN: "SN", code: code, name: name, type: "W",
              date: Date(timeIntervalSince1970: seconds), level: 1)
    }

    @Test func returnsOnlyUnseenMainsFailures() {
        let fresh = [
            alarm("a", at: 100),
            alarm("b", at: 200),
            alarm("c", name: "Battery Low", code: "9", at: 300), // не mains → ігнор
        ]
        let result = DetectNewAlarms.newMainsFailures(seenIDs: ["a"], fresh: fresh)
        #expect(result.map(\.id) == ["b"])
    }

    @Test func sortsOldestFirst() {
        let fresh = [alarm("late", at: 500), alarm("early", at: 100)]
        let result = DetectNewAlarms.newMainsFailures(seenIDs: [], fresh: fresh)
        #expect(result.map(\.id) == ["early", "late"])
    }

    @Test func emptyWhenAllSeen() {
        let fresh = [alarm("a", at: 100), alarm("b", at: 200)]
        #expect(DetectNewAlarms.newMainsFailures(seenIDs: ["a", "b"], fresh: fresh).isEmpty)
    }
}
