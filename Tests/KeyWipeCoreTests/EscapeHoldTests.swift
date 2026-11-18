import XCTest
@testable import KeyWipeCore

final class EscapeHoldTests: XCTestCase {
    func testCompletesAfterThreeSecondsWithoutKeyRepeat() {
        var hold = EscapeHold()
        hold.keyDown(at: 10, isRepeat: false)
        XCTAssertEqual(hold.progress(at: 11.5), 0.5)
        XCTAssertLessThan(hold.progress(at: 12.999), 1)
        XCTAssertEqual(hold.progress(at: 13), 1)
    }

    func testShortPressResetsInsteadOfAccumulating() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: false)
        hold.keyUp(at: 2)
        hold.keyDown(at: 3, isRepeat: false)
        hold.keyUp(at: 5)
        XCTAssertEqual(hold.progress(at: 100), 0)
    }

    func testRepeatsDoNotRestartTheTimer() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: false)
        for time in [0.5, 1, 1.5, 2, 2.5] {
            hold.keyDown(at: time, isRepeat: true)
        }
        XCTAssertEqual(hold.progress(at: 3), 1)
    }

    func testOrphanRepeatDoesNotStartAConfirmation() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: true)
        XCTAssertEqual(hold.progress(at: 10), 0)
    }

    func testReleaseBeforeTheNextTickPreservesCompletedHold() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: false)
        hold.keyUp(at: 3.001)
        XCTAssertEqual(hold.progress(at: 3.05), 1)
    }

    func testReleaseJustBelowThresholdCancels() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: false)
        hold.keyUp(at: 2.999)
        XCTAssertEqual(hold.progress(at: 3.05), 0)
    }

    func testFreshSessionDoesNotRetainACompletedHold() {
        var hold = EscapeHold()
        hold.keyDown(at: 0, isRepeat: false)
        hold.keyUp(at: 3)
        hold = EscapeHold()
        XCTAssertEqual(hold.progress(at: 10), 0)
    }
}
