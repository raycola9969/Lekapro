import Foundation
import WebKit

@MainActor
enum WorkerPrivacy {
    static func install(source: String, controller: WKUserContentController) {
        guard let data = try? JSONEncoder().encode(source), let literal = String(data: data, encoding: .utf8) else { return }
        let bootstrap = #"""
        (() => {
          'use strict';
          if (!globalThis.Worker || !globalThis.Blob || !globalThis.URL?.createObjectURL) return;
          const privacy = SOURCE_LITERAL;
          const NativeWorker = globalThis.Worker;
          const create = URL.createObjectURL;
          const revoke = URL.revokeObjectURL;
          const blobs = new Map();
          const pending = new WeakMap();
          const nativeTerminate = NativeWorker.prototype.terminate;
          NativeWorker.prototype.terminate = function terminate() {
            const url = pending.get(this);
            if (url) { Reflect.apply(revoke, URL, [url]); pending.delete(this); }
            return nativeTerminate.apply(this, arguments);
          };
          URL.createObjectURL = function createObjectURL(value) {
            const url = create.apply(this, arguments);
            if (value instanceof Blob) blobs.set(url, value);
            return url;
          };
          URL.revokeObjectURL = function revokeObjectURL(url) {
            if (typeof url === 'string') blobs.delete(url);
            return revoke.apply(this, arguments);
          };
          globalThis.Worker = new Proxy(NativeWorker, {
            construct(target, args, newTarget) {
              const blob = typeof args[0] === 'string' ? blobs.get(args[0]) : undefined;
              const type = args[1]?.type ?? 'classic';
              // Only Blob objects created in this page are eligible. Preserve native
              // URL/origin validation for external URLs, module workers and unknown blobs.
              if (!blob || type !== 'classic') return Reflect.construct(target, args, newTarget);
              // Keep the original bytes alive after URL revocation. Importing a
              // separate script preserves its own strict-mode directive prologue.
              const originalURL = Reflect.apply(create, URL, [blob]);
              const quoted = JSON.stringify(originalURL);
              const program = privacy + '\n(()=>{const cleanup=URL.revokeObjectURL.bind(URL);try{importScripts(' + quoted + ')}finally{cleanup(' + quoted + ')}})();';
              const combined = new Blob([program], {type: blob.type});
              let url;
              try {
                url = Reflect.apply(create, URL, [combined]);
                const worker = Reflect.construct(target, [url, ...args.slice(1)], newTarget);
                pending.set(worker, originalURL);
                worker.addEventListener('error', () => {
                  Reflect.apply(revoke, URL, [originalURL]); pending.delete(worker);
                }, {once:true});
                return worker;
              } catch (error) {
                Reflect.apply(revoke, URL, [originalURL]); throw error;
              }
              finally { if (url) Reflect.apply(revoke, URL, [url]); }
            }
          });
        })();
        """#.replacingOccurrences(of: "SOURCE_LITERAL", with: literal)
        controller.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }
}
