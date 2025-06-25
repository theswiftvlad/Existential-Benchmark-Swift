import SwiftUI

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
