// Originally created by Sunny Ma on 2025/7/30.
import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class StarNetProcessor: ObservableObject {
    @Published var log = ""
    @Published var isProcessing = false
    @Published var inputImage: NSImage?
    @Published var outputImage: NSImage?
    @Published var progress: Double = 0
    @Published var progressLabel = ""
    @Published var strideValue = 256
    @Published var createDifference = false
    @Published var createUnscreen = false
    @Published var cliInfo: CLIInfo?
    @Published var cliURL: URL?
    @Published var setupMessage = "Checking for StarNet2…"
    @Published var setupSummary = "Checking for StarNet2…"
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var latestRelease: CLIRelease?
    @Published var updateMessage = ""
    @Published var licenseText = ""
    @Published var licenseAccepted = false
    @Published var showLicense = false
    @Published var automaticallyCheckUpdates: Bool {
        didSet { defaults.set(automaticallyCheckUpdates, forKey: "automaticallyCheckCLIUpdates") }
    }

    var inputPath: URL?
    var outputPath: URL?
    var savedOutputPaths: [URL] = []
    private var runner: CLIProcess?
    private var decoder = JSONLines()
    private var stdoutDecoder = JSONLines()
    private var licenseHash = ""
    private var promptedLicenseHash = ""
    private let defaults: UserDefaults
    private var isCancelling = false
    private var checkingUpdates = false
    private var runID = UUID()

    var busy: Bool { isProcessing || isChecking || isDownloading }
    var workspaceAvailable: Bool { cliInfo != nil && licenseAccepted }
    var needsLicenseAcceptance: Bool { cliInfo != nil && !licenseAccepted }
    var canReviewLicense: Bool { needsLicenseAcceptance && !busy }
    var canProcess: Bool { !busy && cliInfo != nil && licenseAccepted && inputPath != nil }
    var newerReleaseAvailable: Bool {
        guard let latest = try? latestRelease?.releaseVersion else { return false }
        guard let installed = try? cliInfo?.releaseVersion else { return true }
        return latest > installed
    }

    init(defaults: UserDefaults = .standard, discover: Bool = true) {
        self.defaults = defaults
        automaticallyCheckUpdates = defaults.object(forKey: "automaticallyCheckCLIUpdates") as? Bool ?? true
        if discover {
            Task {
                await refreshCLI()
                if automaticallyCheckUpdates { await checkUpdates() }
            }
        }
    }

    func refreshCLI() async {
        guard !busy else { return }
        isChecking = true
        defer { isChecking = false }
        var failures: [String] = []
        var summary = "Install StarNet2 to get started."
        let paths = CLIContract.candidates(custom: defaults.string(forKey: "cliPath"),
                                           path: ProcessInfo.processInfo.environment["PATH"])
        for url in paths where FileManager.default.isExecutableFile(atPath: url.path) {
            do {
                let result = try await CLIProcess.capture(url, ["--machine-info"])
                guard result.status == 0, !result.cancelled else {
                    throw CLIError.message("Unable to probe StarNet2. Install CLI \(CLIContract.minimumVersionText) or newer.")
                }
                let info = try JSONDecoder().decode(CLIInfo.self, from: result.stdout)
                try info.validate()
                guard let licenseURL = CLIContract.licenseURL(executable: url) else {
                    throw CLIError.message("The installed StarNet2 license is missing. Reinstall the complete official CLI package.")
                }
                let license = try Data(contentsOf: licenseURL)
                guard let text = String(data: license, encoding: .utf8), !text.isEmpty else {
                    throw CLIError.message("The installed StarNet2 license could not be read.")
                }
                licenseText = text
                licenseHash = CLIContract.digest(license)
                licenseAccepted = defaults.string(forKey: "acceptedStarNetLicenseSHA256") == licenseHash
                cliInfo = info
                cliURL = url
                setupMessage = info.label
                setupSummary = "StarNet2 \(info.version) is installed."
                if !licenseAccepted && promptedLicenseHash != licenseHash {
                    promptedLicenseHash = licenseHash
                    showLicense = true
                }
                return
            } catch {
                summary = "Update StarNet2 to continue."
                var message = error.localizedDescription
                if let version = try? await CLIProcess.capture(url, ["--version"]),
                   version.status == 0, !version.cancelled,
                   let legacy = CLIContract.legacyVersion(version.stdout),
                   let parsed = try? CLIVersion(legacy), parsed < CLIContract.minimumVersion {
                    message = "StarNet2 \(legacy) is installed but is not supported by this version of StarNetPro. Update to StarNet2 \(CLIContract.minimumVersionText) or newer."
                    summary = "StarNet2 \(legacy) is too old. Install \(CLIContract.minimumVersionText) or newer."
                }
                failures.append("\(url.path): \(message)")
            }
        }
        cliInfo = nil
        cliURL = nil
        licenseAccepted = false
        licenseText = ""
        licenseHash = ""
        showLicense = false
        setupSummary = summary
        setupMessage = failures.isEmpty ? "Install the official StarNet2 CLI to start processing." :
            "No compatible StarNet2 installation found.\n" + failures.joined(separator: "\n")
    }

    func chooseCLI() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.message = "Select the starnet2 executable from a complete official CLI installation."
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "cliPath")
            Task { await refreshCLI() }
        }
    }

    func useAutomaticCLI() {
        guard !busy else { return }
        defaults.removeObject(forKey: "cliPath")
        Task { await refreshCLI() }
    }

    func acceptLicense() {
        guard cliInfo != nil, !busy, !licenseHash.isEmpty else { return }
        defaults.set(licenseHash, forKey: "acceptedStarNetLicenseSHA256")
        licenseAccepted = true
        showLicense = false
    }

    func checkUpdates() async {
        guard !checkingUpdates, !isDownloading else { return }
        checkingUpdates = true
        updateMessage = "Checking for CLI updates…"
        defer { checkingUpdates = false }
        do {
            let release = try await InstallerService().latest(platform: CLIContract.nativePlatform)
            guard !isDownloading else { return }
            latestRelease = release
            if let release = latestRelease {
                updateMessage = newerReleaseAvailable ? "StarNet2 \(release.label) is available." :
                    "Your installed StarNet2 is up to date."
            }
        } catch {
            guard !isDownloading else { return }
            latestRelease = nil
            appendLog("Update check failed: \(error.localizedDescription)")
            updateMessage = "Could not check for updates. Try again or download manually."
        }
    }

    func downloadAndInstall() async {
        guard !busy else { return }
        isDownloading = true
        defer { isDownloading = false }
        updateMessage = "Finding the latest installer…"
        do {
            let release = try await InstallerService().latest(platform: CLIContract.nativePlatform)
            latestRelease = release
            guard let package = release.packages["installer"] else {
                throw CLIError.message("The official feed has no Mac installer.")
            }
            let installer = try await InstallerService { [weak self] phase in
                self?.updateMessage = phase.rawValue
            }.download(package)
            updateMessage = "Opening Apple Installer…"
            guard NSWorkspace.shared.open(installer) else {
                throw CLIError.message("Could not open Apple Installer. Download the CLI from the official website.")
            }
            updateMessage = "Complete Apple Installer, then return here."
        } catch {
            appendLog("Installer setup failed: \(error.localizedDescription)")
            updateMessage = "Could not prepare the installer. Try again or download manually."
        }
    }

    func becameActive() {
        // Also covers installations started through the manual download link.
        if !busy { Task { await refreshCLI() } }
    }

    func reviewLicense() {
        guard canReviewLicense else { return }
        showLicense = true
    }

    func openImage() {
        guard workspaceAvailable, !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.tiff, .png, .jpeg]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadImage(at: url) }
    }

    func loadImage(at url: URL) {
        guard workspaceAvailable, !busy else { return }
        guard ["tif", "tiff", "png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()),
              let image = NSImage(contentsOf: url) else {
            appendLog("Choose a TIFF, PNG or JPEG image. FITS preview is not supported.")
            return
        }
        inputPath = url
        inputImage = image
        outputPath = nil
        savedOutputPaths = []
        outputImage = nil
        appendLog("Image loaded: \(url.path)")
    }

    func processImage() {
        guard canProcess else { return }
        Task {
            // A CLI update may have replaced the binary or its terms since app launch.
            await refreshCLI()
            guard canProcess, let input = inputPath, let executable = cliURL else { return }
            chooseDestination(executable: executable, input: input)
        }
    }

    private func chooseDestination(executable: URL, input: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.tiff]
        panel.nameFieldStringValue = "starless_" + input.deletingPathExtension().lastPathComponent + ".tiff"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        guard destination.resolvingSymlinksInPath().standardizedFileURL != input.resolvingSymlinksInPath().standardizedFileURL else {
            appendLog("The output must not overwrite the input file.")
            return
        }
        let difference = createDifference ? CLIContract.companionURL(destination, suffix: "difference") : nil
        let unscreen = createUnscreen ? CLIContract.companionURL(destination, suffix: "unscreen") : nil
        let existing = [difference, unscreen].compactMap { $0 }.filter { FileManager.default.fileExists(atPath: $0.path) }
        if !existing.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Replace existing star outputs?"
            alert.informativeText = existing.map(\.path).joined(separator: "\n")
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        startProcessing(executable: executable, input: input, destination: destination,
                        difference: difference, unscreen: unscreen, stride: strideValue)
    }

    /// UI and integration tests use the same runner; original image files are passed unchanged.
    func startProcessing(executable: URL, input: URL, destination: URL,
                         difference: URL? = nil, unscreen: URL? = nil, stride: Int) {
        guard !isProcessing else { return }
        let destinations = [destination, difference, unscreen].compactMap { $0 }
        do {
            try CLIContract.validateDestinations(input: input, outputs: destinations)
        } catch {
            appendLog(error.localizedDescription)
            return
        }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("StarNetPro-run-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
            let starless = scratch.appendingPathComponent("starless.tiff")
            let stars = difference.map { _ in scratch.appendingPathComponent("difference.tiff") }
            let screened = unscreen.map { _ in scratch.appendingPathComponent("unscreen.tiff") }
            let generated = [starless, stars, screened].compactMap { $0 }
            let args = try CLIContract.arguments(input: input, output: starless, stars: stars, unscreen: screened, stride: stride)
            runID = UUID()
            let id = runID
            isProcessing = true
            isCancelling = false
            progress = 0
            progressLabel = "Preparing image and model…"
            decoder = JSONLines()
            stdoutDecoder = JSONLines()
            outputImage = nil
            outputPath = nil
            savedOutputPaths = []
            log = "Processing with StarNet2\nExecutable: \(executable.path)\nInput: \(input.path)\n"
            runner = CLIProcess()
            runner?.run(executable: executable, arguments: args, onData: { [weak self] data, stderr in
                guard let self, self.runID == id else { return }
                self.consume(data, stderr: stderr)
            }, completion: { [weak self] result in
                defer { try? FileManager.default.removeItem(at: scratch) }
                guard let self, self.runID == id else { return }
                self.consume(Data(), stderr: true, eof: true)
                self.consume(Data(), stderr: false, eof: true)
                self.runner = nil
                defer { self.isProcessing = false }
                do {
                    let result = try result.get()
                    if result.cancelled || self.isCancelling {
                        self.progress = 0
                        self.progressLabel = "Cancelled."
                        self.appendLog("Processing cancelled; no result saved.")
                        return
                    }
                    guard result.status == 0 else {
                        throw CLIError.message("StarNet2 exited with code \(result.status). See the processing log.")
                    }
                    // Check the complete requested set before touching any user destination.
                    let images = try generated.map { url -> NSImage in
                        guard let image = NSImage(contentsOf: url) else {
                            throw CLIError.message("StarNet2 did not produce a readable \(url.lastPathComponent).")
                        }
                        return image
                    }
                    try CLIContract.validateDestinations(input: input, outputs: destinations)
                    for (source, target) in zip(generated, destinations) {
                        try Data(contentsOf: source, options: .mappedIfSafe).write(to: target, options: .atomic)
                        self.savedOutputPaths.append(target)
                        self.appendLog("Saved result: \(target.path)")
                    }
                    self.outputPath = destination
                    self.outputImage = images[0]
                    self.progress = 1
                    self.progressLabel = "Complete."
                } catch {
                    self.progress = 0
                    self.progressLabel = "Processing failed."
                    self.appendLog(error.localizedDescription)
                    if !self.savedOutputPaths.isEmpty {
                        self.appendLog("Some outputs were saved before the save error; see the paths above.")
                    }
                }
            })
        } catch {
            try? FileManager.default.removeItem(at: scratch)
            appendLog(error.localizedDescription)
        }
    }

    private func consume(_ data: Data, stderr: Bool, eof: Bool = false) {
        let lines = stderr ? decoder.append(data, eof: eof) : stdoutDecoder.append(data, eof: eof)
        for line in lines where !line.isEmpty {
            guard stderr, let record = try? JSONDecoder().decode(CLIEvent.self, from: line) else {
                appendLog(String(decoding: line, as: UTF8.self)); continue
            }
            if record.schema == "starnetastro.cli.diagnostic.v1" || record.event == "error" {
                if let message = record.message { appendLog("\(record.severity ?? "error"): \(message)") }
            } else if record.schema == "starnetastro.cli.progress.v1", !isCancelling {
                if record.event == "finish" {
                    progressLabel = "Finishing and saving output…"
                } else if let percent = record.percent, percent.isFinite {
                    progress = min(1, max(0, percent / 100))
                    progressLabel = "Processing tiles: \(record.current ?? 0) / \(record.total ?? 0)"
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        log += text + "\n"
        if log.count > 250_000 { log = String(log.suffix(200_000)) }
    }

    func cancelProcessing() {
        guard isProcessing, !isCancelling else { return }
        isCancelling = true
        progressLabel = "Cancelling…"
        runner?.cancel()
    }

    func showInFinder(url: URL?) {
        if let url {
            NSWorkspace.shared.activateFileViewerSelecting(url == outputPath && !savedOutputPaths.isEmpty ? savedOutputPaths : [url])
        }
    }
}
