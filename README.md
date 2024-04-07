# AsyncPropertyTesting

Give hell to your concurrent code :)

This library was inspired by Antonio Scandurra's talk [Property-testing async code in Rust to build reliable distributed systems](https://youtu.be/ms8zKpS_dZE). Other prior art from the Rust ecosystem includes [turmoil](https://github.com/tokio-rs/turmoil), [loom](https://github.com/tokio-rs/loom), and [shuttle](https://github.com/awslabs/shuttle).

## Usage

Wrap your async test code in `withRandomExecutor`. This will run your test code 100 times, each with a different **deterministic** execution order.

```swift
func testCache() async {
    // fails exactly 44/100 times. can you see why?
    await withRandomExecutor {
        let cache = Cache()
        async let task0 = cache.get(key: 0) { "zero" }
        async let task1 = cache.get(key: 0) { "zero" }
        _ = await (task0, task1)
        let calculations = await cache.calculations
        XCTAssertEqual(calculations, 1)
    }
}

actor Cache {
    var objects: [Int: String] = [:]
    var calculations = 0

    func get(key: Int, compute: () async -> String) async -> String {
        if let value = objects[key] { return value }
        calculations += 1
        let value = await compute()
        objects[key] = value
        return value
    }
}
```
