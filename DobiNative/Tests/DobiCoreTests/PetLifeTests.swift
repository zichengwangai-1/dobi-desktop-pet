import XCTest
import CoreGraphics
@testable import DobiCore

final class PetLifeTests: XCTestCase {
    func testManualStagePersistsAndCanReturnToAutomaticGrowth() throws {
        let birthday = Date(timeIntervalSince1970: 1000)
        var life = PetLife(birthday: birthday)
        life.selectStage(.adult)
        XCTAssertEqual(life.stage(at: birthday), .adult)
        life.selectStage(nil)
        XCTAssertEqual(life.stage(at: birthday), .puppy, "Manual adulthood must not mark natural growth complete")
        XCTAssertEqual(life.stage(at: birthday.addingTimeInterval(259_200)), .adult)
        life.selectStage(.puppy)
        var restored = try JSONDecoder().decode(PetLife.self, from: JSONEncoder().encode(life))
        XCTAssertEqual(restored.selectedStage, .puppy)
        XCTAssertEqual(restored.stage(at: birthday.addingTimeInterval(600_000)), .puppy)
        restored.selectStage(nil)
        XCTAssertEqual(restored.stage(at: birthday), .adult, "Automatic mode must retain completed natural growth")
    }
    func testOldSavedLifeDefaultsToAutomaticGrowth() throws {
        let oldSave = Data(#"{"birthday":0,"hasGrown":false}"#.utf8)
        var restored = try JSONDecoder().decode(PetLife.self, from: oldSave)
        XCTAssertNil(restored.selectedStage)
        XCTAssertEqual(restored.stage(at: restored.birthday), .puppy)
    }
    // Catch early growth at a calendar-day boundary and lost growth on restart.
    func testGrowthAtExactly72HoursAndPersistsAcrossRestart() throws {
        let birthday = Date(timeIntervalSince1970: 1000)
        var life = PetLife(birthday: birthday)
        XCTAssertEqual(life.stage(at: Date(timeIntervalSince1970: 260199)), .puppy)
        XCTAssertEqual(life.remaining(at: Date(timeIntervalSince1970: 260199)), 1)
        XCTAssertEqual(life.stage(at: Date(timeIntervalSince1970: 260200)), .adult)
        var restored = try JSONDecoder().decode(PetLife.self, from: JSONEncoder().encode(life))
        XCTAssertEqual(restored.stage(at: birthday), .adult, "Clock changes must never turn an adult into a puppy")
    }
    func testClickAlwaysUsesStageSpecificInteraction() {
        XCTAssertEqual(PetAction.interaction(for: .puppy), .puppySit)
        XCTAssertEqual(PetAction.interaction(for: .adult), .adultBark)
    }
    func testAmbientClipsStayInCurrentStageAndAvoidRepeats() {
        for _ in 0..<100 {
            XCTAssertEqual(PetAction.ambient(for: .puppy, excluding: .puppyWalk), .puppySpin)
            XCTAssertEqual(PetAction.ambient(for: .adult, excluding: .adultWalk), .adultBark)
            XCTAssertTrue([PetAction.puppyWalk, .puppySpin].contains(PetAction.ambient(for: .puppy)))
        }
    }
    func testDraggingDoesNotBecomeClickWhenPointerReturns() {
        var gesture = PointerGesture()
        gesture.begin(at: CGPoint(x: 100, y: 100))
        XCTAssertFalse(gesture.move(to: CGPoint(x: 101, y: 102)))
        XCTAssertTrue(gesture.shouldInteract)
        XCTAssertTrue(gesture.move(to: CGPoint(x: 108, y: 100)))
        XCTAssertTrue(gesture.move(to: CGPoint(x: 100, y: 100)))
        XCTAssertFalse(gesture.shouldInteract)
        gesture.begin(at: .zero)
        XCTAssertTrue(gesture.shouldInteract)
    }
}
