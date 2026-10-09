import Foundation

public struct IdlePoopSession {
    public enum Phase { case waiting, animating }
    public private(set) var phase: Phase = .waiting
    public private(set) var pendingManualRequests = 0
    private var nextAutomatic: TimeInterval
    private let interval: TimeInterval
    public init(now: TimeInterval, interval: TimeInterval = 300) {
        self.interval = interval
        nextAutomatic = now + interval
    }
    public mutating func registerActivity(at now: TimeInterval) { nextAutomatic = now + interval }
    public mutating func requestManual() { pendingManualRequests += 1 }
    public mutating func beginIfDue(at now: TimeInterval, canStart: Bool) -> Bool {
        guard phase == .waiting, canStart else { return false }
        if pendingManualRequests > 0 { pendingManualRequests -= 1 }
        else {
            guard now >= nextAutomatic else { return false }
            // Resume with one new cycle after sleep, rather than replaying missed intervals.
            nextAutomatic = now + interval
        }
        phase = .animating
        return true
    }
    public mutating func completeAnimation() { phase = .waiting }
}
