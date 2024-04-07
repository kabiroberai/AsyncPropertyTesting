// based on
// https://github.com/pointfreeco/swift-concurrency-extras/blob/f7e9d4ad59d3ecabe5cc207c5e655a03b2b56876/Sources/ConcurrencyExtras/LockIsolated.swift

import Foundation

final class LockIsolated<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()

    init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
        self._value = try value()
    }

    func withValue<T: Sendable>(
        _ operation: @Sendable (inout Value) throws -> T
    ) rethrows -> T {
        try lock.withLock {
            var value = self._value
            defer { self._value = value }
            return try operation(&value)
        }
    }

    var value: Value {
        lock.withLock { self._value }
    }
}
