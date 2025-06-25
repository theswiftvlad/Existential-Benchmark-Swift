import SwiftUI
import Benchmark

@main
struct BenchmarksApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Benchmark")
                .onAppear {
                    start()
                }
        }
    }
}

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
    
    @inline(never)
    func foo() {}
}

func start() {
    // How many inner calls per benchmark
    let innerLoop = 1_000_000

    // —— 1) Raw Int addition (baseline) ——
    benchmark("Raw Int + anchored loop") {
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= 42 + 1
        }
    }

    // —— 2) Any boxing & unboxing ——
    benchmark("Any boxing & unboxing Int anchored loop") {
        var sum = 0
        for _ in 0..<innerLoop {
            let anyValue: Any = 42
            sum &+= (anyValue as! Int) + 1
        }
    }

    // —— 3) Direct Box.v access ——
    benchmark("Direct Box.v anchored loop") {
        let box = Box()
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= box.v + 1
        }
    }

    // —— 4) AnyObject boxing & unboxing ——
    benchmark("AnyObject boxing & unboxing Box anchored loop") {
        var sum = 0
        for _ in 0..<innerLoop {
            let anyObj: AnyObject = Box()
            sum &+= ((anyObj as! Box).v + 1)
        }
    }

    // —— 5) some P static dispatch with data access ——
    benchmark("some P value access anchored loop") {
        let s: some P = 42
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= s.value + 1
        }
    }

    // —— 6) any P dynamic dispatch with data access ——
    benchmark("any P value access anchored loop") {
        let p: any P = 42
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= p.value + 1
        }
    }

    // —— 7) some P static dispatch with method call ——
    benchmark("some P method call anchored loop") {
        let s: some P = 42
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= s.getValue() + 1
        }
    }

    // —— 8) any P dynamic dispatch with method call ——
    benchmark("any P method call anchored loop") {
        let p: any P = 42
        var sum = 0
        for _ in 0..<innerLoop {
            sum &+= p.getValue() + 1
        }
    }

    // —— 9) Box through any P value access (fair comparison) ——
    benchmark("any P Box value access anchored loop") {
        let p: any P = Box()
        var sum = 0
        for _ in 0..<innerLoop { sum &+= p.value + 1 }
    }

    // —— 10) Box method through any P (fair comparison) ——
    benchmark("any P Box method call anchored loop") {
        let p: any P = Box()
        var sum = 0
        for _ in 0..<innerLoop { sum &+= p.getValue() + 1 }
    }

    // —— 11) Mixed types through any P (real-world scenario) ——
    benchmark("any P mixed types anchored loop") {
        let objects: [any P] = [42, S(), Box()]
        var sum = 0
        for _ in 0..<innerLoop {
            for obj in objects {
                sum &+= obj.value + 1
            }
        }
    }

    // —— 12) Protocol witness table overhead ——
    benchmark("any P Int vs direct Int comparison") {
        let p: any P = 42
        let direct = 42
        var sum1 = 0
        var sum2 = 0
        
        for _ in 0..<innerLoop/2 {
            sum1 &+= p.value + 1
            sum2 &+= direct + 1
        }
    }

    print("Running benchmarks...")
    Benchmark.main()
}
