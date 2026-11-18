import CoreGraphics

/// Event taps suppress delivery to apps, but pointer movement has a separate
/// WindowServer path. Disconnect that path while the cleaner is foreground.
@MainActor
public final class CursorMotionLock {
    public private(set) var isLocked = false
    private let associate: (Bool) -> CGError

    public init(associate: @escaping (Bool) -> CGError = {
        CGAssociateMouseAndMouseCursorPosition($0 ? 1 : 0)
    }) {
        self.associate = associate
    }

    @discardableResult
    public func lock() -> CGError {
        guard !isLocked else { return .success }
        let result = associate(false)
        if result == .success { isLocked = true }
        return result
    }

    @discardableResult
    public func unlock() -> CGError {
        guard isLocked else { return .success }
        let result = associate(true)
        // Retain ownership on failure so shutdown/reactivation can retry.
        if result == .success { isLocked = false }
        return result
    }
}
