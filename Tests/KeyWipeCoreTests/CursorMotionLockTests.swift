import XCTest
import CoreGraphics
@testable import KeyWipeCore

final class CursorMotionLockTests: XCTestCase {
    @MainActor
    func testFreezeAndRestoreAreBalancedAndIdempotent() async {
        var calls: [Bool] = []
        let lock = CursorMotionLock { connected in
            calls.append(connected)
            return .success
        }
        XCTAssertEqual(lock.lock(), .success)
        XCTAssertEqual(lock.lock(), .success)
        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(lock.unlock(), .success)
        XCTAssertEqual(lock.unlock(), .success)
        XCTAssertFalse(lock.isLocked)
        XCTAssertEqual(calls, [false, true])
    }

    @MainActor
    func testFailedFreezeDoesNotClaimProtection() async {
        var calls: [Bool] = []
        let lock = CursorMotionLock { connected in
            calls.append(connected)
            return .failure
        }
        XCTAssertEqual(lock.lock(), .failure)
        XCTAssertFalse(lock.isLocked)
        XCTAssertEqual(lock.unlock(), .success)
        XCTAssertEqual(calls, [false])
    }

    @MainActor
    func testFailedRestoreCanBeRetried() async {
        var restoreAttempts = 0
        let lock = CursorMotionLock { connected in
            if connected {
                restoreAttempts += 1
                return restoreAttempts == 1 ? .failure : .success
            }
            return .success
        }
        XCTAssertEqual(lock.lock(), .success)
        XCTAssertEqual(lock.unlock(), .failure)
        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(lock.unlock(), .success)
        XCTAssertFalse(lock.isLocked)
        XCTAssertEqual(restoreAttempts, 2)
    }
}
