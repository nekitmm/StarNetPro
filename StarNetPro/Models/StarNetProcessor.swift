//
//  StarNetProcessor.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

class StarNetProcessor: ObservableObject {
    // MARK: - 发布属性
    @Published var log: String = ""
    @Published var isProcessing: Bool = false
    @Published var inputImage: NSImage?
    @Published var outputImage: NSImage?
    @Published var progress: Double = 0.0

    @Published var strideValue: Int = 256
    @Published var maskmode: Bool = false

    // MARK: - 内部属性
    var inputPath: URL?
    var outputPath: URL?
    private var saveDestination: URL?
    private var cancelled = false
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    // MARK: - 初始化
    init() {
        // 初始化时记录资源目录内容用于调试
        logBundleContents()
    }

    // MARK: - 公共方法

    /// Open Image文件
    func openImage() {
        guard !isProcessing else { return }
        let panel = NSOpenPanel()

        // 使用自定义的天文图像类型
        panel.allowedContentTypes = [.tiff, .png, .jpeg]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // 检查文件扩展名
            let fileExtension = url.pathExtension.lowercased()

            // 处理 FITS 文件
            if fileExtension == "fits" || fileExtension == "fit" {
                handleFITSFile(at: url)
            } else {
                loadImage(at: url)
            }
        }
    }

    /// 处理 FITS 文件
    private func handleFITSFile(at url: URL) {
        log += "FITS file detected: \(url.lastPathComponent)\n"

        // 创建临时 TIFF 文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let tiffFile = tempDir.appendingPathComponent("\(UUID().uuidString).tiff")

        // 使用 StarNet++ 转换 FITS 到 TIFF
        guard let executablePath = findStarNetExecutable() else {
            log += "Error: StarNet executable not found\n"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [url.path, tiffFile.path, "--convert-only"]
        process.environment = setupEnvironment()

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        log += "Converting FITS to TIFF...\n"

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                log += "Conversion succeeded\n"
                loadImage(at: tiffFile)

                // 设置输入路径为原始 FITS 文件
                inputPath = url

                // 自动设置输出路径
                let outputDir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let outputFile = "starless_" + url.lastPathComponent
                outputPath = outputDir.appendingPathComponent(outputFile)
            } else {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    log += "Conversion failed: \(output)\n"
                }
            }
        } catch {

        }
    }

    /// Start Processing图像
    func processImage() {
        guard !isProcessing else { return }
        // 验证输入
        guard let inputPath = inputPath else {
            log += "Error: No input image selected\n"
            return
        }

        // 验证可执行文件
        guard let executablePath = findStarNetExecutable() else {
            log += "Error: StarNet executable not found\n"
            return
        }
        //验证模型文件
        guard let modelPath = findModelPath() else {
            log += "Error: Model weights not found\n"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.tiff]
        panel.nameFieldStringValue = (maskmode ? "stars_" : "starless_") + inputPath.deletingPathExtension().lastPathComponent + ".tiff"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        guard destination.standardizedFileURL != inputPath.standardizedFileURL else {
            log += "The output must not overwrite the input file.\n"
            return
        }
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        self.outputPath = outputPath
        self.saveDestination = destination
        self.cancelled = false
        self.outputImage = nil
        self.isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                self.isProcessing = true
                self.progress = 0.0
                self.log = "Start Processing: \(inputPath.lastPathComponent)\n"
                self.log += "StarNet executable: \(executablePath)\n"
            }

            self.runStarNetProcess(
                executablePath: executablePath,
                inputPath: inputPath.path,
                outputPath: outputPath.path,
                modelPath: modelPath
            )
        }
    }

    /// Cancel Processing
    func cancelProcessing() {
        cancelled = true
        process?.terminate()
        // 保持忙碌状态直到进程Quit，防止交叉覆盖。
        progress = 0.0
        log += "\nCancellation requested\n"
    }

    /// Show in Finder文件
    func showInFinder(url: URL?) {
        guard let url = url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - 私有方法

    /// 加载图像
    func loadImage(at url: URL) {
        guard !isProcessing else { return }
        guard ["tif", "tiff", "png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()),
              NSImage(contentsOf: url) != nil else {
            log += "Please choose a TIFF, PNG, or JPEG image. FITS is not supported in this version.\n"
            return
        }
        do {
            // 检查文件大小
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64, fileSize > 200 * 1024 * 1024 { // 200MB
                log += "Warning: Large file (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))\n"
            }

            // 加载图像
            inputImage = NSImage(contentsOf: url)
            inputPath = url

            // 自动设置输出路径
            let outputDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            let outputFile = "starless_" + url.lastPathComponent
            outputPath = outputDir.appendingPathComponent(outputFile)

            // 重置输出图像
            outputImage = nil

            log += "Image loaded: \(url.lastPathComponent)\n"
            log += "Suggested output name: \(outputPath!.lastPathComponent)\n"

        } catch {
            log += "Error loading image: \(error.localizedDescription)\n"
        }
    }

    /// 查找 StarNet++ 可执行文件
    private func findStarNetExecutable() -> String? {
        // 1. 检查嵌入的版本
        if let embeddedPath = Bundle.main.path(forResource: "starnet2", ofType: nil, inDirectory: "StarNetBin/bin") {
            if isExecutableValid(embeddedPath) {
                return embeddedPath
            }
        }

        // 2. 备选路径：直接检查资源目录
        if let resourcePath = Bundle.main.resourcePath {
            let binPath = "\(resourcePath)/StarNetBin/starnet2"
            if isExecutableValid(binPath) {
                return binPath
            }
        }

        // 3. 检查常见系统路径
        let systemPaths = [
            "/usr/local/bin/starnet2",
            "/opt/homebrew/bin/starnet2",
            "/usr/bin/starnet2"
        ]

        for path in systemPaths {
            if isExecutableValid(path) {
                return path
            }
        }

        // 4. 使用 which 命令查找
        if let path = runWhichCommand() {
            if isExecutableValid(path) {
                return path
            }
        }

        return nil
    }

    private func findModelPath() -> String? {
        if let resourcePath = Bundle.main.resourcePath {
            let modelPath = "\(resourcePath)/StarNetBin/StarNet2_weights.pt"
            if FileManager.default.isReadableFile(atPath: modelPath) {
                return modelPath
            }
        }
        return nil
    }

    /// 运行 which 命令查找可执行文件
    private func runWhichCommand() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["starnet2"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            log += "Executable lookup failed: \(error.localizedDescription)\n"
        }

        return nil
    }

    /// 设置环境变量
    private func setupEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        // 设置 DYLD_LIBRARY_PATH 指向我们的 lib 目录
        if let libPath = Bundle.main.path(forResource: nil, ofType: nil, inDirectory: "StarNetBin/lib") {
            environment["DYLD_LIBRARY_PATH"] = libPath
            log += "DYLD_LIBRARY_PATH: \(libPath)\n"
        } else if let resourcePath = Bundle.main.resourcePath {
            let libPath = "\(resourcePath)/StarNetBin/lib"
            environment["DYLD_LIBRARY_PATH"] = libPath
            log += "DYLD_LIBRARY_PATH: \(libPath)\n"
        }

        return environment
    }

    /// 运行 StarNet++ 进程
    private func runStarNetProcess(executablePath: String, inputPath: String, outputPath: String, modelPath:String) {
        let process = Process()
        self.process = process
        process.executableURL = URL(fileURLWithPath: executablePath)

        var arguments = [
            "-i",
            inputPath,
            "-o",
            self.maskmode ? outputPath + ".starless.tiff" : outputPath,
            "-s",
            "\(self.strideValue)",
            "-w",
            modelPath
        ]

        arguments.append("-m")
        arguments.append(self.maskmode ? outputPath : outputPath + ".mask.tiff")


        process.arguments = arguments

        // 设置环境变量
        process.environment = setupEnvironment()

        // 设置输出管道
        outputPipe = Pipe()
        errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 处理标准输出
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.log += output
                    // 简单的进度模拟
                    if output.contains("Processing") {
                        self?.progress = min((self?.progress ?? 0) + 0.05, 0.95)
                    }
                }
            }
        }

        // 处理错误输出
        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let errorOutput = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.log += errorOutput
                }
            }
        }

        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isProcessing = false
                self.progress = 1.0

                // 清理管道
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil

                // 读取任何剩余的管道数据
                if let outputData = try? self.outputPipe?.fileHandleForReading.readToEnd(),
                   let output = String(data: outputData, encoding: .utf8) {
                    self.log += output
                }

                if let errorData = try? self.errorPipe?.fileHandleForReading.readToEnd(),
                   let errorOutput = String(data: errorData, encoding: .utf8) {

                }

                self.outputPipe = nil
                self.errorPipe = nil

                defer {
                    try? FileManager.default.removeItem(atPath: outputPath)
                    try? FileManager.default.removeItem(atPath: outputPath + ".starless.tiff")
                    try? FileManager.default.removeItem(atPath: outputPath + ".mask.tiff")
                }
                guard !self.cancelled, finished.terminationStatus == 0 else {
                    self.progress = 0
                    self.log += "\nProcessing did not complete. Exit code: \(finished.terminationStatus)\n"
                    return
                }
                guard NSImage(contentsOfFile: outputPath) != nil, let destination = self.saveDestination else {
                    self.log += "\nNo valid output image was generated.\n"
                    return
                }
                do {
                    // 原子写入：只在处理成功后替换用户确认的目标。
                    try Data(contentsOf: URL(fileURLWithPath: outputPath)).write(to: destination, options: .atomic)
                    self.outputPath = destination
                } catch {
                    self.log += "Failed to save: \(error.localizedDescription)\n"
                    return
                }
                // 加载处理后的图像
                if let outputPath = self.outputPath {
                    // 检查是否是 FITS 文件
                    let fileExtension = outputPath.pathExtension.lowercased()

                    if fileExtension == "fits" || fileExtension == "fit" {
                        // 对于 FITS 输出，加载转换后的 TIFF 预览
                        let tempDir = FileManager.default.temporaryDirectory
                        let tiffFile = tempDir.appendingPathComponent("preview_\(UUID().uuidString).tiff")

                        // 转换 FITS 到 TIFF 用于预览
                        self.convertFITSToTIFF(input: outputPath.path, output: tiffFile.path) { success in
                            if success, let image = NSImage(contentsOf: tiffFile) {
                                self.outputImage = image
                                self.log += "\nProcessing complete! Result saved to: \(outputPath.path)\n"
                                self.sendCompletionNotification()
                            } else {
                                self.log += "\nError: Unable to load output image\n"
                            }
                        }
                    } else if let outputImage = NSImage(contentsOf: outputPath) {
                        self.outputImage = outputImage
                        self.log += "\nProcessing complete! Result saved to: \(outputPath.path)\n"
                        self.sendCompletionNotification()
                    } else {
                        self.log += "\nError: Unable to load output image\n"
                    }
                } else {
                    self.log += "\nError: Invalid output path\n"
                }
            }
        }

        do {
            if cancelled {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }
            try process.run()
            if cancelled { process.terminate() }
        } catch {
            DispatchQueue.main.async {
                self.log += "Execution error: \(error.localizedDescription)\n"
                self.isProcessing = false
                self.progress = 0.0

                // 额外错误信息
                self.log += "Executable path: \(executablePath)\n"
                self.log += "Input path: \(inputPath)\n"
                self.log += "Output path: \(outputPath)\n"
            }
        }
    }

    /// 转换 FITS 到 TIFF
    private func convertFITSToTIFF(input: String, output: String, completion: @escaping (Bool) -> Void) {
        guard let executablePath = findStarNetExecutable() else {
            completion(false)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [input, output, "--convert-only"]
        process.environment = setupEnvironment()

        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                completion(process.terminationStatus == 0)
            } catch {
                completion(false)
            }
        }
    }

    /// 发送完成通知
    private func sendCompletionNotification() {
        let notification = NSUserNotification()
        notification.title = "StarNet Pro - Processing Complete"
        notification.informativeText = "Star removal finished successfully."
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }

    /// 验证可执行文件是否有效
    private func isExecutableValid(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        if exists && !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: path) {
            return true
        }

        log += "Validation failed: \(path)\n"
        log += "Exists: \(exists), Is directory: \(isDirectory.boolValue), Executable: \(FileManager.default.isExecutableFile(atPath: path))\n"
        return false
    }

    /// 记录资源目录内容（用于调试）
    private func logBundleContents() {
        if let resourcePath = Bundle.main.resourcePath {
            log += "Application resources: \(resourcePath)\n"
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                log += "Resource directory contents:\n"
                for item in contents {
                    log += "- \(item)\n"

                    // 记录 StarNetBin 目录内容
                    if item == "StarNetBin" {
                        let starNetPath = "\(resourcePath)/StarNetBin"
                        if FileManager.default.fileExists(atPath: starNetPath) {
                            let starNetContents = try FileManager.default.contentsOfDirectory(atPath: starNetPath)
                            log += "  StarNetBin contents:\n"
                            for subItem in starNetContents {
                                log += "  - \(subItem)\n"

                                // 记录 bin 和 lib 目录内容
                                if subItem == "bin" || subItem == "lib" {
                                    let subPath = "\(starNetPath)/\(subItem)"
                                    if FileManager.default.fileExists(atPath: subPath) {
                                        let subContents = try FileManager.default.contentsOfDirectory(atPath: subPath)
                                        log += "    \(subItem) contents:\n"
                                        for file in subContents {
                                            log += "    - \(file)\n"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                log += "Unable to list resources: \(error.localizedDescription)\n"
            }
        } else {
            log += "Resource directory not found\n"
        }
    }
}
