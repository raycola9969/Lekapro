import Foundation
import WebKit

// DEBUG-only, explicit reductions for disposable QA profiles. These getters
// remain observable as JavaScript functions; no native-function camouflage.
@MainActor
enum DiagnosticSignals {
    static func install(_ options: DiagnosticEngineOptions, controller: WKUserContentController) {
        #if DEBUG
        guard options.hardwareThreadLimit != nil || options.colorDepthLimit != nil else { return }
        let cpu = options.hardwareThreadLimit.map { String($0) } ?? "null"
        let depth = options.colorDepthLimit.map { String($0) } ?? "null"
        let source = """
        (() => {
          'use strict';
          const cpuLimit = \(cpu), depthLimit = \(depth);
          function reduce(proto, key, limit) {
            if (limit === null || !proto) return;
            const original = Object.getOwnPropertyDescriptor(proto, key);
            if (!original?.get || !original.configurable) return;
            Object.defineProperty(proto, key, {...original, get: function() {
              return Math.min(Reflect.apply(original.get, this, []), limit);
            }});
          }
          reduce(globalThis.Navigator?.prototype ?? globalThis.WorkerNavigator?.prototype, 'hardwareConcurrency', cpuLimit);
          for (const key of ['colorDepth', 'pixelDepth']) reduce(globalThis.Screen?.prototype, key, depthLimit);
        })();
        """
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        if options.hardwareThreadLimit != nil { WorkerPrivacy.install(source: source, controller: controller) }
        #endif
    }
}
