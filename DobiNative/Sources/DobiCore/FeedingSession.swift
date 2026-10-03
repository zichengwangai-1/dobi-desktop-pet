public struct FeedingSession {
    public private(set) var isEating = false
    private var hasPendingFood = false
    public init() {}
    @discardableResult public mutating func receiveFood() -> Bool {
        if isEating { hasPendingFood = true; return false }
        isEating = true
        return true
    }
    @discardableResult public mutating func completeCycle() -> Bool {
        if hasPendingFood { hasPendingFood = false; return true }
        isEating = false
        return false
    }
}
