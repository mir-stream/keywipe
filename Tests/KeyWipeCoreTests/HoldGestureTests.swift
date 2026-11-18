import XCTest
@testable import KeyWipeCore

final class HoldGestureTests: XCTestCase {
    func testShortClickNeverUnlocks() {
        var gesture = HoldGesture()
        gesture.begin(at: 10)
        XCTAssertFalse(gesture.release(at: 10.1, inside: true))
        XCTAssertEqual(gesture.progress(at: 20), 0)
    }

    func testFullTwoSecondsAndReleaseRequired() {
        var gesture = HoldGesture()
        gesture.begin(at: 10)
        XCTAssertEqual(gesture.progress(at: 11), 0.5)
        XCTAssertEqual(gesture.progress(at: 12), 1)
        XCTAssertTrue(gesture.release(at: 12, inside: true))
        XCTAssertFalse(gesture.release(at: 13, inside: true))
    }

    func testJustUnderTwoSecondsDoesNotUnlock() {
        var gesture = HoldGesture()
        gesture.begin(at: 0)
        XCTAssertFalse(gesture.release(at: 1.999, inside: true))
    }

    func testDraggingOutThenBackInDoesNotUnlock() {
        var gesture = HoldGesture()
        gesture.begin(at: 0)
        gesture.cancel()
        XCTAssertFalse(gesture.release(at: 3, inside: true))
        gesture.begin(at: 4)
        XCTAssertTrue(gesture.release(at: 6, inside: true))
    }

    func testReleaseOutsideDoesNotUnlockEvenAfterLongHold() {
        var gesture = HoldGesture()
        gesture.begin(at: 0)
        XCTAssertFalse(gesture.release(at: 100, inside: false))
    }

    func testClockProgressIsClamped() {
        var gesture = HoldGesture()
        gesture.begin(at: 10)
        XCTAssertEqual(gesture.progress(at: 9), 0)
        XCTAssertEqual(gesture.progress(at: 100), 1)
    }
}
