import XCTest
import AppKit
@testable import StarNetPro

@MainActor
final class CLIIntegrationTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("StarNetPro-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func executable(_ body: String, directory: URL? = nil) throws -> URL {
        let root = try directory ?? temporaryDirectory()
        let url = root.appendingPathComponent("starnet2")
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func machineInfo(version: String = "2.6.2", product: String = "starnet2", progress: Bool = true) -> String {
        let flags = ["--input", "--output", "--stride", "--mask"] + (progress ? ["--machine-progress"] : [])
        let options = flags.map { "{\"name\":\"\($0.dropFirst(2))\",\"flags\":[\"\($0)\"]}" }.joined(separator: ",")
        return """
        {"schema":"starnetastro.cli.machine-info.v1","product":"\(product)","version":"\(version)","build":"0241","backend":{"display_name":"CoreML"},"options":[\(options)]}
        """
    }

    private func defaults() -> UserDefaults {
        let suite = "StarNetPro.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func fixture(_ directory: URL) throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
                                      bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 24, bitsPerPixel: 24)!
        memset(bitmap.bitmapData!, 31, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let url = directory.appendingPathComponent("input (test).tiff")
        try bitmap.representation(using: .tiff, properties: [:])!.write(to: url)
        return url
    }

    private func waitForProcessing(_ processor: StarNetProcessor) async throws {
        for _ in 0..<500 {
            if !processor.isProcessing { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        processor.cancelProcessing()
        XCTFail("Processing did not terminate within 10 seconds")
    }

    func testVersionAndBuildOrdering() throws {
        XCTAssertGreaterThan(try CLIVersion("2.6.2", build: "0242"), try CLIVersion("2.6.2", build: "0241"))
        XCTAssertGreaterThan(try CLIVersion("2.10.0"), try CLIVersion("2.9.9", build: "9999"))
        XCTAssertEqual(try CLIVersion("2.6.2", build: "0241"), try CLIVersion("2.6.2", build: "241"))
        for bad in ["", "2.6", "StarNet2", "2.6.2-beta", "2..2", "2.6.-2"] {
            XCTAssertThrowsError(try CLIVersion(bad))
        }
        XCTAssertThrowsError(try CLIVersion("2.6.2", build: "oops"))
    }

    func testCapabilities() throws {
        let good = try JSONDecoder().decode(CLIInfo.self, from: Data(machineInfo().utf8))
        XCTAssertNoThrow(try good.validate())
        for json in [machineInfo(version: "2.5.0"), machineInfo(version: "2.6.1"), machineInfo(product: "deepsnr"), machineInfo(progress: false)] {
            let info = try JSONDecoder().decode(CLIInfo.self, from: Data(json.utf8))
            XCTAssertThrowsError(try info.validate())
        }
        for version in ["2.6.2", "2.6.3", "2.7.0", "3.0.0"] {
            let future = try JSONDecoder().decode(CLIInfo.self, from: Data(machineInfo(version: version).utf8))
            XCTAssertNoThrow(try future.validate())
        }
    }

    func testDiscoveryAndExplicitOverride() {
        XCTAssertEqual(CLIContract.candidates(custom: "/custom/starnet2", path: "/somewhere"),
                       [URL(fileURLWithPath: "/custom/starnet2")])
        let paths = CLIContract.candidates(custom: nil, path: "/usr/local/bin::relative:/custom").map(\.path)
        XCTAssertEqual(paths.first, "/usr/local/bin/starnet2")
        XCTAssertEqual(paths.filter { $0 == "/usr/local/bin/starnet2" }.count, 1)
        XCTAssertTrue(paths.contains("/custom/starnet2"))
        XCTAssertFalse(paths.contains(where: { $0.contains("relative") }))
    }

    func testArgumentsPreservePathsAndDoNotOverrideWeights() throws {
        let input = URL(fileURLWithPath: "/tmp/hello (world) ' x.tif")
        let out = URL(fileURLWithPath: "/tmp/result.tiff")
        let args = try CLIContract.arguments(input: input, output: out, stars: nil, stride: 256)
        XCTAssertEqual(args, ["--input", input.path, "--output", out.path, "--stride", "256", "--machine-progress"])
        let stars = try CLIContract.arguments(input: input, output: out, stars: out, stride: 512)
        XCTAssertEqual(Array(stars.suffix(2)), ["--mask", out.path])
        for stride in [0, 1, 3, 513, 1024] {
            XCTAssertThrowsError(try CLIContract.arguments(input: input, output: out, stars: nil, stride: stride))
        }
    }

    func testFragmentedJSONLinesAndUTF8() throws {
        let text = "{\"schema\":\"starnetastro.cli.diagnostic.v1\",\"message\":\"étoile\"}\n{\"schema\":\"future\"}"
        var parser = JSONLines()
        var lines: [Data] = []
        for byte in text.utf8 { lines += parser.append(Data([byte])) }
        lines += parser.append(Data(), eof: true)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(try JSONDecoder().decode(CLIEvent.self, from: lines[0]).message, "étoile")
        XCTAssertTrue(parser.append(Data(), eof: true).isEmpty)
    }

    func testDownloadOrigins() {
        for url in ["http://download.starnetastro.com/x.pkg", "https://evil.example/x.pkg",
                    "https://download.starnetastro.com.evil.example/x.pkg", "https://user@starnetastro.com/x.pkg",
                    "https://starnetastro.com:444/x.pkg", "file:///tmp/x.pkg"] {
            XCTAssertFalse(InstallerService.allowed(URL(string: url)!))
        }
        XCTAssertTrue(InstallerService.allowed(URL(string: "https://download.starnetastro.com/x.pkg")!))
    }

    func testInstallerSizeAndHashChecks() throws {
        let file = try temporaryDirectory().appendingPathComponent("test.pkg")
        let data = Data("test installer bytes".utf8)
        try data.write(to: file)
        let url = URL(string: "https://download.starnetastro.com/test.pkg")!
        let package = CLIRelease.Package(url: url, sha256: CLIContract.digest(data), size_bytes: Int64(data.count))
        XCTAssertNoThrow(try InstallerService.verify(file, package: package))
        try Data("changed".utf8).write(to: file)
        XCTAssertThrowsError(try InstallerService.verify(file, package: package))
        let wrongHash = CLIRelease.Package(url: url, sha256: String(repeating: "0", count: 64), size_bytes: 7)
        XCTAssertThrowsError(try InstallerService.verify(file, package: wrongHash))
        XCTAssertThrowsError(try CLIRelease.Package(url: url, sha256: "oops", size_bytes: 7).validate())
    }

    func testFeedSelectsPlatformAndRejectsMissingInstaller() throws {
        let package: [String: Any] = ["url": "https://download.starnetastro.com/test.pkg",
                                     "sha256": String(repeating: "a", count: 64), "size_bytes": 10]
        let feed: [String: Any] = ["schema": "starnetastro.cli-tools.latest.v1", "tools": ["starnet2": ["latest": [
            "macos-arm64": ["version": "2.6.2", "build": "0241", "packages": ["installer": package]],
            "macos-x64": ["version": "2.6.2", "build": "0240", "packages": ["installer": package]]]]]]
        let data = try JSONSerialization.data(withJSONObject: feed)
        XCTAssertEqual(try CLIRelease.parse(data, platform: "macos-arm64").build, "0241")
        XCTAssertEqual(try CLIRelease.parse(data, platform: "macos-x64").build, "0240")
        XCTAssertThrowsError(try CLIRelease.parse(data, platform: "unknown"))
        XCTAssertThrowsError(try CLIRelease.parse(Data("{}".utf8), platform: "macos-arm64"))
    }

    func testHTTPFailureDoesNotPassValidation() throws {
        let url = CLIContract.feedURL
        for status in [301, 404, 500] {
            XCTAssertThrowsError(try InstallerService.validateResponse(HTTPURLResponse(url: url, statusCode: status,
                                                                                       httpVersion: nil, headerFields: nil)!))
        }
    }

    func testLicenseAcceptancePersistsAndChangesInvalidateIt() async throws {
        let root = try temporaryDirectory()
        let exe = try executable("printf '%s' '\(machineInfo())'", directory: root)
        let license = root.appendingPathComponent("LICENSE.txt")
        try Data("Test license A".utf8).write(to: license)
        let settings = defaults()
        settings.set(exe.path, forKey: "cliPath")
        let first = StarNetProcessor(defaults: settings, discover: false)
        await first.refreshCLI()
        XCTAssertNotNil(first.cliInfo)
        XCTAssertFalse(first.licenseAccepted)
        XCTAssertFalse(first.workspaceAvailable)
        XCTAssertTrue(first.canSkipSetup)
        first.skipSetup()
        XCTAssertTrue(first.showLicense)
        XCTAssertFalse(first.licenseAccepted)
        XCTAssertFalse(first.workspaceAvailable)
        first.acceptLicense()
        XCTAssertTrue(first.workspaceAvailable)
        let second = StarNetProcessor(defaults: settings, discover: false)
        await second.refreshCLI()
        XCTAssertTrue(second.licenseAccepted)
        second.skipSetup()
        XCTAssertTrue(second.workspaceAvailable)
        XCTAssertFalse(second.showLicense)
        try Data("Test license B".utf8).write(to: license)
        await second.refreshCLI()
        XCTAssertFalse(second.licenseAccepted)
        XCTAssertFalse(second.workspaceAvailable)
        try FileManager.default.removeItem(at: license)
        await second.refreshCLI()
        XCTAssertNil(second.cliInfo)
    }

    func testOldAndMalformedCLILeaveSetupAvailable() async throws {
        for text in ["starnet2 version 2.1.0", machineInfo(version: "2.5.0"), machineInfo(version: "2.6.1"), "{}"] {
            let exe = try executable("printf '%s' '\(text)'")
            let settings = defaults()
            settings.set(exe.path, forKey: "cliPath")
            let processor = StarNetProcessor(defaults: settings, discover: false)
            await processor.refreshCLI()
            XCTAssertNil(processor.cliInfo)
            XCTAssertFalse(processor.busy)
            XCTAssertFalse(processor.canProcess)
            XCTAssertFalse(processor.canSkipSetup)
            processor.skipSetup()
            XCTAssertFalse(processor.showLicense)
            XCTAssertFalse(processor.workspaceAvailable)
        }
    }

    func testLegacyVersionProducesActionableUpgradeMessage() async throws {
        let exe = try executable("if [ \"$1\" = --version ]; then printf '\\nstarnet2  version: 2.5.0\\n'; else exit 1; fi")
        let settings = defaults()
        settings.set(exe.path, forKey: "cliPath")
        let processor = StarNetProcessor(defaults: settings, discover: false)
        await processor.refreshCLI()
        XCTAssertNil(processor.cliInfo)
        XCTAssertFalse(processor.workspaceAvailable)
        XCTAssertFalse(processor.canSkipSetup)
        processor.skipSetup()
        XCTAssertFalse(processor.showLicense)
        XCTAssertFalse(processor.workspaceAvailable)
        XCTAssertTrue(processor.setupMessage.contains("StarNet2 2.5.0 is installed"))
        XCTAssertTrue(processor.setupMessage.contains("Update to StarNet2 2.6.2 or newer"))
        XCTAssertFalse(processor.busy)
        XCTAssertNil(CLIContract.legacyVersion(Data("deepsnr version: 2.5.0".utf8)))
        XCTAssertNil(CLIContract.legacyVersion(Data("starnet2 version: unknown".utf8)))
    }

    func testOfficialInstallerLicenseLayout() throws {
        let root = try temporaryDirectory()
        let bin = root.appendingPathComponent("usr/local/bin")
        let docs = root.appendingPathComponent("usr/local/share/doc/starnet2")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let exe = try executable("exit 0", directory: bin)
        let license = docs.appendingPathComponent("LICENSE.txt")
        try Data("Test installed license".utf8).write(to: license)
        XCTAssertEqual(CLIContract.licenseURL(executable: exe)?.standardizedFileURL, license)
    }

    func testRunnerDrainsBothPipesAndPreservesExitStatus() async throws {
        let exe = try executable("i=0; while [ $i -lt 4000 ]; do printf 'stdout line\\n'; printf 'stderr line\\n' >&2; i=$((i+1)); done; exit 7")
        let result = try await CLIProcess.capture(exe, [])
        XCTAssertEqual(result.status, 7)
        XCTAssertEqual(result.stdout.count, 48000)
        XCTAssertEqual(result.stderr.count, 48000)
    }

    func testCancellationBeforeLaunch() async throws {
        let runner = CLIProcess()
        runner.cancel()
        let result: Result<CLIProcess.Result, Error> = await withCheckedContinuation { continuation in
            runner.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: []) {
                continuation.resume(returning: $0)
            }
        }
        if case .success = result { XCTFail("Cancelled process must not launch") }
    }

    func testSmallProgressRecordArrivesBeforeChildExits() async throws {
        let exe = try executable("printf 'progress\\n' >&2; exec /bin/sleep 2")
        let runner = CLIProcess()
        var received = false
        var completed = false
        runner.run(executable: exe, arguments: [], onData: { data, stderr in
            if stderr && !data.isEmpty { received = true }
        }) { _ in completed = true }
        for _ in 0..<50 {
            if received { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(received, "Short progress messages must not wait for EOF or a full read buffer")
        XCTAssertFalse(completed)
        runner.cancel()
        for _ in 0..<200 {
            if completed { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(completed)
    }

    func testTimeoutTerminatesChild() async throws {
        let result = try await CLIProcess.capture(URL(fileURLWithPath: "/bin/sleep"), ["30"], timeout: 0.1)
        XCTAssertTrue(result.cancelled)
        XCTAssertNotEqual(result.status, 0)
    }

    func testProcessorSavesExactCLIBytesAndCleansScratch() async throws {
        let root = try temporaryDirectory()
        let input = try fixture(root)
        let exe = try executable("""
        while [ "$#" -gt 0 ]; do
          case "$1" in --input) input="$2"; shift 2;; --output) output="$2"; shift 2;; --mask) stars="$2"; shift 2;; *) shift;; esac
        done
        printf '%s\\n' '{"schema":"starnetastro.cli.progress.v1","event":"progress","percent":50,"current":1,"total":2}' >&2
        cp "$input" "$output"
        if [ -n "$stars" ]; then cp "$input" "$stars"; fi
        """)
        for starsOnly in [false, true] {
            let destination = root.appendingPathComponent(starsOnly ? "stars.tiff" : "starless.tiff")
            let processor = StarNetProcessor(defaults: defaults(), discover: false)
            processor.startProcessing(executable: exe, input: input, destination: destination, starsOnly: starsOnly, stride: 256)
            try await waitForProcessing(processor)
            XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: input))
            XCTAssertEqual(processor.progressLabel, "Complete.")
        }
    }

    func testInferenceFinishDoesNotPublishFailedJob() async throws {
        let root = try temporaryDirectory()
        let input = try fixture(root)
        let destination = root.appendingPathComponent("existing.tiff")
        let original = Data("keep existing output".utf8)
        try original.write(to: destination)
        let exe = try executable("printf '%s\\n' '{\"schema\":\"starnetastro.cli.progress.v1\",\"event\":\"finish\",\"percent\":100}' >&2; exit 1")
        let processor = StarNetProcessor(defaults: defaults(), discover: false)
        processor.startProcessing(executable: exe, input: input, destination: destination, starsOnly: false, stride: 256)
        try await waitForProcessing(processor)
        XCTAssertEqual(try Data(contentsOf: destination), original)
        XCTAssertEqual(processor.progressLabel, "Processing failed.")
        XCTAssertNil(processor.outputPath)
    }

    func testCancellationDoesNotPublishOutput() async throws {
        let root = try temporaryDirectory()
        let input = try fixture(root)
        let destination = root.appendingPathComponent("result.tiff")
        let exe = try executable("exec /bin/sleep 30")
        let processor = StarNetProcessor(defaults: defaults(), discover: false)
        processor.startProcessing(executable: exe, input: input, destination: destination, starsOnly: false, stride: 256)
        try await Task.sleep(for: .milliseconds(100))
        processor.cancelProcessing()
        try await waitForProcessing(processor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(processor.progressLabel, "Cancelled.")
    }

    func testMissingOutputAndInputOverwriteAreRejected() async throws {
        let root = try temporaryDirectory()
        let input = try fixture(root)
        let original = try Data(contentsOf: input)
        let processor = StarNetProcessor(defaults: defaults(), discover: false)
        processor.startProcessing(executable: URL(fileURLWithPath: "/usr/bin/true"), input: input,
                                  destination: input, starsOnly: false, stride: 256)
        XCTAssertFalse(processor.isProcessing)
        XCTAssertEqual(try Data(contentsOf: input), original)
        processor.startProcessing(executable: URL(fileURLWithPath: "/usr/bin/true"), input: input,
                                  destination: root.appendingPathComponent("missing.tiff"), starsOnly: false, stride: 256)
        try await waitForProcessing(processor)
        XCTAssertEqual(processor.progressLabel, "Processing failed.")
    }
}
