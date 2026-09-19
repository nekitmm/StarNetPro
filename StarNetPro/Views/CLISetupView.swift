import SwiftUI

struct CLISetupView: View {
    @EnvironmentObject var processor: StarNetProcessor
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(processor.setupMessage).font(prominent ? .body : .caption).textSelection(.enabled)
            if let url = processor.cliURL {
                Text(url.path).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if processor.cliInfo != nil {
                Button(processor.licenseAccepted ? "View StarNet2 License" : "Review and Accept License…") {
                    processor.showLicense = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(prominent ? .large : .regular)
            }
            if processor.cliInfo == nil || processor.newerReleaseAvailable {
                Button("Download and Install CLI…") { Task { await processor.downloadAndInstall() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(prominent ? .large : .regular)
                Text("Downloads from StarNetAstro, then opens Apple Installer for your approval.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Refresh CLI") { Task { await processor.refreshCLI() } }
                Button("Choose…", action: processor.chooseCLI)
            }
            Button("Use Automatic Location", action: processor.useAutomaticCLI)
            Button("Check for CLI Updates") { Task { await processor.checkUpdates() } }
            Toggle("Check on Launch", isOn: $processor.automaticallyCheckUpdates)
                .font(.caption)
            if processor.isDownloading {
                ProgressView(processor.updateMessage)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            } else if !processor.updateMessage.isEmpty {
                Text(processor.updateMessage).font(.caption).textSelection(.enabled)
            }
            Link("Download Manually", destination: CLIContract.downloadPage)
        }
        .disabled(processor.busy)
    }
}

struct CLIOnboardingView: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 40)).foregroundStyle(.tint)
                Text(processor.cliInfo == nil ? "Set up StarNet2" : "One more step")
                    .font(.largeTitle).fontWeight(.semibold)
                Text(processor.cliInfo == nil
                     ? "StarNetPro uses the official StarNet2 CLI to process your images. Install a compatible version to get started."
                     : "Review and accept the StarNet2 license to open the image workspace.")
                    .foregroundStyle(.secondary)
                if processor.isChecking { ProgressView("Checking your installation…") }
                CLISetupView(prominent: true)
            }
            .padding(36)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LicenseView: View {
    @EnvironmentObject var processor: StarNetProcessor
    @State private var agreed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("StarNet2 License Agreement").font(.title2)
            ScrollView {
                Text(processor.licenseText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.background)
            if !processor.licenseAccepted {
                Toggle("I agree to the StarNet2 License Agreement.", isOn: $agreed)
            }
            HStack {
                Button("Close") { processor.showLicense = false }
                Spacer()
                if !processor.licenseAccepted {
                    Button("Accept", action: processor.acceptLicense).disabled(!agreed)
                }
            }
        }
        .padding(24)
        .frame(width: 650, height: 550)
    }
}
