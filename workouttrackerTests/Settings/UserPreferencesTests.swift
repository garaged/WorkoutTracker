import XCTest
@testable import workouttracker

final class UserPreferencesTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "UserPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_autoSavePreference_persistsAcrossReload() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertFalse(prefs.autoSaveCompletedTrackedActivitiesToAppleHealth)

        prefs.autoSaveCompletedTrackedActivitiesToAppleHealth = true

        let reloaded = UserPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.autoSaveCompletedTrackedActivitiesToAppleHealth)
    }

    func test_resetToDefaults_turnsOffAutoSavePreference() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.autoSaveCompletedTrackedActivitiesToAppleHealth = true

        prefs.resetToDefaults()

        XCTAssertFalse(prefs.autoSaveCompletedTrackedActivitiesToAppleHealth)
        let reloaded = UserPreferences(defaults: defaults)
        XCTAssertFalse(reloaded.autoSaveCompletedTrackedActivitiesToAppleHealth)
    }
}
