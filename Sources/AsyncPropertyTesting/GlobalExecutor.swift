import Foundation

func withGlobalExecutor(
    _ executor: @escaping Hook,
    @_implicitSelfCapture operation: @Sendable () async throws -> Void
) async rethrows {
    let oldHook = swift_task_enqueueGlobal_hook
    let oldDelayHook = swift_task_enqueueGlobalWithDelay_hook
    let oldDeadlineHook = swift_task_enqueueGlobalWithDeadline_hook
    let oldMainHook = swift_task_enqueueMainExecutor_hook
    let oldRunner = runner
    defer {
        swift_task_enqueueGlobal_hook = oldHook
        swift_task_enqueueGlobalWithDelay_hook = oldDelayHook
        swift_task_enqueueGlobalWithDeadline_hook = oldDeadlineHook
        swift_task_enqueueMainExecutor_hook = oldMainHook
        runner = oldRunner
    }
    swift_task_enqueueGlobal_hook = rawHook
    swift_task_enqueueGlobalWithDelay_hook = rawDelayHook
    swift_task_enqueueGlobalWithDeadline_hook = rawDeadlineHook
    swift_task_enqueueMainExecutor_hook = rawMainHook
    runner = executor
    // ensure that `operation` itself runs on the global executor too,
    // otherwise it may race.
    await Task { @MainActor in }.value
    try await operation()
}

typealias Original = @convention(thin) (UnownedJob) -> Void
typealias Hook = (UnownedJob) -> Void
private var runner: Hook = { _ in }

private typealias RawHook = @convention(thin) (UnownedJob, Original) -> Void
private let rawHook: RawHook = { job, _ in runner(job) }
private var swift_task_enqueueGlobal_hook: RawHook? {
    get { _swift_task_enqueueGlobal_hook.pointee }
    set { _swift_task_enqueueGlobal_hook.pointee = newValue }
}
private let _swift_task_enqueueGlobal_hook: UnsafeMutablePointer<RawHook?> =
    dlsym(dlopen(nil, 0), "swift_task_enqueueGlobal_hook").assumingMemoryBound(to: RawHook?.self)

private typealias RawDelayHook = @convention(thin) (CUnsignedLongLong, UnownedJob, Original) -> Void
private let rawDelayHook: RawDelayHook = { _, job, _ in
    runner(job)
}
private var swift_task_enqueueGlobalWithDelay_hook: RawDelayHook? {
    get { _swift_task_enqueueGlobalWithDelay_hook.pointee }
    set { _swift_task_enqueueGlobalWithDelay_hook.pointee = newValue }
}
private let _swift_task_enqueueGlobalWithDelay_hook: UnsafeMutablePointer<RawDelayHook?> =
    dlsym(dlopen(nil, 0), "swift_task_enqueueGlobalWithDelay_hook").assumingMemoryBound(to: RawDelayHook?.self)

private typealias RawDeadlineHook = @convention(thin) (CLongLong, CLongLong, CLongLong, CLongLong, CInt, UnownedJob, Original) -> Void
private let rawDeadlineHook: RawDeadlineHook = { _, _, _, _, _, job, _ in
    runner(job)
}
private var swift_task_enqueueGlobalWithDeadline_hook: RawDeadlineHook? {
    get { _swift_task_enqueueGlobalWithDeadline_hook.pointee }
    set { _swift_task_enqueueGlobalWithDeadline_hook.pointee = newValue }
}
private let _swift_task_enqueueGlobalWithDeadline_hook: UnsafeMutablePointer<RawDeadlineHook?> =
    dlsym(dlopen(nil, 0), "swift_task_enqueueGlobalWithDeadline_hook").assumingMemoryBound(to: RawDeadlineHook?.self)

private let rawMainHook: RawHook = { job, _ in
    DispatchQueue.main.async {
        job.runSynchronously(on: MainActor.sharedUnownedExecutor)
    }
}
private var swift_task_enqueueMainExecutor_hook: RawHook? {
    get { _swift_task_enqueueMainExecutor_hook.pointee }
    set { _swift_task_enqueueMainExecutor_hook.pointee = newValue }
}
private let _swift_task_enqueueMainExecutor_hook: UnsafeMutablePointer<RawHook?> =
    dlsym(dlopen(nil, 0), "swift_task_enqueueMainExecutor_hook").assumingMemoryBound(to: RawHook?.self)
