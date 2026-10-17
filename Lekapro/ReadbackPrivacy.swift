import Foundation
import WebKit

@MainActor
enum ReadbackPrivacy {
    static func install(profile: BrowserProfile, controller: WKUserContentController) {
        let canvas = profile.privacy.canvasNoise == true && !profile.privacy.blockCanvasReadback
        let audio = profile.privacy.audioNoise == true && !profile.privacy.blockAudioReadback
        guard canvas || audio else { return }
        let seed = profile.dataStoreID.uuidString
        let source = #"""
        (() => {
          'use strict';
          const canvasEnabled = CANVAS_OPTION;
          const audioEnabled = AUDIO_OPTION;
          const identity = 'PROFILE_SEED' + '|' + location.origin;
          function hash(text) {
            let value = 2166136261;
            for (let i = 0; i < text.length; i++) value = Math.imul(value ^ text.charCodeAt(i), 16777619);
            return value >>> 0;
          }
          const base = hash(identity);
          function unit(index, salt) {
            let value = base ^ Math.imul(index + 1, 1597334677) ^ salt;
            value = Math.imul(value ^ (value >>> 16), 2246822507);
            value = Math.imul(value ^ (value >>> 13), 3266489909);
            return ((value ^ (value >>> 16)) >>> 0) / 4294967296;
          }
          if (canvasEnabled && globalThis.CanvasRenderingContext2D && globalThis.HTMLCanvasElement) {
            const context = CanvasRenderingContext2D.prototype;
            const canvas = HTMLCanvasElement.prototype;
            const read = context.getImageData;
            const encode = canvas.toDataURL;
            const blob = canvas.toBlob;
            function vary(image, left, top) {
              const pixels = image.data;
              for (let y = 0; y < image.height; y++) {
                for (let x = 0; x < image.width; x++) {
                  const at = (y * image.width + x) * 4;
                  if (pixels[at + 3] === 0) continue;
                  const absolute = Math.imul((top + y) | 0, 65537) ^ ((left + x) | 0);
                  if (unit(absolute, 1) < 0.25) pixels[at] = (pixels[at] & 254) | (unit(absolute, 2) < 0.5 ? 0 : 1);
                }
              }
              return image;
            }
            context.getImageData = function getImageData(left, top) {
              return vary(read.apply(this, arguments), Number(left) | 0, Number(top) | 0);
            };
            function copy(source) {
              const target = document.createElement('canvas');
              target.width = source.width; target.height = source.height;
              if (!target.width || !target.height) return source;
              const ctx = target.getContext('2d');
              if (!ctx) return source;
              ctx.drawImage(source, 0, 0);
              const image = vary(read.call(ctx, 0, 0, target.width, target.height), 0, 0);
              ctx.putImageData(image, 0, 0);
              return target;
            }
            canvas.toDataURL = function toDataURL() { return encode.apply(copy(this), arguments); };
            if (blob) canvas.toBlob = function toBlob() { return blob.apply(copy(this), arguments); };
          }
          if (audioEnabled && globalThis.AudioBuffer) {
            const proto = AudioBuffer.prototype;
            const original = proto.getChannelData;
            const originalCopy = proto.copyFromChannel;
            const visited = new WeakMap();
            function channel(buffer, index) {
              const values = original.call(buffer, index);
              let channels = visited.get(buffer);
              if (channels?.has(index)) return values;
              // Keep silent audio silent; do not add audible content.
              if (!values.some(value => value !== 0)) return values;
              if (!channels) { channels = new Set(); visited.set(buffer, channels); }
              channels.add(index);
              for (let i = 0; i < values.length; i += 128) {
                values[i] += (unit(i, index + 17) - 0.5) * 0.00001;
              }
              return values;
            }
            proto.getChannelData = function getChannelData(index) { return channel(this, Number(index) >>> 0); };
            if (originalCopy) proto.copyFromChannel = function copyFromChannel(destination, index) {
              channel(this, Number(index) >>> 0);
              return originalCopy.apply(this, arguments);
            };
          }
        })();
        """#
            .replacingOccurrences(of: "CANVAS_OPTION", with: canvas ? "true" : "false")
            .replacingOccurrences(of: "AUDIO_OPTION", with: audio ? "true" : "false")
            .replacingOccurrences(of: "PROFILE_SEED", with: seed)
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }
}
