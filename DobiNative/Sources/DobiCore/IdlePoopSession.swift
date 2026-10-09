import Foundation

public struct IdlePoopSession {
    public enum Phase { case waiting, animating, visible }
    public private(set) var phase: Phase
    private var lastActivity: TimeInterval
    private let interval: TimeInterval
    public init(now: TimeInterval, hasPoop: Bool = false, interval: TimeInterval = 300) {
        self.lastActivity = now; self.interval = interval
        phase = hasPoop ? .visible : .waiting
    }
    public mutating func registerActivity(at now: TimeInterval) { lastActivity = now }
    public mutating func beginIfDue(at now: TimeInterval, canStart: Bool, manually: Bool = false) -> Bool {
        guard phase == .waiting, canStart, manually || now - lastActivity >= interval else { return false }
        phase = .animating
        return true
    }
    public mutating func completeAnimation() {
        if phase == .animating { phase = .visible }
    }
    public mutating func clear(at now: TimeInterval) {
        phase = .waiting
        lastActivity = now
    }
}
