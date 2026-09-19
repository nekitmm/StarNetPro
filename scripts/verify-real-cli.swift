// Build with StarNetPro/Models/*.swift; run on a Mac with an isolated official CLI.
import Foundation
import AppKit

@main
struct VerifyRealCLI {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 4 else {
            throw CLIError.message("Usage: verify-real-cli <starnet2> <real-image.tif> <new-output-directory>")
        }
        let executable = URL(fileURLWithPath: CommandLine.arguments[1])
        let input = URL(fileURLWithPath: CommandLine.arguments[2])
        let root = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let probe = try await CLIProcess.capture(executable, ["--machine-info"])
        let info = try JSONDecoder().decode(CLIInfo.self, from: probe.stdout)
        try info.validate()
        print(info.label)
        guard CLIContract.licenseURL(executable: executable) != nil else {
            throw CLIError.message("License discovery failed for the real release")
        }
        let baseline = root.appendingPathComponent("direct-starless.tiff")
        let baselineStars = root.appendingPathComponent("direct-stars.tiff")
        let direct = try await CLIProcess.capture(executable,
            CLIContract.arguments(input: input, output: baseline, stars: baselineStars, stride: 256), timeout: 300)
        guard direct.status == 0, !direct.cancelled else {
            throw CLIError.message("Direct inference failed: " + String(decoding: direct.stderr, as: UTF8.self))
        }
        try direct.stderr.write(to: root.appendingPathComponent("direct.jsonl"))
        let suite = "StarNetPro.verification." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for (starsOnly, reference, name) in [(false, baseline, "gui-starless.tiff"), (true, baselineStars, "gui-stars.tiff")] {
            let processor = StarNetProcessor(defaults: defaults, discover: false)
            let output = root.appendingPathComponent(name)
            processor.startProcessing(executable: executable, input: input, destination: output, starsOnly: starsOnly, stride: 256)
            var sawProgress = false
            for _ in 0..<15000 {
                if processor.progress > 0 && processor.isProcessing { sawProgress = true }
                if !processor.isProcessing { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            guard !processor.isProcessing, processor.outputPath == output else {
                processor.cancelProcessing()
                throw CLIError.message("GUI processor failed: \(processor.log)")
            }
            guard sawProgress else { throw CLIError.message("No live tile progress was observed") }
            let a = try Data(contentsOf: reference), b = try Data(contentsOf: output)
            // Equal files imply exact saved pixel/sample/metadata equality, not preview similarity.
            guard a == b else { throw CLIError.message("Output bytes differ for \(name)") }
            try Data(processor.log.utf8).write(to: root.appendingPathComponent(name + ".log"))
            print("PASS \(name): \(b.count) bytes; SHA-256 \(CLIContract.digest(b)); real progress observed")
        }
    }
}
