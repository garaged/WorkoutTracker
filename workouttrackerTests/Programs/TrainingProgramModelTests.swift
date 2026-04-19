import XCTest
@testable import workouttracker

final class TrainingProgramModelTests: XCTestCase {

    func test_orderingAndValidation_followWeekDayRelationships() {
        let dayThree = ProgramDay(index: 3, title: "Day 3")
        let dayOne = ProgramDay(
            index: 1,
            title: "Day 1",
            prescriptions: [
                ProgramPrescription(order: 2, exerciseKey: "bench-press"),
                ProgramPrescription(order: 1, exerciseKey: "squat")
            ]
        )

        let weekTwo = ProgramWeek(index: 2, days: [ProgramDay(index: 2, title: "Week 2 Day 2")])
        let weekOne = ProgramWeek(index: 1, days: [dayThree, dayOne])

        let program = TrainingProgram(
            slug: "linear-strength-4-week",
            name: "Linear Strength 4 Week",
            weeks: [weekTwo, weekOne],
            source: .bundled
        )

        XCTAssertEqual(program.orderedWeeks.map(\.index), [1, 2])
        XCTAssertEqual(program.orderedWeeks[0].orderedDays.map(\.index), [1, 3])
        XCTAssertEqual(program.orderedWeeks[0].orderedDays[0].orderedPrescriptions.map(\.order), [1, 2])
        XCTAssertEqual(program.totalTrainingDays, 3)
        XCTAssertTrue(program.validationIssues().isEmpty)
    }

    func test_validationIssues_detectDuplicateWeekAndDayIndexes() {
        let program = TrainingProgram(
            name: "Broken",
            weeks: [
                ProgramWeek(index: 1, days: [ProgramDay(index: 1, title: "A"), ProgramDay(index: 1, title: "B")]),
                ProgramWeek(index: 1, days: [])
            ]
        )

        let issues = program.validationIssues()
        XCTAssertTrue(issues.contains("Program contains duplicate week indexes."))
        XCTAssertTrue(issues.contains(where: { $0.contains("Duplicate day indexes.") }))
    }

    func test_seedCatalogDecodesOptionalPrograms_withoutAffectingExistingFields() throws {
        let json = #"""
        {
          "programs": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "slug": "seed-linear",
              "name": "Seed Linear",
              "source": "bundled",
              "weeks": [
                {
                  "index": 1,
                  "days": [
                    {
                      "index": 1,
                      "title": "Lower",
                      "prescriptions": [
                        { "order": 1, "exerciseKey": "back-squat", "targetReps": 5 }
                      ]
                    }
                  ]
                }
              ]
            }
          ],
          "exercises": [],
          "routines": []
        }
        """#

        let data = try XCTUnwrap(json.data(using: .utf8))
        let catalog = try JSONDecoder().decode(SeedCatalog.self, from: data)

        XCTAssertEqual(catalog.programs.count, 1)
        XCTAssertEqual(catalog.programs.first?.slug, "seed-linear")
        XCTAssertEqual(catalog.programs.first?.weeks.first?.days.first?.prescriptions.first?.exerciseKey, "back-squat")
    }
}
