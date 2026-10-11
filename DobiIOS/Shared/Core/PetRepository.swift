import Foundation
import Darwin

// Every process opens its own lock descriptor. Atomic read/modify/write protects
// rapid taps, multiple widgets and the containing app from losing each other's work.
public struct PetRepository: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func snapshot(at now: Date) throws -> PetState {
        try transaction(at: now) { $0.advance(to: now) }
    }
    @discardableResult
    public func perform(_ action: PetAction, at now: Date) throws -> PetState {
        try transaction(at: now) { $0.perform(action, at: now) }
    }
    private func transaction(at now: Date, _ change: (inout PetState) -> Void) throws -> PetState {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("pet.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { flock(descriptor, LOCK_UN) }
        let file = directory.appendingPathComponent("pet-v1.json")
        var state: PetState
        if FileManager.default.fileExists(atPath: file.path) {
            state = try JSONDecoder().decode(PetState.self, from: Data(contentsOf: file))
        } else { state = PetState(now: now) }
        change(&state)
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try JSONEncoder().encode(state).write(to: file, options: options)
        return state
    }
}
