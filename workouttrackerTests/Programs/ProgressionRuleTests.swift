import XCTest
@testable import workouttracker

final class ProgressionRuleTests: XCTestCase {

    func test_fixedLoadIncreaseRule_isValidWhenStepPositive() {
        XCTAssertTrue(ProgressionRule.fixedLoadIncrease(step: 2.5).isValid)
        XCTAssertFalse(ProgressionRule.fixedLoadIncrease(step: 0).isValid)
    }

    func test_doubleProgressionRule_isInvalidWhenRepRangeIsBackwards() {
        XCTAssertFalse(ProgressionRule.doubleProgression(minReps: 10, maxReps: 8, loadStep: 2.5).isValid)
    }

    func test_ruleRoundTripDecoding_preservesKindAndConfig() throws {
        let rules: [ProgressionRule] = [
            .fixedLoadIncrease(step: 2.5),
            .doubleProgression(minReps: 8, maxReps: 12, loadStep: 2.5),
            .deloadEvery(weeks: 4, percent: 0.1),
            .repeatWeekOnFailureThreshold(failedSets: 2)
        ]

        let data = try JSONEncoder().encode(rules)
        let decoded = try JSONDecoder().decode([ProgressionRule].self, from: data)

        XCTAssertEqual(decoded, rules)
    }
}
