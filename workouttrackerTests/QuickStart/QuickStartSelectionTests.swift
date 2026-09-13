import XCTest
@testable import workouttracker

final class QuickStartSelectionTests: XCTestCase {
    func testStableStyleCatalogAndBoundedDefaults() {
        XCTAssertEqual(QuickStartStyle.allCases.count, 9)
        XCTAssertEqual(Set(QuickStartStyle.allCases.map(\.rawValue)).count, 9)
        XCTAssertEqual(QuickStartStyle.defaults, [.cardio, .strengthWeights, .bodyweightFunctional, .hiit])
        XCTAssertNil(QuickStartStyle(rawValue: "future_style"))
    }
    func testFavoritesPrecedeDeduplicatedSuccessfulRecents() {
        let result = QuickStartSelectionPolicy.shortlist(
            favorites: ["leg_press", "chest_press", "leg_press"],
            recents: ["chest_press", "row", "missing", "bike", "squat"],
            available: ["leg_press", "chest_press", "row", "bike", "squat"])
        XCTAssertEqual(result, ["leg_press", "chest_press", "row", "bike"])
    }
    func testMissingChoicesDoNotBecomeDifferentExercises() {
        XCTAssertEqual(QuickStartSelectionPolicy.shortlist(favorites: ["deleted"],
            recents: ["deleted"], available: ["squat"]), [])
    }
    func testActiveConflictPreservesSpecificTarget() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(QuickStartSelectionPolicy.startResolution(activeSessionIDs: []), .canStart)
        XCTAssertEqual(QuickStartSelectionPolicy.startResolution(activeSessionIDs: [a, a]), .resolveExisting([a]))
        XCTAssertEqual(QuickStartSelectionPolicy.startResolution(activeSessionIDs: [a, b]), .resolveExisting([a, b]))
    }
    func testUpgradeUsesExplicitEvidenceNotWorkoutCount() {
        XCTAssertEqual(ExperiencePreferenceState.bootstrap(isExistingInstallation: true).effective, .pro)
        XCTAssertEqual(ExperiencePreferenceState.bootstrap(isExistingInstallation: false).effective, .easy)
    }
    func testActiveModeChangeSurvivesEncodingUntilWorkoutEnds() throws {
        var state = ExperiencePreferenceState.bootstrap(isExistingInstallation: false)
        state.request(.pro, hasActiveSession: true)
        XCTAssertEqual(state.effective, .easy)
        XCTAssertEqual(state.requested, .pro)
        var restored = try JSONDecoder().decode(ExperiencePreferenceState.self, from: JSONEncoder().encode(state))
        restored.applyPendingIfIdle(hasActiveSession: true)
        XCTAssertEqual(restored.effective, .easy)
        restored.applyPendingIfIdle(hasActiveSession: false)
        XCTAssertEqual(restored.effective, .pro)
        XCTAssertNil(restored.requested)
    }
    func testChoosingEffectiveModeCancelsPendingChange() {
        var state = ExperiencePreferenceState.bootstrap(isExistingInstallation: true)
        state.request(.easy, hasActiveSession: true)
        state.request(.pro, hasActiveSession: true)
        XCTAssertNil(state.requested)
        XCTAssertEqual(state.effective, .pro)
    }
}
