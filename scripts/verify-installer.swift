// Build with StarNetPro/Models/*.swift; downloads/verifies but NEVER opens/installs.
import Foundation

@main
struct VerifyInstaller {
    @MainActor
    static func main() async throws {
        var phases: [InstallerService.Phase] = []
        let service = InstallerService(onPhase: { phase in
            phases.append(phase)
            print("Installer phase: \(phase.rawValue)")
        })
        let release = try await service.latest(platform: CLIContract.nativePlatform)
        guard let package = release.packages["installer"] else { throw CLIError.message("No installer") }
        let file = try await service.download(package)
        guard phases == [.downloading, .verifying, .checkingTrust] else {
            throw CLIError.message("Installer activity phases were missing or out of order")
        }
        print("Verified StarNet2 \(release.label) for \(CLIContract.nativePlatform)")
        print("SHA-256: \(package.sha256); bytes: \(package.size_bytes)")
        print("macOS install trust assessment passed. Not installed. File: \(file.path)")
    }
}
