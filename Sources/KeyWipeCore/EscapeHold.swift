/// Uses elapsed monotonic time, independent of the user's key-repeat settings.
public struct EscapeHold: Sendable {
    public let duration: Double
    private var beganAt: Double?
    private var completedOnRelease = false

    public init(duration: Double = 3) {
        precondition(duration > 0)
        self.duration = duration
    }

    public mutating func keyDown(at time: Double, isRepeat: Bool) {
        guard !isRepeat, beganAt == nil, !completedOnRelease else { return }
        beganAt = time
    }

    public mutating func keyUp(at time: Double) {
        // A release just after the threshold can precede the next UI tick.
        // Latch completion so that a valid hold is not lost in that interval.
        completedOnRelease = progress(at: time) >= 1
        beganAt = nil
    }

    public func progress(at time: Double) -> Double {
        if completedOnRelease { return 1 }
        guard let beganAt else { return 0 }
        return min(1, max(0, (time - beganAt) / duration))
    }
}
