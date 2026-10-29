import XCTest
@testable import Lekapro

@MainActor
final class DiagnosticCaptureTests: XCTestCase {
    func testPersistentTokenValuesAreHashedBeforeExport() {
        let token = "secret-existing-site-token"
        let state: [String: Any] = ["localValues": ["_vid_t": token],
            "sessionValues": ["session": token], "cookieText": "_vid_t=\(token); other=a=b",
            "timeZone": "Asia/Bangkok"]
        let result = FingerprintDiagnosticCapture.redactStorage(state)
        let encoded = String(data: try! JSONSerialization.data(withJSONObject: result), encoding: .utf8)!
        XCTAssertFalse(encoded.contains(token))
        XCTAssertNil(result["localValues"]); XCTAssertNil(result["sessionValues"])
        XCTAssertNil(result["cookieText"])
        XCTAssertEqual((result["localStorageDigests"] as? [String: String])?["_vid_t"], FingerprintDiagnosticCapture.hash(token))
        XCTAssertEqual((result["sessionStorageDigests"] as? [String: String])?["session"], FingerprintDiagnosticCapture.hash(token))
        let cookies = result["scriptCookieDigests"] as? [[String: String]]
        XCTAssertEqual(cookies?.last?["valueDigest"], FingerprintDiagnosticCapture.hash("a=b"))
        XCTAssertEqual(result["timeZone"] as? String, "Asia/Bangkok")
    }
}
