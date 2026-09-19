import Foundation
import Darwin

/// One child per instance. Pipes are drained concurrently, never on the UI thread.
final class CLIProcess: @unchecked Sendable {
    struct Result {
        let status: Int32
        let stdout: Data
        let stderr: Data
        let cancelled: Bool
    }
    private let lock = NSLock()
    private let process = Process()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        if process.isRunning { process.terminate() }
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [self] in
            lock.lock()
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            lock.unlock()
        }
    }

    func run(executable: URL, arguments: [String], timeout: TimeInterval? = nil,
             onData: @escaping (Data, Bool) -> Void = { _, _ in },
             completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let output = Pipe(), errors = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            // No shell and no injected model/library environment overrides.
            process.standardOutput = output
            process.standardError = errors
            lock.lock()
            do {
                if cancelled { throw CLIError.message("Cancelled.") }
                try process.run()
                lock.unlock()
            } catch {
                lock.unlock()
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let timer = timeout.map { interval -> DispatchWorkItem in
                let item = DispatchWorkItem { [weak self] in self?.cancel() }
                DispatchQueue.global().asyncAfter(deadline: .now() + interval, execute: item)
                return item
            }
            let group = DispatchGroup()
            final class Capture: @unchecked Sendable { var data = Data() }
            let stdout = Capture(), stderr = Capture()
            for (pipe, isError, captured) in [(output, false, stdout), (errors, true, stderr)] {
                group.enter()
                DispatchQueue.global().async {
                    defer { group.leave(); try? pipe.fileHandleForReading.close() }
                    while true {
                        // read(upToCount:) can wait for the requested byte count on a pipe.
                        // availableData returns the currently readable chunk, allowing live progress.
                        let data = pipe.fileHandleForReading.availableData
                        if data.isEmpty { break }
                        if captured.data.count < 4_194_304 {
                            captured.data.append(data.prefix(4_194_304 - captured.data.count))
                        }
                        DispatchQueue.main.async { onData(data, isError) }
                    }
                }
            }
            process.waitUntilExit()
            group.wait()
            timer?.cancel()
            lock.lock()
            let result = Result(status: process.terminationStatus, stdout: stdout.data,
                                stderr: stderr.data, cancelled: cancelled)
            lock.unlock()
            // All onData callbacks have been enqueued before completion.
            DispatchQueue.main.async { completion(.success(result)) }
        }
    }

    static func capture(_ executable: URL, _ arguments: [String], timeout: TimeInterval = 10) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let runner = CLIProcess()
            runner.run(executable: executable, arguments: arguments, timeout: timeout) {
                continuation.resume(with: $0)
            }
        }
    }
}
