import Foundation
import WebKit

// One-shot DEBUG experiments supplied through the app's own Documents folder.
// No network interception, response changes or production profile defaults.
struct DiagnosticEngineOptions: Codable {
    var navigatorPlatform: String?
    var webAudioEnabled: Bool?
    var acceleratedDrawing: Bool?
    var allowInstalledFonts: Bool?
    var allowDesignSystemFonts: Bool?
    var storageAPIEnabled: Bool?
    var standalone: Bool?

    func validate() throws {
        if let platform = navigatorPlatform {
            guard ["iPhone", "iPad", "MacIntel", "Linux aarch64", "Win32"].contains(platform) else {
                throw BrowserError.invalid("Unknown diagnostic navigator platform.")
            }
        }
    }
}

@MainActor
enum DiagnosticEngineRegistry {
    private static var options: [UUID: DiagnosticEngineOptions] = [:]
    static func set(_ values: [UUID: DiagnosticEngineOptions]) { options = values }
    static func clear() { options = [:] }
    static func apply(profileID: UUID, configuration: WKWebViewConfiguration) throws {
        #if DEBUG
        guard let value = options[profileID] else { return }
        try value.validate()
        let data = try JSONEncoder().encode(value)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrowserError.invalid("Invalid diagnostic engine options.")
        }
        try LegacyWebKitBridge.applyDiagnosticOptions(dictionary, configuration: configuration)
        #endif
    }
}
