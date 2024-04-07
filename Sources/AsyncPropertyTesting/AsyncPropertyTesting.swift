import Foundation

public func withRandomExecutor(
    seed: UInt64,
    @_implicitSelfCapture operation: @Sendable () async throws -> Void
) async rethrows {
    let executor = RandomExecutor(seed: seed)
    try await withGlobalExecutor({ job in
        executor.enqueue(job)
    }, operation: operation)
}

public func withRandomExecutor(
    iterations: Int,
    @_implicitSelfCapture operation: @Sendable () async throws -> Void
) async rethrows {
    for seed in 0..<UInt64(iterations) {
        try await withRandomExecutor(seed: seed, operation: operation)
    }
}

private final class RandomExecutor: SerialExecutor {
    private struct CriticalState {
        var rng: Xoshiro
        var isRunning = false
        var pending: [UnownedJob] = []
    }
    private let state: LockIsolated<CriticalState>
    private let queue = DispatchQueue(label: "random-executor")

    init(seed: UInt64) {
        state = LockIsolated(CriticalState(rng: Xoshiro(seed: seed)))
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    private func runNext() {
        let maybeJob: UnownedJob? = state.withValue { state in
            if let next = state.pending.indices.randomElement(using: &state.rng) {
                return state.pending.remove(at: next)
            } else {
                state.isRunning = false
                return nil
            }
        }
        guard let job = maybeJob else { return }
        job.runSynchronously(on: asUnownedSerialExecutor())
        queue.async { self.runNext() }
    }

    func enqueue(_ job: UnownedJob) {
        queue.async { [self] in
            let wasRunning = state.withValue { state in
                state.pending.append(job)
                let wasRunning = state.isRunning
                state.isRunning = true
                return wasRunning
            }
            guard !wasRunning else { return }
            runNext()
        }
    }
}
