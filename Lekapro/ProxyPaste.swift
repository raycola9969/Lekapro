import Foundation

// Never Codable/logged: credentials go directly from the form to Keychain.
struct PastedProxy {
    var record: ProxyRecord
    let password: String
}

enum ProxyPaste {
    static func parse(_ text: String, kind: ProxyKind = .socks5) throws -> [PastedProxy] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty, lines.count <= 20 else {
            throw BrowserError.invalid("Dán từ 1 đến 20 proxy, mỗi proxy một dòng.")
        }
        var result: [PastedProxy] = []
        for (index, line) in lines.enumerated() {
            func invalid() -> BrowserError { .invalid("Dòng \(index + 1): dùng host:port:user:pass; IPv6 dùng [địa chỉ]:port:user:pass.") }
            guard line.utf8.count <= 2048, !line.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw invalid() }
            let host: String, remainder: Substring
            if line.hasPrefix("[") {
                guard let closing = line.firstIndex(of: "]"), line.index(after: closing) < line.endIndex,
                      line[line.index(after: closing)] == ":" else { throw invalid() }
                host = String(line[line.index(after: line.startIndex)..<closing])
                remainder = line[line.index(closing, offsetBy: 2)...]
                guard IPTimeZone.validIP(host) else { throw invalid() }
            } else {
                guard let colon = line.firstIndex(of: ":") else { throw invalid() }
                host = String(line[..<colon]); remainder = line[line.index(after: colon)...]
            }
            let parts = remainder.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, let port = Int(parts[0]), (1...65535).contains(port),
                  !host.isEmpty, !host.contains(where: { $0.isWhitespace }),
                  !host.contains(where: { "/@?#\\".contains($0) }) else { throw invalid() }
            var proxy = ProxyRecord(); proxy.name = "Proxy \(host):\(port)"; proxy.kind = kind
            proxy.host = host; proxy.port = port; proxy.username = String(parts[1])
            try proxy.validate()
            let item = PastedProxy(record: proxy, password: String(parts[2]))
            // Repeated identical lines should not create two profiles by accident.
            if !result.contains(where: { sameEndpoint($0.record, proxy) && $0.password == item.password }) { result.append(item) }
        }
        return result
    }
    static func sameEndpoint(_ a: ProxyRecord, _ b: ProxyRecord) -> Bool {
        a.kind == b.kind && a.host.lowercased() == b.host.lowercased() && a.port == b.port && a.username == b.username
    }
}
