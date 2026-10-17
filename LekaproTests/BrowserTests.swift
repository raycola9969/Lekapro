import XCTest
import UIKit
import WebKit
@testable import Lekapro

@MainActor
final class BrowserTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")
    }
    func testAddressParsingDoesNotOpenLocalOrScriptURLs() throws {
        XCTAssertEqual(try AddressInput.resolve("example.com/path").absoluteString, "https://example.com/path")
        XCTAssertEqual(try AddressInput.resolve("hello world").host, "www.google.com")
        XCTAssertThrowsError(try AddressInput.resolve("file:///etc/passwd"))
        XCTAssertThrowsError(try AddressInput.resolve("https://user:password@example.com"))
        XCTAssertThrowsError(try AddressInput.validateHome("example.com"))
    }
    func testDuplicateStartsWithFreshWebsiteIdentity() {
        var profile = BrowserProfile()
        profile.tabs = [SavedTab(url: "https://example.com", title: "Example")]
        profile.history = [PageRecord(title: "Example", url: "https://example.com")]
        let duplicate = profile.duplicated()
        XCTAssertNotEqual(profile.id, duplicate.id)
        XCTAssertNotEqual(profile.dataStoreID, duplicate.dataStoreID)
        XCTAssertTrue(duplicate.tabs.isEmpty)
        XCTAssertTrue(duplicate.history.isEmpty)
        XCTAssertEqual(duplicate.privacy, profile.privacy)
    }
    func testProfilesBeforeUserAgentSettingStillLoadAndRetainData() throws {
        var profile = BrowserProfile()
        profile.userAgent = UserAgentPreset.ios172.value
        profile.history = [PageRecord(title: "Existing history", url: "https://example.com")]
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        old.removeValue(forKey: "userAgent")
        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.userAgent)
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.dataStoreID, profile.dataStoreID)
        XCTAssertEqual(decoded.history, profile.history)
        let store = ProfileStore(fileURL: temporaryFile())
        try store.save(profile)
        var changed = try XCTUnwrap(store.profile(profile.id))
        changed.userAgent = UserAgentPreset.ios1879.value
        try store.save(changed)
        XCTAssertEqual(store.profile(profile.id)?.dataStoreID, profile.dataStoreID)
        XCTAssertEqual(store.profile(profile.id)?.history, profile.history)
        changed.userAgent = "Bad\r\nInjected: value"
        XCTAssertThrowsError(try store.save(changed))
        XCTAssertEqual(store.profile(profile.id)?.userAgent, UserAgentPreset.ios1879.value)
    }
    func testOldPrivacySettingsKeepReadbackVariationOff() throws {
        let old = Data(#"{"blockTrackers":true,"blockCanvasReadback":false,"blockAudioReadback":false,"blockWebRTC":false}"#.utf8)
        let privacy = try JSONDecoder().decode(PrivacySettings.self, from: old)
        XCTAssertNil(privacy.canvasNoise)
        XCTAssertNil(privacy.audioNoise)
        XCTAssertNil(privacy.blockWebGL)
        XCTAssertNil(privacy.reduceHardwareInfo)
        XCTAssertNil(privacy.protectBlobWorkers)
        XCTAssertNil(privacy.audioNoiseScale)
        XCTAssertEqual(privacy, PrivacySettings())
    }
    func testDiagnosticStateResetIsScopedAndPreservesOtherDataTypes() async throws {
        var selected = BrowserProfile(); selected.tags = "qa-disposable-site-state"
        let other = BrowserProfile()
        let a = try DataStoreFactory.make(id: selected.dataStoreID, forceLegacy: true)
        let b = try DataStoreFactory.make(id: other.dataStoreID, forceLegacy: true)
        let ca = WKWebViewConfiguration(); ca.websiteDataStore = a
        let cb = WKWebViewConfiguration(); cb.websiteDataStore = b
        let ta = BrowserTab(configuration: ca), tb = BrowserTab(configuration: cb)
        defer {
            ta.close(); tb.close()
            DataStoreFactory.release(id: selected.dataStoreID); DataStoreFactory.release(id: other.dataStoreID)
        }
        func load(_ tab: BrowserTab) async throws {
            tab.webView.loadHTMLString("<!doctype html><title>State fixture</title>", baseURL: URL(string: "https://lekapro.invalid"))
            let end = Date().addingTimeInterval(25)
            while tab.webView.title != "State fixture" || tab.webView.isLoading {
                guard Date() < end else { throw BrowserError.invalid("State fixture timed out.") }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        try await load(ta); try await load(tb)
        let encoder = JSONEncoder()
        for (value, dataStore) in [("A", a), ("B", b)] {
            _ = try await CookieService.importData(encoder.encode([CookieRecord(name: "qa_state", value: value,
                domain: "lekapro.invalid", expirationDate: Date().addingTimeInterval(3600).timeIntervalSince1970)]), into: dataStore)
        }
        _ = try await ta.webView.evaluateJavaScript("localStorage.setItem('qa_state','A')")
        _ = try await tb.webView.evaluateJavaScript("localStorage.setItem('qa_state','B')")
        let cleared = try await DiagnosticSiteState.reset(.cookies, profile: selected, store: a)
        XCTAssertEqual(cleared["cookieCountAfter"] as? Int, 0)
        let bCookies = await CookieService.all(in: b)
        XCTAssertTrue(bCookies.contains { $0.name == "qa_state" && $0.value == "B" })
        let localA = try await ta.webView.evaluateJavaScript("localStorage.getItem('qa_state')")
        XCTAssertEqual(localA as? String, "A")
        _ = try await CookieService.importData(encoder.encode([CookieRecord(name: "qa_state", value: "A2",
            domain: "lekapro.invalid", expirationDate: Date().addingTimeInterval(3600).timeIntervalSince1970)]), into: a)
        _ = try await DiagnosticSiteState.reset(.localStorage, profile: selected, store: a)
        try await load(ta)
        let emptyA = try await ta.webView.evaluateJavaScript("localStorage.getItem('qa_state') === null")
        let localB = try await tb.webView.evaluateJavaScript("localStorage.getItem('qa_state')")
        XCTAssertEqual(emptyA as? Bool, true); XCTAssertEqual(localB as? String, "B")
        let aCookies = await CookieService.all(in: a)
        XCTAssertTrue(aCookies.contains { $0.name == "qa_state" && $0.value == "A2" })
        do {
            _ = try await DiagnosticSiteState.reset(.allSiteData, profile: other, store: b)
            XCTFail("Ordinary profiles must not be reset by the QA harness")
        } catch { }
        let unchanged = await CookieService.all(in: b)
        XCTAssertTrue(unchanged.contains { $0.name == "qa_state" && $0.value == "B" })
    }
    func testNativeDiagnosticOptionsAffectOnlySelectedProfileAndClear() async throws {
        let defaultProfile = BrowserProfile()
        let baseline = try await sampleContext(defaultProfile)
        let selected = BrowserProfile()
        DiagnosticEngineRegistry.set([selected.id: DiagnosticEngineOptions(navigatorPlatform: "MacIntel", webAudioEnabled: false)])
        defer { DiagnosticEngineRegistry.clear() }
        let changed = try await sampleContext(selected)
        XCTAssertEqual(changed["platform"] as? String, "MacIntel")
        XCTAssertEqual(changed["framePlatform"] as? String, "MacIntel")
        XCTAssertEqual(changed["webAudioAvailable"] as? Bool, false)
        let other = try await sampleContext(defaultProfile)
        XCTAssertEqual(other["platform"] as? String, baseline["platform"] as? String)
        XCTAssertEqual(other["webAudioAvailable"] as? Bool, baseline["webAudioAvailable"] as? Bool)
        DiagnosticEngineRegistry.clear()
        let restored = try await sampleContext(selected)
        XCTAssertEqual(restored["platform"] as? String, baseline["platform"] as? String)
        XCTAssertEqual(restored["webAudioAvailable"] as? Bool, baseline["webAudioAvailable"] as? Bool)
        XCTAssertThrowsError(try DiagnosticEngineOptions(navigatorPlatform: "unsupported").validate())
    }
    func testContextOptionsValidateAndOldProfilesKeepDeviceDefaults() throws {
        let file = temporaryFile()
        let store = ProfileStore(fileURL: file)
        var profile = BrowserProfile()
        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertNil(decoded.timeZoneID)
        XCTAssertNil(decoded.minimumFontSize)
        XCTAssertNil(decoded.fontFamily)
        profile.timeZoneID = "Asia/Tokyo"; profile.minimumFontSize = 32
        try store.save(profile)
        let reopened = ProfileStore(fileURL: file)
        XCTAssertFalse(reopened.isReadOnly)
        XCTAssertEqual(reopened.profile(profile.id)?.timeZoneID, "Asia/Tokyo")
        XCTAssertEqual(reopened.profile(profile.id)?.minimumFontSize, 32)
        profile.timeZoneID = "Invalid/Not_A_Zone"
        XCTAssertThrowsError(try store.save(profile))
        profile.timeZoneID = nil; profile.minimumFontSize = -1
        XCTAssertThrowsError(try store.save(profile))
        profile.minimumFontSize = 33
        XCTAssertThrowsError(try store.save(profile))
    }
    func testClosingSessionKeepsTabsAfterPendingSaveDeadline() async throws {
        let file = temporaryFile()
        let store = ProfileStore(fileURL: file)
        var profile = BrowserProfile()
        profile.privacy.blockTrackers = false
        profile.tabs = [SavedTab(url: "about:blank", title: "One")]
        try store.save(profile)
        let session = try BrowserSession(profile: profile, store: store)
        await session.start()
        session.addTab(url: URL(string: "about:blank"))
        session.close()
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(store.profile(profile.id)?.tabs.count, 2)
        XCTAssertEqual(ProfileStore(fileURL: file).profile(profile.id)?.tabs.count, 2)
    }
    func testNativeStorageLimitReachesMainAndWorkerWithoutJavaScriptOverrides() async throws {
        guard #available(iOS 17, *) else { throw XCTSkip("Storage estimate requires newer WebKit.") }
        for size in [1, 2] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = try LegacyWebKitBridge.makeQuotaStore(at: folder, quota: UInt(size) * 1024 * 1024 * 1024)
            let tab = BrowserTab(configuration: configuration)
            defer { tab.close() }
            tab.webView.loadHTMLString("<!doctype html><title>Native quota fixture</title>", baseURL: URL(string: "https://quota.lekapro.invalid/"))
            let deadline = Date().addingTimeInterval(30)
            while tab.webView.isLoading || tab.webView.url == nil {
                guard Date() < deadline else { throw BrowserError.invalid("Quota fixture did not load.") }
                try await Task.sleep(for: .milliseconds(100))
            }
            let value = try await tab.webView.callAsyncJavaScript(#"""
            const main = await navigator.storage.estimate();
            const worker = await new Promise((resolve, reject) => {
              let worker, url;
              const finish = (value, error) => {clearTimeout(timer);worker?.terminate();if(url)URL.revokeObjectURL(url);error ? reject(error) : resolve(value)};
              const timer=setTimeout(()=>finish(null,new Error('Quota Worker timed out')),5000);
              try {
                url=URL.createObjectURL(new Blob(["navigator.storage.estimate().then(v=>postMessage(v.quota))"],{type:'text/javascript'}));
                worker=new Worker(url);
                worker.onmessage=e=>finish(e.data);
                worker.onerror=()=>finish(null,new Error('Quota Worker failed'));
              } catch(error){finish(null,error)}
            });
            return {main:main.quota,worker,secure:isSecureContext};
            """#, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
            XCTAssertEqual(value?["secure"] as? Bool, true)
            XCTAssertEqual((value?["main"] as? NSNumber)?.uint64Value, UInt64(size) * 1024 * 1024 * 1024)
            XCTAssertEqual((value?["worker"] as? NSNumber)?.uint64Value, UInt64(size) * 1024 * 1024 * 1024)
            XCTAssertEqual(tab.webView.configuration.userContentController.userScripts.count, 0)
        }
    }
    func testNativeTimeZonesStaySeparateAcrossProfilesAndWorkers() async throws {
        var tokyo = BrowserProfile()
        tokyo.timeZoneID = "Asia/Tokyo"
        var utc = tokyo.duplicated(); utc.timeZoneID = "UTC"
        let first = try await sampleContext(tokyo)
        let second = try await sampleContext(utc)
        let repeated = try await sampleContext(tokyo)
        for value in [first, repeated] {
            XCTAssertEqual(value["zone"] as? String, "Asia/Tokyo")
            XCTAssertEqual(value["offset"] as? Int, -540)
            XCTAssertEqual(value["hour"] as? Int, 21)
            XCTAssertEqual(value["workerZone"] as? String, "Asia/Tokyo")
            XCTAssertEqual(value["workerOffset"] as? Int, -540)
        }
        XCTAssertEqual(second["zone"] as? String, "UTC")
        XCTAssertEqual(second["offset"] as? Int, 0)
        XCTAssertEqual(second["hour"] as? Int, 12)
        XCTAssertEqual(second["workerZone"] as? String, "UTC")
        XCTAssertEqual(second["workerOffset"] as? Int, 0)
    }
    func testMinimumFontSizeChangesActualLayout() async throws {
        let native = try await sampleContext(BrowserProfile())
        var large = BrowserProfile(); large.minimumFontSize = 32
        let changed = try await sampleContext(large)
        let smallHeight = try XCTUnwrap(native["textHeight"] as? Double)
        let largeHeight = try XCTUnwrap(changed["textHeight"] as? Double)
        XCTAssertGreaterThan(largeHeight, smallHeight)
    }
    func testNativeFontChoiceAppliesToInlineAndFrameText() async throws {
        var mono = BrowserProfile(); mono.fontFamily = .monospaced
        let monospaced = try await sampleContext(mono)
        var serif = BrowserProfile(); serif.fontFamily = .serif
        let withSerifs = try await sampleContext(serif)
        XCTAssertEqual(monospaced["fontFamily"] as? String, "monospace")
        XCTAssertEqual(monospaced["frameFontFamily"] as? String, "monospace")
        XCTAssertEqual(withSerifs["fontFamily"] as? String, "serif")
        XCTAssertEqual(withSerifs["frameFontFamily"] as? String, "serif")
        let original = try await sampleContext(BrowserProfile())
        XCTAssertEqual(original["fontFamily"] as? String, "sans-serif")
        XCTAssertEqual(original["frameFontFamily"] as? String, "sans-serif")
    }
    func testHardwareReductionIsOptInAndKeepsNativeDefaultsSeparate() async throws {
        let original = try await sampleContext(BrowserProfile())
        var reduced = BrowserProfile(); reduced.privacy.reduceHardwareInfo = true
        let privateContext = try await sampleContext(reduced)
        let nativeScreen = try XCTUnwrap(original["screen"] as? [Double])
        let privateScreen = try XCTUnwrap(privateContext["screen"] as? [Double])
        XCTAssertEqual(privateScreen, nativeScreen.map { max(200, floor($0 / 200) * 200) })
        let nativeCPU = try XCTUnwrap(original["cpu"] as? Int)
        XCTAssertEqual(privateContext["cpu"] as? Int, min(2, nativeCPU))
        let unchanged = try await sampleContext(BrowserProfile())
        XCTAssertEqual(unchanged["screen"] as? [Double], nativeScreen)
        XCTAssertEqual(unchanged["cpu"] as? Int, nativeCPU)
    }
    func testWebGLBlockingLeaves2DCanvasAvailable() async throws {
        let store = ProfileStore(fileURL: temporaryFile())
        var profile = BrowserProfile(); profile.privacy.blockWebGL = true
        profile.privacy.blockTrackers = false
        profile.tabs = [SavedTab(url: "about:blank", title: "Graphics fixture")]
        try store.save(profile)
        let session = try BrowserSession(profile: profile, store: store)
        await session.start(); defer { session.close() }
        let tab = try XCTUnwrap(session.selectedTab)
        let deadline = Date().addingTimeInterval(15)
        while tab.webView.url == nil || tab.webView.isLoading {
            guard Date() < deadline else { XCTFail("Graphics fixture did not load"); return }
            try await Task.sleep(for: .milliseconds(100))
        }
        let values = try await tab.webView.evaluateJavaScript(#"""
        (()=>{
          const canvas=()=>document.createElement('canvas');
          const gl=['webgl','webgl2','experimental-webgl'].map(type=>canvas().getContext(type)===null);
          const ctx=canvas().getContext('2d');ctx.fillRect(0,0,1,1);
          return [...gl,ctx.getImageData(0,0,1,1).data[3]===255];
        })()
        """#) as? [Bool]
        XCTAssertEqual(values, [true,true,true,true])
    }
    func testBlobWorkerPrivacyPreservesStrictModeOptionsAndPayloadAfterRevocation() async throws {
        var profile = BrowserProfile()
        profile.privacy.reduceHardwareInfo = true
        profile.privacy.protectBlobWorkers = true
        let value = try await sampleContext(profile)
        XCTAssertEqual(value["workerCPU"] as? Int, value["cpu"] as? Int)
        XCTAssertEqual(value["workerStrict"] as? Bool, true)
        XCTAssertEqual(value["workerName"] as? String, "context-fixture")
        XCTAssertEqual(value["workerInstance"] as? Bool, true)
        let payload = try XCTUnwrap(value["untouched"] as? [String: Any])
        XCTAssertEqual(payload["hardwareConcurrency"] as? Int, 99)
        XCTAssertEqual(payload["userAgent"] as? String, "literal payload")
    }
    private func sampleContext(_ profile: BrowserProfile) async throws -> [String: Any] {
        let store = ProfileStore(fileURL: temporaryFile())
        var fixture = profile; fixture.privacy.blockTrackers = false
        fixture.tabs = [SavedTab(url: "about:blank", title: "Context fixture")]
        try store.save(fixture)
        let session = try BrowserSession(profile: fixture, store: store)
        await session.start()
        let tab = try XCTUnwrap(session.selectedTab)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        tab.webView.frame = try XCTUnwrap(window.rootViewController).view.bounds
        window.rootViewController?.view.addSubview(tab.webView)
        defer {
            tab.webView.removeFromSuperview(); session.close()
            window.isHidden = true; previousWindow?.makeKeyAndVisible()
        }
        let blankDeadline = Date().addingTimeInterval(30)
        while tab.webView.url == nil || tab.webView.isLoading {
            guard Date() < blankDeadline else { throw BrowserError.invalid("Context blank page did not load.") }
            try await Task.sleep(for: .milliseconds(100))
        }
        let html = #"""
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <span id="sample" style="font-size:1px;font-family:sans-serif!important">Measurement</span><script>
        (async () => {
        const frame = document.createElement('iframe');
        const loaded = new Promise(resolve => {frame.onload=resolve});
        frame.srcdoc = '<span style="font-family:sans-serif!important">Frame</span>';
        document.body.append(frame); await loaded;
        const d = new Date('2026-01-15T12:00:00Z');
        const result = {zone:Intl.DateTimeFormat().resolvedOptions().timeZone,
          platform:navigator.platform,framePlatform:frame.contentWindow.navigator.platform,
          webAudioAvailable:typeof OfflineAudioContext==='function'||typeof webkitOfflineAudioContext==='function',
          cpu:navigator.hardwareConcurrency,screen:[screen.width,screen.height],
          offset:d.getTimezoneOffset(),hour:d.getHours(),
          fontFamily:getComputedStyle(document.querySelector('#sample')).fontFamily,
          frameFontFamily:frame.contentWindow.getComputedStyle(frame.contentDocument.querySelector('span')).fontFamily,
          textHeight:document.querySelector('#sample').getBoundingClientRect().height};
        const code = "'use strict';const d=new Date('2026-01-15T12:00:00Z');postMessage({workerZone:Intl.DateTimeFormat().resolvedOptions().timeZone,workerOffset:d.getTimezoneOffset(),workerCPU:navigator.hardwareConcurrency,workerStrict:(function(){return this})()===undefined,workerName:self.name,untouched:{hardwareConcurrency:99,userAgent:'literal payload'}})";
        const url = URL.createObjectURL(new Blob([code],{type:'text/javascript'}));
        const worker = new Worker(url,{name:'context-fixture'});
        URL.revokeObjectURL(url);
        result.workerInstance=worker instanceof Worker;
        worker.onmessage = event => {window.qaValue=JSON.stringify({...result,...event.data});worker.terminate()};
        worker.onerror = event => {window.qaError=String(event.message)};
        })().catch(error=>{window.qaError=String(error)});
        </script>
        """#
        tab.webView.loadHTMLString(html, baseURL: URL(string: "https://context.lekapro.invalid"))
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if let value = try? await tab.webView.evaluateJavaScript("window.qaValue"), let text = value as? String {
                return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            }
            if let error = try? await tab.webView.evaluateJavaScript("window.qaError"), let message = error as? String {
                throw BrowserError.invalid(message)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw BrowserError.invalid("Context fixture did not finish.")
    }
    func testReadbackVariationIsStableDistinctAndKeepsAudioCopiesConsistent() async throws {
        var first = BrowserProfile()
        first.privacy.blockTrackers = false
        first.privacy.canvasNoise = true
        first.privacy.audioNoise = true
        let second = first.duplicated()
        let a = try await sampleReadback(first)
        let repeated = try await sampleReadback(first)
        let b = try await sampleReadback(second)
        XCTAssertEqual(a, repeated)
        XCTAssertNotEqual(a, b)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(a.utf8)) as? [String: Any])
        let png = try XCTUnwrap(decoded["png"] as? [String])
        XCTAssertEqual(png[0], png[1])
        let audio = try XCTUnwrap(decoded["audio"] as? [[Double]])
        XCTAssertEqual(audio[0], audio[1])
        XCTAssertEqual(audio[0], audio[2])
        var native = first
        native.privacy.canvasNoise = false; native.privacy.audioNoise = false
        let original = try await sampleReadback(native)
        XCTAssertNotEqual(a, original)
    }
    func testFineAudioVariationIsStableAndUsesSmallerSampleChanges() async throws {
        var profile = BrowserProfile(); profile.privacy.audioNoise = true
        profile.privacy.audioNoiseScale = .fine
        let first = try await sampleReadback(profile)
        let repeated = try await sampleReadback(profile)
        XCTAssertEqual(first, repeated)
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(first.utf8)) as? [String: Any])
        let arrays = try XCTUnwrap(value["audio"] as? [[Double]])
        XCTAssertEqual(arrays[0], arrays[1]); XCTAssertEqual(arrays[0], arrays[2])
        XCTAssertTrue(arrays[0].contains { $0 != 0.25 })
        XCTAssertTrue(arrays[0].allSatisfy { abs($0 - 0.25) < 0.0000001 })
        let other = try await sampleReadback(profile.duplicated())
        XCTAssertNotEqual(first, other)
    }
    private func sampleReadback(_ profile: BrowserProfile) async throws -> String {
        let store = ProfileStore(fileURL: temporaryFile())
        var fixture = profile
        fixture.tabs = [SavedTab(url: "about:blank", title: "Readback fixture")]
        try store.save(fixture)
        let session = try BrowserSession(profile: fixture, store: store)
        await session.start()
        defer { session.close() }
        let tab = try XCTUnwrap(session.selectedTab)
        let html = #"""
        <!doctype html><script>
        const c = document.createElement('canvas'); c.width = 64; c.height = 64;
        const ctx = c.getContext('2d'); ctx.fillStyle = '#723b81'; ctx.fillRect(0,0,64,64);
        const buffer = new AudioBuffer({length:4096,sampleRate:44100});
        buffer.getChannelData(0).fill(0.25);
        const first = Array.from(buffer.getChannelData(0));
        const second = Array.from(buffer.getChannelData(0));
        const copy = new Float32Array(4096); buffer.copyFromChannel(copy,0);
        const pick = values => Array.from({length:32},(_,i)=>values[i*128]);
        window.qaValue = JSON.stringify({png:[c.toDataURL(),c.toDataURL()],audio:[pick(first),pick(second),pick(copy)]});
        </script>
        """#
        tab.webView.loadHTMLString(html, baseURL: URL(string: "https://readback.lekapro.invalid"))
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if let value = try? await tab.webView.evaluateJavaScript("window.qaValue"), let text = value as? String { return text }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw BrowserError.invalid("Readback fixture did not finish.")
    }
    func testProfileUserAgentReachesJavaScriptAndNewTabs() async throws {
        for preset in [UserAgentPreset.ios172, .crios119] {
            let store = ProfileStore(fileURL: temporaryFile())
            var profile = BrowserProfile()
            profile.userAgent = preset.value
            profile.privacy.blockTrackers = false
            profile.tabs = [SavedTab(url: "about:blank", title: "QA")]
            try store.save(profile)
            let session = try BrowserSession(profile: profile, store: store)
            await session.start()
            defer { session.close() }
            session.addTab(url: URL(string: "about:blank"))
            for tab in session.tabs {
                let deadline = Date().addingTimeInterval(15)
                while tab.webView.url == nil || tab.webView.isLoading {
                    guard Date() < deadline else { XCTFail("WebKit did not finish loading"); return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let value = try await tab.webView.evaluateJavaScript("navigator.userAgent") as? String
                XCTAssertEqual(value, preset.value)
                XCTAssertTrue(tab.webView.configuration.websiteDataStore === session.dataStore)
            }
        }
    }
    func testConfigurationImportCreatesNewIDsAndKeepsExistingProfiles() throws {
        let file = temporaryFile()
        let store = ProfileStore(fileURL: file)
        let first = BrowserProfile()
        try store.save(first)
        let backup = try store.exportConfiguration()
        try store.importConfiguration(backup)
        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(Set(store.profiles.map(\.dataStoreID)).count, 2)
        XCTAssertEqual(store.profiles[0].id, first.id)
        let reopened = ProfileStore(fileURL: file)
        XCTAssertEqual(reopened.profiles.count, 2)
        XCTAssertFalse(reopened.isReadOnly)
    }
    func testCorruptDatabaseIsPreservedAndNotOverwritten() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("broken data".utf8)
        try corrupt.write(to: file)
        let store = ProfileStore(fileURL: file)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertThrowsError(try store.save(BrowserProfile()))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    func testSharedWebsiteDataIdentityIsRejected() {
        let first = BrowserProfile()
        var second = BrowserProfile(); second.dataStoreID = first.dataStoreID
        XCTAssertThrowsError(try ProfileStore.validate(BrowserDatabase(profiles: [first, second])))
    }
    func testProxyRequiresCredentialsAndDisallowsDirectFailover() throws {
        var proxy = ProxyRecord(); proxy.host = "127.0.0.1"; proxy.username = "test"
        XCTAssertThrowsError(try ProxyService.legacyConfiguration(for: proxy, password: nil))
        if #available(iOS 17, *) {
            let config = try ProxyService.configuration(for: proxy, password: "example")
            XCTAssertFalse(config.allowFailover)
        }
        let legacy = try ProxyService.legacyConfiguration(for: proxy, password: "example")
        XCTAssertEqual(legacy["SOCKSProxy"] as? String, "127.0.0.1")
        XCTAssertEqual(legacy["SOCKSPassword"] as? String, "example")
        XCTAssertEqual(legacy["kCFStreamPropertySOCKSUser"] as? String, "test")
        XCTAssertEqual(legacy["kCFStreamPropertySOCKSPassword"] as? String, "example")
        proxy.port = 70000
        XCTAssertThrowsError(try ProxyService.legacyConfiguration(for: proxy, password: "example"))
    }
    func testNetscapeCookieParsingAndValidation() throws {
        let source = "# Netscape HTTP Cookie File\n#HttpOnly_.example.com\tTRUE\t/\tTRUE\t0\tsession\tvalue\n"
        let cookies = try CookieService.parse(Data(source.utf8))
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "session")
        XCTAssertTrue(cookies.first?.isSecure == true)
        XCTAssertTrue(cookies.first?.isHTTPOnly == true)
        XCTAssertNil(cookies.first?.expiresDate)
        XCTAssertThrowsError(try CookieService.parse(Data("not cookie data".utf8)))
        XCTAssertThrowsError(try CookieRecord(name: "test", value: "value", domain: "bad/domain").cookie())
    }
    func testCookiesAreSharedWithinProfileAndIsolatedBetweenProfiles() async throws {
        let idA = UUID(), idB = UUID()
        let storeA = try DataStoreFactory.make(id: idA)
        let storeB = try DataStoreFactory.make(id: idB)
        let cookieA = try CookieRecord(name: "account", value: "A", domain: "example.com").cookie()
        let cookieB = try CookieRecord(name: "account", value: "B", domain: "example.com").cookie()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storeA.httpCookieStore.setCookie(cookieA) { c.resume() } }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storeB.httpCookieStore.setCookie(cookieB) { c.resume() } }
        let config1 = WKWebViewConfiguration(); config1.websiteDataStore = storeA
        let config2 = WKWebViewConfiguration(); config2.websiteDataStore = try DataStoreFactory.make(id: idA)
        let tab1 = WKWebView(frame: .zero, configuration: config1)
        let tab2 = WKWebView(frame: .zero, configuration: config2)
        let a1 = await CookieService.all(in: tab1.configuration.websiteDataStore)
        let a2 = await CookieService.all(in: tab2.configuration.websiteDataStore)
        let b = await CookieService.all(in: storeB)
        XCTAssertEqual(a1.first(where: { $0.name == "account" })?.value, "A")
        XCTAssertEqual(a2.first(where: { $0.name == "account" })?.value, "A")
        XCTAssertEqual(b.first(where: { $0.name == "account" })?.value, "B")
        await CookieService.clear(storeA)
        let remainingA = await CookieService.all(in: storeA)
        let remainingB = await CookieService.all(in: storeB)
        XCTAssertTrue(remainingA.isEmpty)
        XCTAssertEqual(remainingB.first(where: { $0.name == "account" })?.value, "B")
        await CookieService.clear(storeB)
    }
    func testTrackerRulesCompileInWebKit() async throws {
        let list = try await PrivacyService.blocker()
        XCTAssertEqual(list.identifier, "Lekapro.Trackers.v1")
    }
    func testLegacyStoresShareWithinProfileAndIsolateBetweenProfiles() async throws {
        let idA = UUID(), idB = UUID()
        let storeA = try DataStoreFactory.make(id: idA, forceLegacy: true)
        let storeA2 = try DataStoreFactory.make(id: idA, forceLegacy: true)
        let storeB = try DataStoreFactory.make(id: idB, forceLegacy: true)
        XCTAssertTrue(storeA.isPersistent)
        XCTAssertTrue(storeA === storeA2)
        let data = Data("[{\"name\":\"legacy\",\"value\":\"A\",\"domain\":\"lekapro.invalid\"}]".utf8)
        _ = try await CookieService.importData(data, into: storeA)
        let a = await CookieService.all(in: storeA2)
        let b = await CookieService.all(in: storeB)
        XCTAssertEqual(a.first(where: { $0.name == "legacy" })?.value, "A")
        XCTAssertTrue(b.isEmpty)
        await CookieService.clear(storeA); await CookieService.clear(storeB)
        DataStoreFactory.release(id: idA); DataStoreFactory.release(id: idB)
    }
}
