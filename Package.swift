// swift-tools-version: 5.9
import PackageDescription

// Fast, portable checks for pure quick-start policies. The shipping app and its
// SwiftData/UI integration tests remain owned by workouttracker.xcodeproj.
let package = Package(
    name: "WorkoutTrackerPolicyChecks",
    products: [],
    targets: [
        .target(name: "workouttracker", path: "workouttracker/Domain/Models/QuickStart"),
        .testTarget(name: "QuickStartPolicyTests", dependencies: ["workouttracker"],
                    path: "workouttrackerTests/QuickStart")
    ]
)
