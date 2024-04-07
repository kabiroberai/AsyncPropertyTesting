import XCTest
@testable import AsyncPropertyTesting

final class RandomExecutorTests: XCTestCase {
    func testRandomExecution() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([9, 3, 7, 5, 2, 10, 6, 8, 1, 4], xs.value)
    }

    func testRandomExecutionChangedSeed() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 456) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([5, 3, 10, 7, 1, 2, 9, 4, 6, 8], xs.value)
    }

    func testRandomExecutionDelay() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 1 * NSEC_PER_MSEC)
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([2, 7, 8, 3, 6, 1, 4, 5, 9, 10], xs.value)
    }

    func testRandomExecutionDeadline() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        try? await Task.sleep(for: .milliseconds(1))
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([7, 2, 9, 3, 1, 6, 4, 8, 5, 10], xs.value)
    }

    func testRandomExecutionUnstructured() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        await Task {}.value
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([3, 2, 4, 7, 8, 9, 10, 6, 1, 5], xs.value)
    }

    func testRandomExecutionDetached() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        await Task.detached {}.value
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([3, 2, 4, 7, 8, 9, 10, 6, 1, 5], xs.value)
    }

    func testRandomExecutionUnstructured2() async {
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            var tasks: [Task<Void, Never>] = []
            for x in 1...10 {
                tasks.append(Task {
                    await Task {}.value
                    xs.withValue { $0.append(x) }
                })
            }
            for task in tasks { await task.value }
        }
        XCTAssertEqual([9, 2, 1, 3, 10, 8, 4, 5, 7, 6], xs.value)
    }

    func testRandomExecutionActor() async {
        @globalActor actor MyActor {
            static let shared = MyActor()
        }

        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        await Task { @MyActor in }.value
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([7, 9, 10, 1, 3, 4, 5, 6, 2, 8], xs.value)
    }

    func testRandomExecutionMain() async throws {
        try XCTSkipIf(true, "Currently non-deterministic")
        // FIXME: why is swift_task_enqueueMainExecutor_hook not invoked?
        let xs = LockIsolated<[Int]>([])
        await withRandomExecutor(seed: 123) {
            await withTaskGroup(of: Void.self) { group in
                for x in 1...10 {
                    group.addTask {
                        await Task { @MainActor in }.value
                        xs.withValue { $0.append(x) }
                    }
                }
            }
        }
        XCTAssertEqual([1, 2, 3, 5, 9, 8, 10, 4, 7, 6], xs.value)
    }

    func testCacheExample() async {
        // example: the programmer expected the cache to compute
        // a value for any specific key at most once. However
        // they failed to account for reentrancy.

        actor CacheSUT {
            var objects: [Int: String] = [:]
            var computes = 0

            func get(key: Int, compute: () async -> String) async -> String {
                if let value = objects[key] { return value }
                computes += 1
                let value = await compute()
                objects[key] = value
                return value
            }
        }

        await withRandomExecutor(seed: 0) {
            let cache = CacheSUT()
            async let task0 = cache.get(key: 0) { "zero" }
            async let task1 = cache.get(key: 0) { "zero" }
            _ = await (task0, task1)
            let computes = await cache.computes
            XCTAssertEqual(computes, 2)
        }

        await withRandomExecutor(seed: 2) {
            let cache = CacheSUT()
            async let task0 = cache.get(key: 0) { "zero" }
            async let task1 = cache.get(key: 0) { "zero" }
            _ = await (task0, task1)
            let computes = await cache.computes
            XCTAssertEqual(computes, 1)
        }

        let failures = LockIsolated(0)
        await withRandomExecutor(iterations: 100) {
            let cache = CacheSUT()
            async let task0 = cache.get(key: 0) { "zero" }
            async let task1 = cache.get(key: 0) { "zero" }
            _ = await (task0, task1)
            let computes = await cache.computes
            if computes != 1 {
                failures.withValue { $0 += 1 }
            }
        }
        XCTAssertEqual(failures.value, 44)
    }
}
