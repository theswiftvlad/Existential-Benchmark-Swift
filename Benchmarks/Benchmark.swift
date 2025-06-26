import Benchmark

// MARK: — Protocol and types with fair comparison

protocol P {
    var value: Int { get }
    @inline(never)
    func getValue() -> Int
}

extension Int: P {
    var value: Int { self }
    @inline(never)
    func getValue() -> Int { self }
}

struct S: P {
    let value: Int = 42
    @inline(never)
    func getValue() -> Int { value }
}

class Box: P {
    let v: Int
    var value: Int { v }
    init(_ v: Int = 42) { self.v = v }
    
    @inline(never)
    func getValue() -> Int { v }
}

// Global data to prevent compiler optimizations
var globalMixedArray: [any P] = []

@inline(never)
func createRandomP(_ seed: Int) -> any P {
    switch seed % 3 {
    case 0: return 42
    case 1: return S()
    default: return Box()
    }
}

// Prevent optimizer from removing sums
@inline(never)
func blackHole<T>(_ value: T) {
    withUnsafePointer(to: value) { _ in }
}

final class Test {
    let p: any P
    
    init(p: any P) {
        self.p = p
    }
    
    @inline(never)
    func run(iterations: Int) -> Int {
        var sum = 0
        for _ in 0..<iterations {
            sum &+= p.getValue() + 1
        }
        return sum
    }
}

func start() {
    let innerLoop = 1_000_000
    
    // Prepare global data
    globalMixedArray = (0..<100).map { createRandomP($0) }

    // —— 1) Raw Int addition (baseline) ——
    benchmark("Raw Int + anchored loop") {
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= 42 + 1
        }
        blackHole(sum)
    }

    // —— 2) Any boxing & unboxing ——
    benchmark("Any boxing & unboxing Int anchored loop") {
        var sum = 0
        let anyValue: Any = 42
        for _ in 0..<innerLoop {
            sum &+= (anyValue as! Int) + 1
        }
        blackHole(sum)
    }

    // —— 3) Direct Box.v access ——
    benchmark("Direct Box.v anchored loop") {
        let box = Box()
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= box.v + 1
        }
        blackHole(sum)
    }

    // —— 4) AnyObject boxing & unboxing ——
    benchmark("AnyObject boxing & unboxing Box anchored loop") {
        var sum = 0
        let anyObj: AnyObject = Box()
        for _ in 0..<innerLoop {
            sum &+= ((anyObj as! Box).v + 1)
        }
        blackHole(sum)
    }

    // —— 5) some P static dispatch with data access ——
    benchmark("some P value access anchored loop") {
        let s: some P = 42  // Use let, not var
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= s.value + 1
        }
        blackHole(sum)
    }

    // —— 6) any P dynamic dispatch (MISLEADING - compiler optimizes!) ——
    benchmark("any P value access (MISLEADING - optimized)") {
        let p: any P = 42  // Compiler knows this is Int!
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= p.value + 1
        }
        blackHole(sum)
    }

    // —— 7) some P static dispatch with method call ——
    benchmark("some P method call anchored loop") {
        let s: some P = 42
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= s.getValue() + 1
        }
        blackHole(sum)
    }

    // —— 8) any P dynamic dispatch (MISLEADING - compiler optimizes!) ——
    benchmark("any P method call (MISLEADING - optimized)") {
        let p: any P = 42  // Compiler knows this is Int!
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= p.getValue() + 1
        }
        blackHole(sum)
    }

    // —— 9) any P from global array (REALISTIC!) ——
    benchmark("any P from global array (REALISTIC)") {
        var sum = 0
        let arraySize = globalMixedArray.count
        for i in 0..<innerLoop {
            let obj = globalMixedArray[i % arraySize]
            sum &+= obj.value + 1
        }
        blackHole(sum)
    }

    // —— 10) any P created dynamically (REALISTIC!) ——
    benchmark("any P created dynamically (REALISTIC)") {
        var sum = 0
        for i in 0..<innerLoop {
            let obj = createRandomP(i)
            sum &+= obj.getValue() + 1
        }
        blackHole(sum)
    }

    // —— 11) Mixed types through any P (real-world scenario) ——
    benchmark("any P mixed types anchored loop") {
        let objects: [any P] = [42, S(), Box()]
        var sum = 0
        for _ in 0..<innerLoop/3 {  // Divide by 3 since we process 3 items
            for obj in objects {
                sum &+= obj.value + 1
            }
        }
        blackHole(sum)
    }

    // —— 12) Class with stored any P (REALISTIC!) ——
    benchmark("any P wrapped in class as dependency") {
        let sut = Test(p: createRandomP(42))  // Unknown type at compile time
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= sut.run(iterations: 1)
        }
        blackHole(sum)
    }

    print("Running benchmarks...")
    print("NOTE: Tests 6 & 8 are misleading - compiler can optimize them!")
    print("Tests 9, 10, 11, 12 show REAL any P performance.")
    Benchmark.main()
}
