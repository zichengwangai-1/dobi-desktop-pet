import XCTest
@testable import DobiCore

final class IdlePoopTests: XCTestCase {
    func testEveryFiveMinutesCanAddAnotherPoopWithoutCleaning() {
        var session = IdlePoopSession(now: 100)
        XCTAssertFalse(session.beginIfDue(at: 399.999, canStart: true))
        XCTAssertTrue(session.beginIfDue(at: 400, canStart: true))
        XCTAssertFalse(session.beginIfDue(at: 401, canStart: true))
        session.completeAnimation()
        XCTAssertFalse(session.beginIfDue(at: 699.999, canStart: true))
        for cycle in 1...100 {
            XCTAssertTrue(session.beginIfDue(at: 400 + Double(cycle) * 300, canStart: true))
            session.completeAnimation()
        }
    }
    func testActivityResetsDeadlineAndBusyPlaybackDefersWithoutLosingIt() {
        var session = IdlePoopSession(now: 0)
        session.registerActivity(at: 299)
        XCTAssertFalse(session.beginIfDue(at: 300, canStart: true))
        XCTAssertFalse(session.beginIfDue(at: 599, canStart: false))
        XCTAssertTrue(session.beginIfDue(at: 600, canStart: true))
        session.registerActivity(at: 601)
        XCTAssertEqual(session.phase, .animating)
        session.completeAnimation()
        XCTAssertFalse(session.beginIfDue(at: 900, canStart: true))
        XCTAssertTrue(session.beginIfDue(at: 901, canStart: true))
    }
    func testEveryManualClickQueuesOneAnimationEvenWhenBusy() {
        var session = IdlePoopSession(now: 0)
        for _ in 0..<1000 { session.requestManual() }
        XCTAssertEqual(session.pendingManualRequests, 1000)
        XCTAssertFalse(session.beginIfDue(at: 0, canStart: false))
        XCTAssertEqual(session.pendingManualRequests, 1000, "Busy playback cannot discard clicks")
        for remaining in stride(from: 999, through: 0, by: -1) {
            XCTAssertTrue(session.beginIfDue(at: 0, canStart: true))
            XCTAssertEqual(session.pendingManualRequests, remaining)
            session.requestManual()
            XCTAssertFalse(session.beginIfDue(at: 0, canStart: true), "An active animation cannot be interrupted")
            session.completeAnimation()
            XCTAssertTrue(session.beginIfDue(at: 0, canStart: true))
            session.completeAnimation()
        }
        XCTAssertFalse(session.beginIfDue(at: 0, canStart: true))
        XCTAssertTrue(session.beginIfDue(at: 300, canStart: true), "Automatic cycles still work after queued demos")
    }
}
