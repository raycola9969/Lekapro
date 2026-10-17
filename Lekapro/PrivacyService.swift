import Foundation
import WebKit

@MainActor
enum PrivacyService {
    static func blocker() async throws -> WKContentRuleList {
        let rules = ["doubleclick.net", "googlesyndication.com", "google-analytics.com", "connect.facebook.net", "scorecardresearch.com"].map { domain in
            ["trigger": ["url-filter": "^https?://([^/]+\\.)?" + NSRegularExpression.escapedPattern(for: domain) + "/", "load-type": ["third-party"]],
             "action": ["type": "block"]] as [String: Any]
        }
        let json = String(data: try JSONSerialization.data(withJSONObject: rules), encoding: .utf8)!
        return try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "Lekapro.Trackers.v1", encodedContentRuleList: json) { list, error in
                if let list { continuation.resume(returning: list) }
                else { continuation.resume(throwing: error ?? BrowserError.invalid("Không tạo được bộ chặn tracker.")) }
            }
        }
    }

    static func install(_ privacy: PrivacySettings, controller: WKUserContentController) {
        guard privacy.blockCanvasReadback || privacy.blockAudioReadback || privacy.blockWebRTC || privacy.blockWebGL == true || privacy.reduceHardwareInfo == true else { return }
        let source = """
        (() => {
          'use strict';
          const deny = () => { throw new DOMException('Blocked by Lekapro privacy settings', 'NotAllowedError'); };
          const replace = (prototype, names) => {
            if (!prototype) return;
            names.forEach(name => {
              if (typeof prototype[name] === 'function') {
                try { Object.defineProperty(prototype, name, {value: deny, configurable: true, writable: true}); } catch (_) {}
              }
            });
          };
          if (\(privacy.blockWebGL == true)) {
            for (const proto of [globalThis.HTMLCanvasElement?.prototype, globalThis.OffscreenCanvas?.prototype]) {
              if (!proto || typeof proto.getContext !== 'function') continue;
              const original = proto.getContext;
              proto.getContext = function getContext(type) {
                if (typeof type === 'string' && /^(webgl2?|experimental-webgl)$/i.test(type)) return null;
                return original.apply(this, arguments);
              };
            }
          }
          if (\(privacy.reduceHardwareInfo == true)) {
            const reduce = (proto, key, transform) => {
              const descriptor = proto && Object.getOwnPropertyDescriptor(proto, key);
              if (!descriptor?.get || !descriptor.configurable) return;
              Object.defineProperty(proto, key, {...descriptor, get: function() {return transform(descriptor.get.call(this))}});
            };
            reduce(globalThis.Navigator?.prototype ?? globalThis.WorkerNavigator?.prototype, 'hardwareConcurrency', value => Math.min(2, value));
            for (const key of ['width', 'height', 'availWidth', 'availHeight']) {
              reduce(globalThis.Screen?.prototype, key, value => Math.max(200, Math.floor(value / 200) * 200));
            }
          }
          if (\(privacy.blockCanvasReadback)) {
            replace(globalThis.HTMLCanvasElement?.prototype, ['toDataURL', 'toBlob']);
            replace(globalThis.CanvasRenderingContext2D?.prototype, ['getImageData']);
            replace(globalThis.OffscreenCanvas?.prototype, ['convertToBlob']);
            replace(globalThis.OffscreenCanvasRenderingContext2D?.prototype, ['getImageData']);
            replace(globalThis.WebGLRenderingContext?.prototype, ['readPixels']);
            replace(globalThis.WebGL2RenderingContext?.prototype, ['readPixels']);
          }
          if (\(privacy.blockAudioReadback)) {
            replace(globalThis.AudioBuffer?.prototype, ['getChannelData', 'copyFromChannel']);
            replace(globalThis.AnalyserNode?.prototype, ['getFloatFrequencyData', 'getByteFrequencyData', 'getFloatTimeDomainData', 'getByteTimeDomainData']);
          }
          if (\(privacy.blockWebRTC)) {
            ['RTCPeerConnection', 'webkitRTCPeerConnection'].forEach(name => {
              if (name in globalThis) {
                try { Object.defineProperty(globalThis, name, {value: deny, configurable: true, writable: true}); } catch (_) {}
              }
            });
          }
        })();
        """
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        if privacy.protectBlobWorkers == true && (privacy.reduceHardwareInfo == true || privacy.blockWebGL == true) {
            WorkerPrivacy.install(source: source, controller: controller)
        }
    }
}
