import XCTest
@testable import DobiCore

final class IdlePoopTests: XCTestCase {
    func testExactlyFiveMinutesAndOnlyOneUnclearedPoop() {
        var session = IdlePoopSession(now: 100)
        XCTAssertFalse(session.beginIfDue(at: 399.999, canStart: true))
        XCTAssertTrue(session.beginIfDue(at: 400, canStart: true))
        XCTAssertEqual(session.phase, .animating)
        XCTAssertFalse(session.beginIfDue(at: 1000, canStart: true))
        session.completeAnimation()
        XCTAssertEqual(session.phase, .visible)
        XCTAssertFalse(session.beginIfDue(at: 2000, canStart: true))
        session.clear(at: 2000)
        XCTAssertFalse(session.beginIfDue(at: 2299, canStart: true))
        XCTAssertTrue(session.beginIfDue(at: 2300, canStart: true))
    }
    func testActivityResetsDeadlineAndBusyPlaybackDefersWithoutLosingIt() {
        var session = IdlePoopSession(now: 0)
        session.registerActivity(at: 299)
        XCTAssertFalse(session.beginIfDue(at: 300, canStart: true))
        XCTAssertFalse(session.beginIfDue(at: 599, canStart: false))
        XCTAssertEqual(session.phase, .waiting)
        XCTAssertTrue(session.beginIfDue(at: 600, canStart: true))
        session.registerActivity(at: 601)
        XCTAssertEqual(session.phase, .animating, "Clicking cannot leave a half-finished poop animation")
        session.completeAnimation()
        XCTAssertFalse(session.beginIfDue(at: 1000, canStart: true))
    }
    func testRestoredPoopRemainsUntilClearedAndUsesAgeSpecificAction() {
        var session = IdlePoopSession(now: 0, hasPoop: true)
        XCTAssertFalse(session.beginIfDue(at: 10000, canStart: true))
        session.clear(at: 10000)
        XCTAssertTrue(session.beginIfDue(at: 10300, canStart: true))
        XCTAssertEqual(PetAction.pooping(for: .puppy).rawValue, "puppy_poop")
        XCTAssertEqual(PetAction.pooping(for: .adult).rawValue, "adult_poop")
    }
}
