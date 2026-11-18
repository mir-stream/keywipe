/// Pointer-only confirmation. Leaving the button cancels the entire gesture;
/// re-entering without another mouse-down cannot confirm it.
public struct HoldGesture: Sendable {
    public let duration: Double
    private var startedAt: Double?

    public init(duration: Double = 2) {
        precondition(duration > 0)
        self.duration = duration
    }

    public mutating func begin(at time: Double) {
        startedAt = time
    }

    public mutating func cancel() {
        startedAt = nil
    }

    public func progress(at time: Double) -> Double {
        guard let startedAt else { return 0 }
        return min(1, max(0, (time - startedAt) / duration))
    }

    /// Confirm on release, so the mouse-up cannot land on the app underneath.
    public mutating func release(at time: Double, inside: Bool) -> Bool {
        let confirmed = inside && progress(at: time) >= 1
        cancel()
        return confirmed
    }
}
