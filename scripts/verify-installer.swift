// Build with StarNetPro/Models/*.swift; downloads/verifies but NEVER opens/installs.
import Foundation

@main
struct VerifyInstaller {
    static func main() async throws {
        let service = InstallerService()
        let release = try await service.latest(platform: CLIContract.nativePlatform)
        guard let package = release.packages["installer"] else { throw CLIError.message("No installer") }
        let file = try await service.download(package)
        print("Verified StarNet2 \(release.label) for \(CLIContract.nativePlatform)")
        print("SHA-256: \(package.sha256); bytes: \(package.size_bytes)")
        print("macOS install trust assessment passed. Not installed. File: \(file.path)")
    }
}
