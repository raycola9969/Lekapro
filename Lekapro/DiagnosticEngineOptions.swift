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
    var originQuotaBytes: UInt?
    var ephemeralStore: Bool?
    var hardwareThreadLimit: Int?
    var colorDepthLimit: Int?

    func validate() throws {
        if let limit = hardwareThreadLimit, !(1...8).contains(limit) {
            throw BrowserError.invalid("Diagnostic CPU reduction must be between 1 and 8.")
        }
        if let depth = colorDepthLimit, ![8, 16, 24].contains(depth) {
            throw BrowserError.invalid("Diagnostic color depth reduction must be 8, 16 or 24.")
        }
        if let quota = originQuotaBytes {
            guard quota >= 16 * 1024 * 1024, quota <= 64 * 1024 * 1024 * 1024 else {
                throw BrowserError.invalid("Diagnostic storage quota must be between 16 MiB and 64 GiB.")
            }
        }
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
    static func ephemeralStore(profileID: UUID) -> Bool {
        #if DEBUG
        return options[profileID]?.ephemeralStore == true
        #else
        return false
        #endif
    }
    static func originQuota(profileID: UUID) -> UInt? {
        #if DEBUG
        return options[profileID]?.originQuotaBytes
        #else
        return nil
        #endif
    }
    static func navigatorPlatform(profileID: UUID) -> String? {
        #if DEBUG
        return options[profileID]?.navigatorPlatform
        #else
        return nil
        #endif
    }
    static func apply(profileID: UUID, configuration: WKWebViewConfiguration) throws {
        #if DEBUG
        guard let value = options[profileID] else { return }
        try value.validate()
        let data = try JSONEncoder().encode(value)
        guard var dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrowserError.invalid("Invalid diagnostic engine options.")
        }
        // This policy is main-frame-only; default preferences reach subframes.
        dictionary.removeValue(forKey: "navigatorPlatform")
        dictionary.removeValue(forKey: "originQuotaBytes")
        dictionary.removeValue(forKey: "ephemeralStore")
        dictionary.removeValue(forKey: "hardwareThreadLimit")
        dictionary.removeValue(forKey: "colorDepthLimit")
        try LegacyWebKitBridge.applyDiagnosticOptions(dictionary, configuration: configuration)
        DiagnosticSignals.install(value, controller: configuration.userContentController)
        #endif
    }
}
