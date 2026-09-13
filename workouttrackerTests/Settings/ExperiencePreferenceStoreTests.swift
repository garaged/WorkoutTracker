import XCTest
@testable import workouttracker

@MainActor
final class ExperiencePreferenceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ExperiencePreferenceStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewAndExistingInstallationsBootstrapWithoutWorkoutHeuristics() {
        XCTAssertEqual(ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: false).state.effective, .easy)
        defaults.removePersistentDomain(forName: suiteName)
        XCTAssertEqual(ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: true).state.effective, .pro)
    }

    func testExplicitChoicePersistsAcrossRelaunchRegardlessOfLaterEvidence() {
        let original = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: true)
        original.request(.easy, hasActiveSession: false)
        let restored = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: true)
        XCTAssertEqual(restored.state.effective, .easy)
        let contradictoryEvidence = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: false)
        XCTAssertEqual(contradictoryEvidence.state.effective, .easy)
    }

    func testActiveChangePersistsPendingUntilIdleThenCommits() {
        let original = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: false)
        original.request(.pro, hasActiveSession: true)
        XCTAssertEqual(original.state.effective, .easy)
        XCTAssertEqual(original.state.requested, .pro)
        let restored = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: true)
        restored.applyPendingIfIdle(hasActiveSession: true)
        XCTAssertEqual(restored.state.effective, .easy)
        restored.applyPendingIfIdle(hasActiveSession: false)
        XCTAssertEqual(restored.state.effective, .pro)
        XCTAssertNil(restored.state.requested)
        XCTAssertEqual(ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: false).state.effective, .pro)
    }

    func testCorruptSnapshotUsesExplicitSafeBootstrapAndBecomesStable() {
        defaults.set(Data("not-json".utf8), forKey: ExperiencePreferenceStore.storageKey)
        let recovered = ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: true)
        XCTAssertEqual(recovered.state.effective, .pro)
        XCTAssertEqual(ExperiencePreferenceStore(defaults: defaults, isExistingInstallation: false).state.effective, .pro)
    }
}
