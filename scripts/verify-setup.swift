import Foundation

@main
struct VerifySetup {
    @MainActor
    static func main() async {
        let suite = "StarNetPro.setup-verification." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        if CommandLine.arguments.count == 2 { defaults.set(CommandLine.arguments[1], forKey: "cliPath") }
        let processor = StarNetProcessor(defaults: defaults, discover: false)
        await processor.refreshCLI()
        print(processor.setupMessage)
        print("Summary: \(processor.setupSummary); Skip available: \(processor.canSkipSetup)")
        print("Compatible: \(processor.cliInfo != nil); busy: \(processor.busy); license accepted: \(processor.licenseAccepted)")
    }
}
