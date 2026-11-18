import XCTest
import CoreGraphics
@testable import KeyWipeCore

final class TrackpadInputStateTests: XCTestCase {
    private func key(_ code: CGKeyCode = 53, down: Bool) throws -> CGEvent {
        try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down))
    }

    func testOnlyEscapeStartsTheUnlockTimer() throws {
        var state = TrackpadInputState()
        state.observe(type: .keyDown, event: try key(0, down: true), at: 0)
        XCTAssertEqual(state.escapeProgress(at: 10), 0)
        XCTAssertFalse(state.isReadyToFinish(at: 10))
    }

    func testEscapeHoldCompletesButWaitsForRelease() throws {
        var state = TrackpadInputState()
        state.observe(type: .keyDown, event: try key(down: true), at: 0)
        XCTAssertEqual(state.escapeProgress(at: 3), 1)
        XCTAssertFalse(state.isReadyToFinish(at: 3))
        state.observe(type: .keyUp, event: try key(down: false), at: 3.1)
        XCTAssertTrue(state.isReadyToFinish(at: 3.1))
        XCTAssertEqual(state.escapeProgress(at: 3.1), 1)
    }

    func testNearbyKeyMustBeReleasedToo() throws {
        var state = TrackpadInputState()
        state.observe(type: .keyDown, event: try key(49, down: true), at: 0)
        state.observe(type: .keyDown, event: try key(down: true), at: 1)
        state.observe(type: .keyUp, event: try key(down: false), at: 4)
        XCTAssertEqual(state.escapeProgress(at: 4), 1)
        XCTAssertFalse(state.isReadyToFinish(at: 4))
        state.observe(type: .keyUp, event: try key(49, down: false), at: 4.1)
        XCTAssertTrue(state.isReadyToFinish(at: 4.1))
    }

    func testModifiersBlockFinishButCapsLockToggleDoesNot() throws {
        var state = TrackpadInputState()
        let event = try key(56, down: true)
        event.flags = [.maskShift, .maskAlphaShift]
        state.observe(type: .flagsChanged, event: event, at: 0)
        XCTAssertFalse(state.isReadyToFinish(at: 1))
        event.flags = .maskAlphaShift
        state.observe(type: .flagsChanged, event: event, at: 1)
        XCTAssertTrue(state.isReadyToFinish(at: 1))
    }

    func testClickReleaseAndQuietPeriodAreRequired() throws {
        var state = TrackpadInputState()
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
        state.observe(type: .leftMouseDown, event: event, at: 0)
        XCTAssertFalse(state.isReadyToFinish(at: 5))
        state.observe(type: .leftMouseUp, event: event, at: 5)
        XCTAssertFalse(state.isReadyToFinish(at: 5.24))
        XCTAssertTrue(state.isReadyToFinish(at: 5.25))
    }

    func testGestureActivityDelaysFinish() throws {
        var state = TrackpadInputState()
        let event = try XCTUnwrap(CGEvent(source: nil))
        state.observe(type: CGEventType(rawValue: 29)!, event: event, at: 10)
        XCTAssertFalse(state.isReadyToFinish(at: 10.2))
        XCTAssertTrue(state.isReadyToFinish(at: 10.25))
    }
}
