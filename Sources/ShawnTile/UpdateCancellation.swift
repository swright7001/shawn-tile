import Foundation

final class UpdateCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var process:Process?
    func check() throws { lock.lock(); let stopped = cancelled; lock.unlock(); if stopped { throw CancellationError() } }
    func attach(_ process:Process) {
        lock.lock(); self.process = process; let stopped = cancelled; lock.unlock()
        if stopped && process.isRunning { process.terminate() }
    }
    func detach() { lock.lock(); process = nil; lock.unlock() }
    func cancel() {
        lock.lock(); cancelled = true; let process = process; lock.unlock()
        if let process, process.isRunning { process.terminate() }
    }
}
