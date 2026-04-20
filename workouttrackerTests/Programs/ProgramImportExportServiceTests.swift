import XCTest
@testable import workouttracker

final class ProgramImportExportServiceTests: XCTestCase {

    func test_previewImport_v2Pack_and_importsPrograms_intoLibrary() async throws {
        // Create a V2 pack file
        let pack = makeSamplePackV2(programDays: [1])

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(pack)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("program_pack_v2_\(UUID().uuidString).json")
        try data.write(to: tmp, options: [.atomic])

        // Use unique base folder so tests don't share state
        let io = ProgramImportExportService(baseFolderName: "WorkoutTrackerTests-\(UUID().uuidString)")

        // Preview (should report v2)
        let preview = try await io.previewImport(fileURL: tmp)
        XCTAssertEqual(preview.packVersion, 2)
        XCTAssertEqual(preview.programs.count, 1)

        // Import programs into library
        _ = try await io.importFromPreview(preview, strategy: .renameOnConflict)

        let library = try await io.loadLibrary()
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(library.first?.slug, "sample-program")
    }

    func test_importFromPreview_keepExisting_preservesExistingProgram() async throws {
        let existing = TrainingProgram(slug: "sample-program", name: "Existing Program", weeks: [TrainingWeek(index: 1, days: [])])
        let incoming = TrainingProgram(id: existing.id, slug: "sample-program", name: "Incoming Program", weeks: [TrainingWeek(index: 1, days: [])])

        let io = ProgramImportExportService(baseFolderName: "WorkoutTrackerTests-\(UUID().uuidString)")
        try await io.saveLibrary([existing])

        let preview = ProgramImportExportService.ImportPreview(
            pack: ProgramPack(formatVersion: 2, packID: "sample-pack", generatedAt: Date(), programs: [incoming]),
            validationIssues: [],
            rawData: Data()
        )

        let library = try await io.importFromPreview(preview, strategy: .keepExisting)
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(library.first?.name, "Existing Program")
    }

    func test_importFromPreview_replaceExisting_updatesProgram() async throws {
        let existing = TrainingProgram(slug: "sample-program", name: "Existing Program", weeks: [TrainingWeek(index: 1, days: [])])
        let incoming = TrainingProgram(id: existing.id, slug: "sample-program", name: "Updated Program", weeks: [TrainingWeek(index: 1, days: [])])

        let io = ProgramImportExportService(baseFolderName: "WorkoutTrackerTests-\(UUID().uuidString)")
        try await io.saveLibrary([existing])

        let preview = ProgramImportExportService.ImportPreview(
            pack: ProgramPack(formatVersion: 2, packID: "sample-pack", generatedAt: Date(), programs: [incoming]),
            validationIssues: [],
            rawData: Data()
        )

        let library = try await io.importFromPreview(preview, strategy: .replaceExisting)
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(library.first?.name, "Updated Program")
    }

    func test_importFromPreview_renameOnConflict_importsCopyWithUniqueSlug() async throws {
        let existing = TrainingProgram(slug: "sample-program", name: "Existing Program", weeks: [TrainingWeek(index: 1, days: [])])
        let incoming = TrainingProgram(id: existing.id, slug: "sample-program", name: "Imported Copy", weeks: [TrainingWeek(index: 1, days: [])])

        let io = ProgramImportExportService(baseFolderName: "WorkoutTrackerTests-\(UUID().uuidString)")
        try await io.saveLibrary([existing])

        let preview = ProgramImportExportService.ImportPreview(
            pack: ProgramPack(formatVersion: 2, packID: "sample-pack", generatedAt: Date(), programs: [incoming]),
            validationIssues: [],
            rawData: Data()
        )

        let library = try await io.importFromPreview(preview, strategy: .renameOnConflict)
        XCTAssertEqual(library.count, 2)
        XCTAssertEqual(Set(library.map(\.slug)).count, 2)
        XCTAssertTrue(library.contains { $0.slug == "sample-program-2" })
    }

    // MARK: - Helpers

    private func makeSamplePackV2(programDays: [Int]) -> ProgramPackV2 {
        let ex = ExerciseDTO(slug: "goblet-squat", name: "Goblet Squat", modality: "strength", instructions: nil, notes: nil, equipmentTags: nil)

        let routine = RoutineDTO(
            slug: "beginner-full-body-a",
            name: "Beginner Full Body A",
            notes: nil,
            items: [
                RoutineItemDTO(
                    order: 1,
                    exerciseSlug: "goblet-squat",
                    trackingStyle: "strength",
                    notes: nil,
                    setPlans: [SetPlanDTO(order: 1, targetReps: 8, targetWeight: nil, weightUnit: "kg", targetDurationSeconds: nil, targetDistance: nil, targetRpe: nil, restSeconds: 90)]
                )
            ]
        )

        let days: [TrainingDay] = programDays.map { idx in
            TrainingDay(index: idx, title: "Full Body A", blocks: [
                .init(kind: .workout, title: "Routine", estimatedMinutes: 60, reference: .init(kind: .routine, slug: "beginner-full-body-a"))
            ])
        }

        let program = TrainingProgram(slug: "sample-program", name: "Sample Program", weeks: [TrainingWeek(index: 1, days: days)])
        return ProgramPackV2(formatVersion: 2, generatedAt: Date(), exercises: [ex], routines: [routine], programs: [program])
    }
}
