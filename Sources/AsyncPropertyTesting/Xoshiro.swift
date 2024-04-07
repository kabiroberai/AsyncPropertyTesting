// based on
// https://github.com/pointfreeco/swift-gen/blob/67a6c895aeb0d6ab9bdcd5fd91c6f8ae6e8e499c/Sources/Gen/Xoshiro.swift
// which is itself based on
// https://github.com/mattgallagher/CwlUtils/blob/0bfc4587d01cfc796b6c7e118fc631333dd8ab33/Sources/CwlUtils/CwlRandom.swift
// which is in turn based on
// http://xoshiro.di.unimi.it

struct Xoshiro: RandomNumberGenerator {
    var state: (UInt64, UInt64, UInt64, UInt64)

    init(seed: UInt64) {
        self.state = (seed, 18_446_744, 073_709, 551_615)
        for _ in 1...10 { _ = self.next() } // perturb
    }

    mutating func next() -> UInt64 {
        let x = self.state.1 &* 5
        let result = ((x &<< 7) | (x &>> 57)) &* 9
        let t = self.state.1 &<< 17
        self.state.2 ^= self.state.0
        self.state.3 ^= self.state.1
        self.state.1 ^= self.state.2
        self.state.0 ^= self.state.3
        self.state.2 ^= t
        self.state.3 = (self.state.3 &<< 45) | (self.state.3 &>> 19)
        return result
    }
}
