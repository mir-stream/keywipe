import XCTest
import CoreGraphics
@testable import KeyWipeCore

final class KeyboardEventFilterTests: XCTestCase {
    func testAllKeyboardEventsAreDropped() throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        for type in KeyboardEventFilter.keyboardTypes {
            XCTAssertNil(KeyboardEventFilter.filter(type: type, event: event), "\(type)")
        }
    }

    func testSystemShortcutsAreDropped() throws {
        for key: CGKeyCode in [12, 48, 49, 53, 123] { // Q, Tab, Space, Escape, arrow
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true))
            event.flags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            XCTAssertNil(KeyboardEventFilter.filter(type: .keyDown, event: event))
            XCTAssertNil(KeyboardEventFilter.filter(type: .keyUp, event: event))
        }
    }

    func testMediaEventsAreDropped() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        XCTAssertNil(KeyboardEventFilter.filter(type: KeyboardEventFilter.systemDefined, event: event))
    }

    func testPointerEventsSurviveWithPositionPreserved() throws {
        for type in KeyboardEventFilter.pointerTypes {
            let event = try XCTUnwrap(CGEvent(source: nil))
            event.location = CGPoint(x: 123, y: 456)
            event.flags = [.maskControl, .maskCommand, .maskAlternate, .maskShift,
                           .maskSecondaryFn, .maskAlphaShift]
            let result = try XCTUnwrap(KeyboardEventFilter.filter(type: type, event: event))
                .takeUnretainedValue()
            XCTAssertEqual(result.location, CGPoint(x: 123, y: 456))
            XCTAssertEqual(result.flags.rawValue, 0)
        }
    }

    func testDeviceSpecificModifierBitsAreCleared() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.flags = CGEventFlags(rawValue: 0xFFFF).union(.maskCommand)
        let result = try XCTUnwrap(KeyboardEventFilter.filter(type: .leftMouseDown, event: event))
            .takeUnretainedValue()
        XCTAssertEqual(result.flags, .maskNonCoalesced)
    }

    func testUnknownEventsPassThroughUnchanged() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.flags = .maskCommand
        let result = try XCTUnwrap(KeyboardEventFilter.filter(type: .tabletPointer, event: event))
            .takeUnretainedValue()
        XCTAssertEqual(result.flags, .maskCommand)
    }

    func testEventMaskCoversKeyboardAndPointerEvents() {
        for type in KeyboardEventFilter.keyboardTypes + KeyboardEventFilter.pointerTypes {
            XCTAssertNotEqual(KeyboardEventFilter.eventMask & (CGEventMask(1) << type.rawValue), 0)
        }
    }

    func testTrackpadModeBlocksKeyboardPointerAndGestureEvents() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        for type in KeyboardEventFilter.keyboardTypes + KeyboardEventFilter.pointerTypes
            + KeyboardEventFilter.gestureTypes {
            XCTAssertNil(KeyboardEventFilter.filter(type: type, event: event, mode: .trackpad),
                         "Input event \(type.rawValue) must be blocked")
        }
    }

    func testEscapeIsConsumedRatherThanForwardedToAnotherApp() throws {
        for down in [true, false] {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down))
            XCTAssertNil(KeyboardEventFilter.filter(type: down ? .keyDown : .keyUp,
                                                    event: event, mode: .trackpad))
        }
    }

    func testTrackpadModeBlocksUnenumeratedInputEventsToo() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        let unknown = CGEventType(rawValue: 40)!
        XCTAssertNotEqual(KeyboardEventFilter.eventMask(for: .trackpad) & (1 << 40), 0)
        XCTAssertNil(KeyboardEventFilter.filter(type: unknown, event: event, mode: .trackpad))
        XCTAssertNotNil(KeyboardEventFilter.filter(type: unknown, event: event, mode: .keyboard))
    }

    func testKeyboardModeStillAllowsGestures() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        for type in KeyboardEventFilter.gestureTypes {
            XCTAssertNotNil(KeyboardEventFilter.filter(type: type, event: event, mode: .keyboard))
        }
    }
}
