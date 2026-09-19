import Foundation
import CryptoKit
import Darwin

enum CLIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

struct CLIVersion: Comparable, Equatable {
    let parts: [Int]
    let build: Int

    init(_ version: String, build: String = "") throws {
        let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              pieces.allSatisfy({ Int($0) != nil }),
              build.isEmpty || (build.allSatisfy(\.isNumber) && Int(build) != nil) else {
            throw CLIError.message("Unrecognized StarNet2 version: \(version)-\(build)")
        }
        parts = pieces.map { Int($0)! }
        self.build = Int(build) ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.parts == rhs.parts ? lhs.build < rhs.build : lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }
}

struct CLIInfo: Decodable {
    struct Backend: Decodable { let display_name: String }
    struct Option: Decodable { let name: String; let flags: [String] }
    let schema: String
    let product: String
    let version: String
    let build: String
    let backend: Backend
    let options: [Option]

    var label: String { "StarNet2 \(version)\(build.isEmpty ? "" : "-" + build) · \(backend.display_name)" }
    var releaseVersion: CLIVersion { get throws { try CLIVersion(version, build: build) } }

    func validate() throws {
        guard schema == "starnetastro.cli.machine-info.v1", product == "starnet2" else {
            throw CLIError.message("This executable does not report the supported StarNet2 CLI contract.")
        }
        guard try releaseVersion >= CLIContract.minimumVersion else {
            throw CLIError.message("StarNet2 \(CLIContract.minimumVersionText) or newer is required. Install the current official CLI.")
        }
        for flag in ["--input", "--output", "--stride", "--mask", "--machine-progress"] {
            guard options.contains(where: { $0.flags.contains(flag) }) else {
                throw CLIError.message("The selected CLI does not support \(flag).")
            }
        }
    }
}

enum CLIContract {
    // Deliberate compatibility floor, not a moving requirement from the update feed.
    static let minimumVersionText = "2.6.2"
    static let minimumVersion = try! CLIVersion(minimumVersionText)
    static let downloadPage = URL(string: "https://starnetastro.com/cli-tools/starnet/")!
    static let feedURL = URL(string: "https://starnetastro.com/cli-tools/latest.json")!

    /// Only for an actionable upgrade message; legacy parsing never grants compatibility.
    static func legacyVersion(_ output: Data) -> String? {
        let text = String(decoding: output, as: UTF8.self)
        let expression = try! NSRegularExpression(pattern: #"(?im)^\s*starnet2\s+version:\s*(\d+\.\d+\.\d+)\s*$"#)
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    static func candidates(custom: String?, path: String?) -> [URL] {
        if let custom, !custom.isEmpty { return [URL(fileURLWithPath: custom)] }
        let directories = ["/usr/local/bin", "/opt/homebrew/bin"] +
            (path ?? "").split(separator: ":").map(String.init).filter { $0.hasPrefix("/") }
        var seen = Set<String>()
        return directories.map { URL(fileURLWithPath: $0).appendingPathComponent("starnet2") }
            .filter { seen.insert($0.path).inserted }
    }

    static func arguments(input: URL, output: URL, stars: URL?, stride: Int) throws -> [String] {
        guard stride >= 2, stride <= 512, stride.isMultiple(of: 2) else {
            throw CLIError.message("Stride must be an even integer from 2 through 512.")
        }
        var args = ["--input", input.path, "--output", output.path,
                    "--stride", String(stride), "--machine-progress"]
        if let stars { args += ["--mask", stars.path] }
        return args
    }

    static func licenseURL(executable: URL) -> URL? {
        let bin = executable.resolvingSymlinksInPath().deletingLastPathComponent()
        // Official portable archive and macOS installer layouts, respectively.
        let candidates = [bin.appendingPathComponent("LICENSE.txt"),
                          bin.appendingPathComponent("../share/doc/starnet2/LICENSE.txt")]
        return candidates.first { FileManager.default.isReadableFile(atPath: $0.path) }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static var nativePlatform: String {
        // hw.optional.arm64 also identifies Apple Silicon when the GUI runs under Rosetta.
        var arm64: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0) == 0 && arm64 == 1 {
            return "macos-arm64"
        }
        return "macos-x64"
    }
}

struct CLIRelease: Decodable {
    struct Package: Decodable {
        let url: URL
        let sha256: String
        let size_bytes: Int64

        func validate() throws {
            guard InstallerService.allowed(url), url.pathExtension == "pkg",
                  size_bytes > 0, size_bytes <= 2_000_000_000,
                  sha256.count == 64, sha256.allSatisfy({ $0.isHexDigit }) else {
                throw CLIError.message("The update feed contains an invalid installer record.")
            }
        }
    }
    let version: String
    let build: String
    let packages: [String: Package]
    var label: String { "\(version)-\(build)" }
    var releaseVersion: CLIVersion { get throws { try CLIVersion(version, build: build) } }

    static func parse(_ data: Data, platform: String) throws -> Self {
        struct Feed: Decodable {
            struct Tool: Decodable { let latest: [String: CLIRelease] }
            let schema: String
            let tools: [String: Tool]
        }
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        guard feed.schema == "starnetastro.cli-tools.latest.v1",
              let release = feed.tools["starnet2"]?.latest[platform],
              let installer = release.packages["installer"] else {
            throw CLIError.message("No compatible StarNet2 Mac installer was found in the update feed.")
        }
        _ = try release.releaseVersion
        try installer.validate()
        return release
    }
}

struct CLIEvent: Decodable {
    let schema: String
    let event: String?
    let stage: String?
    let current: Int?
    let total: Int?
    let percent: Double?
    let severity: String?
    let message: String?
}

/// Data buffering preserves UTF-8 characters and records split across pipe reads.
struct JSONLines {
    private var pending = Data()
    mutating func append(_ chunk: Data, eof: Bool = false) -> [Data] {
        pending.append(chunk)
        var lines: [Data] = []
        while let newline = pending.firstIndex(of: 10) {
            lines.append(Data(pending[..<newline]))
            pending.removeSubrange(...newline)
        }
        if eof && !pending.isEmpty { lines.append(pending); pending.removeAll() }
        // Limit a malformed child's unterminated record without unbounded RAM growth.
        if pending.count > 1_048_576 { lines.append(pending); pending.removeAll() }
        return lines
    }
}
