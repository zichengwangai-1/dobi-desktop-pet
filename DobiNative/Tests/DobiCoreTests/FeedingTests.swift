import XCTest
@testable import DobiCore

final class FeedingSessionTests: XCTestCase {
    func testFeedingUsesCurrentGrowthStageAndNeverFallsBackToPuppyAfterGrowth() {
        var life = PetLife(birthday: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(PetAction.eating(for: life.stage(at: Date(timeIntervalSince1970: 260199))).rawValue, "puppy_eat")
        XCTAssertEqual(PetAction.eating(for: life.stage(at: Date(timeIntervalSince1970: 260200))).rawValue, "adult_eat")
        let restored = try! JSONDecoder().decode(PetLife.self, from: JSONEncoder().encode(life))
        var resumed = restored
        XCTAssertEqual(PetAction.eating(for: resumed.stage(at: Date(timeIntervalSince1970: 1000))).rawValue, "adult_eat")
    }
    func testContinuousDropsKeepEatingWithoutRestartingOrGrowingAnEndlessQueue() {
        var session = FeedingSession()
        XCTAssertTrue(session.receiveFood(), "First successful drop starts the eating clip")
        XCTAssertTrue(session.isEating)
        for _ in 0..<100 { XCTAssertFalse(session.receiveFood(), "Later drops extend eating without restarting the clip") }
        XCTAssertTrue(session.completeCycle(), "Pending food keeps the next cycle eating")
        XCTAssertTrue(session.isEating)
        XCTAssertFalse(session.completeCycle(), "After the last meal cycle ambient playback resumes")
        XCTAssertFalse(session.isEating)
        XCTAssertTrue(session.receiveFood(), "A later meal can start again")
    }
    func testFoodInEveryCycleKeepsEatingUntilDropsStop() {
        var session = FeedingSession()
        session.receiveFood()
        for _ in 0..<3 {
            session.receiveFood()
            XCTAssertTrue(session.completeCycle())
        }
        XCTAssertFalse(session.completeCycle())
        XCTAssertFalse(session.isEating)
    }
}

final class FileFeedingTests: XCTestCase {
    private var fixture: URL!
    private let manager = FileManager.default
    override func setUpWithError() throws {
        fixture = manager.temporaryDirectory.appendingPathComponent("dobi-feeding-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: fixture, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if manager.fileExists(atPath: fixture.path) { try manager.removeItem(at: fixture) }
    }
    private func file(_ name: String) throws -> URL {
        let url = fixture.appendingPathComponent(name)
        try Data("disposable feeding test".utf8).write(to: url)
        return url
    }
    private func restore(_ result: FileFeedingResult) {
        for entry in result.trashed {
            try? manager.moveItem(at: entry.trash, to: entry.original)
        }
    }
    func testBatchMovesFilesToRecoverableTrashAndDeduplicates() throws {
        let a = try file("a.txt"), b = try file("b.txt")
        let result = FileFeedingService().consume([a, b, a])
        defer { restore(result) }
        XCTAssertEqual(result.trashed.count, 2)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(manager.fileExists(atPath: a.path))
        XCTAssertFalse(manager.fileExists(atPath: b.path))
        for entry in result.trashed { XCTAssertTrue(manager.fileExists(atPath: entry.trash.path)) }
    }
    func testMissingFileDoesNotPreventOtherFilesBeingConsumed() throws {
        let a = try file("valid.txt"), missing = fixture.appendingPathComponent("missing.txt")
        let result = FileFeedingService().consume([missing, a])
        defer { restore(result) }
        XCTAssertEqual(result.trashed.count, 1)
        XCTAssertEqual(result.failures.map(\.file), [missing])
        XCTAssertFalse(manager.fileExists(atPath: a.path))
    }
    func testDroppingDirectoryAndItsChildConsumesDirectoryOnlyOnce() throws {
        let folder = fixture.appendingPathComponent("folder", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let child = folder.appendingPathComponent("child.txt")
        try Data("test".utf8).write(to: child)
        let result = FileFeedingService().consume([child, folder])
        defer { restore(result) }
        XCTAssertEqual(result.trashed.count, 1)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(manager.fileExists(atPath: folder.path))
    }
    func testSymbolicLinkIsTrashedWithoutDeletingItsTarget() throws {
        let target = try file("target.txt"), link = fixture.appendingPathComponent("link.txt")
        try manager.createSymbolicLink(at: link, withDestinationURL: target)
        let result = FileFeedingService().consume([link])
        defer { restore(result) }
        XCTAssertEqual(result.trashed.count, 1)
        XCTAssertTrue(manager.fileExists(atPath: target.path))
        XCTAssertFalse(manager.fileExists(atPath: link.path))
    }
}
