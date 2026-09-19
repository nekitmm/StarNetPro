// Build with StarNetPro/Models/*.swift; run on a Mac with an isolated official CLI.
import Foundation
import AppKit

@main
struct VerifyRealCLI {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 4 ||
                (CommandLine.arguments.count == 5 && CommandLine.arguments[4] == "--linear") else {
            throw CLIError.message("Usage: verify-real-cli <starnet2> <real-image.tif> <new-output-directory> [--linear]")
        }
        let linear = CommandLine.arguments.count == 5
        let executable = URL(fileURLWithPath: CommandLine.arguments[1])
        let input = URL(fileURLWithPath: CommandLine.arguments[2])
        let root = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let probe = try await CLIProcess.capture(executable, ["--machine-info"])
        let info = try JSONDecoder().decode(CLIInfo.self, from: probe.stdout)
        try info.validate()
        print(info.label)
        print("Linear mode: \(linear)")
        guard CLIContract.licenseURL(executable: executable) != nil else {
            throw CLIError.message("License discovery failed for the real release")
        }
        let baseline = root.appendingPathComponent("direct-starless.tiff")
        let baselineStars = root.appendingPathComponent("direct-stars.tiff")
        let baselineUnscreen = root.appendingPathComponent("direct-unscreen.tiff")
        let direct = try await CLIProcess.capture(executable,
            ["--input", input.path, "--output", baseline.path, "--mask", baselineStars.path,
             "--unscreen", baselineUnscreen.path, "--stride", "256", "--machine-progress"] + (linear ? ["--linear"] : []), timeout: 300)
        guard direct.status == 0, !direct.cancelled else {
            throw CLIError.message("Direct inference failed: " + String(decoding: direct.stderr, as: UTF8.self))
        }
        try direct.stderr.write(to: root.appendingPathComponent("direct.jsonl"))
        let suite = "StarNetPro.verification." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let processor = StarNetProcessor(defaults: defaults, discover: false)
        let starless = root.appendingPathComponent("gui-starless.tiff")
        let difference = CLIContract.companionURL(starless, suffix: "difference")
        let unscreen = CLIContract.companionURL(starless, suffix: "unscreen")
        processor.startProcessing(executable: executable, input: input, destination: starless,
                                  difference: difference, unscreen: unscreen, stride: 256, linear: linear)
        var sawProgress = false
        for _ in 0..<15000 {
            if processor.progress > 0 && processor.isProcessing { sawProgress = true }
            if !processor.isProcessing { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard !processor.isProcessing, processor.outputPath == starless,
              processor.savedOutputPaths == [starless, difference, unscreen] else {
            processor.cancelProcessing()
            throw CLIError.message("GUI processor failed: \(processor.log)")
        }
        guard sawProgress else { throw CLIError.message("No live tile progress was observed") }
        try Data(processor.log.utf8).write(to: root.appendingPathComponent("gui.log"))
        for (reference, output) in [(baseline, starless), (baselineStars, difference), (baselineUnscreen, unscreen)] {
            let name = output.lastPathComponent
            let a = try Data(contentsOf: reference), b = try Data(contentsOf: output)
            // Equal files imply exact saved pixel/sample/metadata equality, not preview similarity.
            guard a == b else { throw CLIError.message("Output bytes differ for \(name)") }
            print("PASS \(name): \(b.count) bytes; SHA-256 \(CLIContract.digest(b)); real progress observed")
        }
    }
}
