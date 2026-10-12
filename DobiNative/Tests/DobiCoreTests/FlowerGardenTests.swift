import XCTest
@testable import DobiCore

final class FlowerGardenTests: XCTestCase {
    func testFlowersPointOutwardFromTheirInsertionPosition() {
        var garden = FlowerGarden()
        let left = garden.insert(x: 0.2, y: 0.6, kind: .daisy)!
        let center = garden.insert(x: 0.5, y: 0.8, kind: .pink)!
        let right = garden.insert(x: 0.8, y: 0.6, kind: .clover)!
        XCTAssertGreaterThan(left.angle, 0)
        XCTAssertEqual(center.angle, 0, accuracy: 0.001)
        XCTAssertLessThan(right.angle, 0)
        XCTAssertEqual(garden.flowers.map(\.kind), [.daisy, .pink, .clover])
    }

    func testUndoAndResetPreserveOtherIndependentGardens() throws {
        var first = FlowerGarden(), second = FlowerGarden()
        for _ in 0..<150 { first.insert(x: 0.5, y: 0.5, kind: .daisy) }
        second.insert(x: 0.4, y: 0.4, kind: .pink)
        first.undo()
        XCTAssertEqual(first.flowers.count, 149)
        let restored = try JSONDecoder().decode(FlowerGarden.self, from: JSONEncoder().encode(first))
        XCTAssertEqual(restored, first)
        XCTAssertEqual(Set(restored.flowers.map(\.id)).count, 149)
        first.reset(); first.undo()
        XCTAssertTrue(first.flowers.isEmpty)
        XCTAssertEqual(second.flowers.count, 1)
    }

    func testInvalidCoordinatesCannotCreateAnUnsaveableArrangement() {
        var garden = FlowerGarden()
        XCTAssertNil(garden.insert(x: .nan, y: 0.5, kind: .daisy))
        XCTAssertNil(garden.insert(x: 0.5, y: .infinity, kind: .daisy))
        XCTAssertNil(garden.insert(x: -0.01, y: 0.5, kind: .daisy))
        XCTAssertNil(garden.insert(x: 0.5, y: 1.01, kind: .daisy))
        XCTAssertNil(garden.insert(x: 0.5, y: 0.5, kind: .daisy, variation: .nan))
        XCTAssertTrue(garden.flowers.isEmpty)
    }
}
