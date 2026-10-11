import Foundation

enum PetEnvironment {
    static let widgetKind = "DobiHomeWidget"
    static func repository() throws -> PetRepository {
        // All interactive intents run in the widget extension. The setup app is
        // stateless, so no App Group entitlement or shared host container is needed.
        let container = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
        return PetRepository(directory: container.appendingPathComponent("DobiPet", isDirectory: true))
    }
}
