import Foundation

// CI tends to be slower than a local Mac + warm simulator.
// Scale UI timeouts automatically when running under GitHub Actions / CI.
enum UITestTiming {
    static let multiplier: Double = {
        let env = ProcessInfo.processInfo.environment
        if env["GITHUB_ACTIONS"] == "true" { return 2.0 }
        if env["CI"] == "true" { return 2.0 }
        return 1.0
    }()

    static func scaled(_ base: TimeInterval) -> TimeInterval { base * multiplier }
}

@inline(__always)
func t(_ base: TimeInterval) -> TimeInterval {
    UITestTiming.scaled(base)
}
