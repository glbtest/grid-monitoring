import Testing
import Foundation
@testable import GridMonitorCore

struct DetectGridTransitionTests {

    private func status(_ present: Bool) -> GridStatus {
        GridStatus(
            isPresent: present,
            voltage: present ? 230 : 0,
            frequency: present ? 50 : 0,
            workMode: present ? .line : .battery,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    @Test func firstSnapshotIsBaselineNotEvent() {
        #expect(DetectGridTransition.transition(previous: nil, current: status(true)) == nil)
        #expect(DetectGridTransition.transition(previous: nil, current: status(false)) == nil)
    }

    @Test func noChangeProducesNoEvent() {
        #expect(DetectGridTransition.transition(previous: status(true), current: status(true)) == nil)
        #expect(DetectGridTransition.transition(previous: status(false), current: status(false)) == nil)
    }

    @Test func gridLostDetected() {
        #expect(
            DetectGridTransition.transition(previous: status(true), current: status(false)) == .gridLost
        )
    }

    @Test func gridRestoredDetected() {
        #expect(
            DetectGridTransition.transition(previous: status(false), current: status(true)) == .gridRestored
        )
    }
}
