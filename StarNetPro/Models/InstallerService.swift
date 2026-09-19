import Foundation
import CryptoKit

/// Only downloads; Apple Installer owns authorization and installation.
final class InstallerService: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    enum Phase: String, Sendable {
        case downloading = "Downloading the official installer…"
        case verifying = "Verifying the installer…"
        case checkingTrust = "Checking installer trust with macOS…"
    }
    private let onPhase: @MainActor @Sendable (Phase) -> Void

    init(onPhase: @escaping @MainActor @Sendable (Phase) -> Void = { _ in }) {
        self.onPhase = onPhase
    }

    static func allowed(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil &&
        (url.port == nil || url.port == 443) &&
        ["starnetastro.com", "download.starnetastro.com"].contains(url.host?.lowercased() ?? "")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(Self.allowed) == true ? request : nil)
    }

    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 900
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    static func validateResponse(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let url = response.url, allowed(url) else {
            throw CLIError.message("The official download server returned an unexpected response.")
        }
    }

    func latest(platform: String) async throws -> CLIRelease {
        let session = session()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: CLIContract.feedURL)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        try Self.validateResponse(response)
        guard data.count <= 1_048_576 else { throw CLIError.message("The update feed is too large.") }
        return try CLIRelease.parse(data, platform: platform)
    }

    static func verify(_ file: URL, package: CLIRelease.Package) throws {
        try package.validate()
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        var size: Int64 = 0
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            size += Int64(data.count)
            guard size <= package.size_bytes else { throw CLIError.message("Installer size mismatch.") }
            hash.update(data: data)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard size == package.size_bytes, digest == package.sha256.lowercased() else {
            throw CLIError.message("Installer verification failed. Nothing was installed; try downloading again.")
        }
    }

    /// Retain the returned private directory while Apple Installer is open.
    func download(_ package: CLIRelease.Package) async throws -> URL {
        try package.validate()
        let session = session()
        defer { session.invalidateAndCancel() }
        // The async download API did not deliver download-delegate byte callbacks
        // on the tested macOS runtime. Report explicit phases, not a false percentage.
        await onPhase(.downloading)
        let (file, response) = try await session.download(for: URLRequest(url: package.url), delegate: self)
        defer { try? FileManager.default.removeItem(at: file) }
        try Self.validateResponse(response)
        await onPhase(.verifying)
        try Self.verify(file, package: package)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StarNetPro-installer-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let installer = directory.appendingPathComponent("StarNet2.pkg")
        do {
            try FileManager.default.moveItem(at: file, to: installer)
            await onPhase(.checkingTrust)
            let trust = try await CLIProcess.capture(URL(fileURLWithPath: "/usr/sbin/spctl"),
                                                    ["--assess", "--type", "install", installer.path], timeout: 60)
            guard trust.status == 0, !trust.cancelled else {
                throw CLIError.message("macOS did not approve this installer. Nothing was installed.\n" +
                                       String(decoding: trust.stderr, as: UTF8.self))
            }
            return installer
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
