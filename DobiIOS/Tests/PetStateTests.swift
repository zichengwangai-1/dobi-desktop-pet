import XCTest
@testable import DobiWidgetCore

final class PetStateTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000)

    func testExactGrowthBoundaryAndManualAppearance() {
        var state = PetState(now: start)
        state.advance(to: start.addingTimeInterval(259_199))
        XCTAssertEqual(state.stage(for: .automatic), .puppy)
        XCTAssertEqual(state.stage(for: .adult), .adult)
        state.advance(to: start.addingTimeInterval(259_200))
        XCTAssertEqual(state.stage(for: .automatic), .adult)
        XCTAssertEqual(state.stage(for: .puppy), .puppy)
        state.advance(to: start)
        XCTAssertEqual(state.stage(for: .automatic), .adult)
    }
    func testMissedRefreshAccumulatesEveryIdlePeriodWithoutDoubleCounting() {
        var state = PetState(now: start)
        state.advance(to: start.addingTimeInterval(299))
        XCTAssertEqual(state.poopCount, 0)
        state.advance(to: start.addingTimeInterval(300))
        XCTAssertEqual(state.poopCount, 1)
        state.advance(to: start.addingTimeInterval(1_810))
        XCTAssertEqual(state.poopCount, 6)
        state.advance(to: start.addingTimeInterval(1_810))
        XCTAssertEqual(state.poopCount, 6)
        XCTAssertEqual(state.nextIdleDate, start.addingTimeInterval(2_100))
    }
    func testEveryFoodTapCountsAndResetsInactivity() {
        var state = PetState(now: start)
        for _ in 0..<20 { state.perform(.feed, at: start.addingTimeInterval(299)) }
        XCTAssertEqual(state.foodCount, 20)
        state.advance(to: start.addingTimeInterval(598))
        XCTAssertEqual(state.poopCount, 0)
        state.advance(to: start.addingTimeInterval(599))
        XCTAssertEqual(state.poopCount, 1)
    }
    func testCleaningRemovesOnePileAndLeavesOtherPiles() {
        var state = PetState(now: start)
        state.advance(to: start.addingTimeInterval(900))
        state.perform(.clean, at: start.addingTimeInterval(901))
        XCTAssertEqual(state.poopCount, 2)
        state.perform(.clean, at: start.addingTimeInterval(902))
        state.perform(.clean, at: start.addingTimeInterval(903))
        state.perform(.clean, at: start.addingTimeInterval(904))
        XCTAssertEqual(state.poopCount, 0)
    }
    func testCleaningDoesNotResetThePetInactivityDeadline() {
        var state = PetState(now: start)
        state.advance(to: start.addingTimeInterval(600))
        state.perform(.clean, at: start.addingTimeInterval(899))
        XCTAssertEqual(state.poopCount, 1)
        state.advance(to: start.addingTimeInterval(900))
        XCTAssertEqual(state.poopCount, 2, "Cleaning poop is not clicking the dog")
    }
    func testStageSpecificPoseAndFeedbackAreNotVideoPromises() {
        var state = PetState(now: start)
        state.perform(.pet, at: start)
        XCTAssertEqual(state.imageName(for: .puppy, at: start), "puppy_sit")
        XCTAssertEqual(state.imageName(for: .adult, at: start), "adult_bark")
        state.perform(.feed, at: start)
        XCTAssertEqual(state.imageName(for: .adult, at: start), "adult_eat")
        XCTAssertEqual(state.imageName(for: .puppy, at: start.addingTimeInterval(300)), "puppy_walk")
    }
    func testRepositoryPersistsActionsAcrossIndependentInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = PetRepository(directory: directory)
        _ = try first.perform(.feed, at: start)
        _ = try first.perform(.pet, at: start)
        let restored = try PetRepository(directory: directory).snapshot(at: start)
        XCTAssertEqual(restored.foodCount, 1)
        XCTAssertEqual(restored.touchCount, 1)
        XCTAssertEqual(restored.birthday, start)
        XCTAssertEqual(restored.lastAction, .pet)
    }
    func testConcurrentWidgetActionsDoNotLoseUpdates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try PetRepository(directory: directory).snapshot(at: start)
        DispatchQueue.concurrentPerform(iterations: 60) { _ in
            do { _ = try PetRepository(directory: directory).perform(.feed, at: start) }
            catch { XCTFail("Concurrent transaction failed: \(error)") }
        }
        XCTAssertEqual(try PetRepository(directory: directory).snapshot(at: start).foodCount, 60)
    }
    func testFutureTimelineProjectionDoesNotPersistFuturePoopOrGrowth() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = PetRepository(directory: directory)
        var projection = try repository.snapshot(at: start)
        projection.advance(to: start.addingTimeInterval(300_000))
        XCTAssertGreaterThan(projection.poopCount, 0)
        let actual = try repository.snapshot(at: start)
        XCTAssertEqual(actual.poopCount, 0)
        XCTAssertEqual(actual.stage(for: .automatic), .puppy)
    }
}
