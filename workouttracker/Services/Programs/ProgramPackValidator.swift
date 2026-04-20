import Foundation

enum ProgramPackValidator {
    struct Options: Hashable, Sendable {
        let allowMissingAssets: Bool

        static let strict = Options(allowMissingAssets: false)
        static let programOnly = Options(allowMissingAssets: true)
    }

    struct Issue: Hashable, Sendable {
        enum Severity: String, Hashable, Sendable {
            case warning
            case error
        }

        enum Code: String, Hashable, Sendable {
            case emptyPack
            case emptyPackID
            case duplicateProgramID
            case duplicateProgramSlug
            case duplicateExerciseSlug
            case duplicateRoutineSlug
            case duplicateWeekIndex
            case duplicateDayIndex
            case duplicatePrescriptionOrder
            case duplicateRoutineItemOrder
            case duplicateSetPlanOrder
            case missingRoutineReference
            case missingExerciseReference
            case invalidOrdering
            case invalidNumericRange
            case invalidProgressionRule
            case invalidTrackingStyle
            case invalidExerciseModality
            case invalidWeightUnit
            case invalidProgramName
            case invalidDayTitle
        }

        let severity: Severity
        let code: Code
        let path: String
        let message: String
    }

    struct Report: Hashable, Sendable {
        let issues: [Issue]

        var warnings: [Issue] {
            issues.filter { $0.severity == .warning }
        }

        var errors: [Issue] {
            issues.filter { $0.severity == .error }
        }

        var isValid: Bool {
            errors.isEmpty
        }
    }

    static func validate(_ pack: ProgramPack, options: Options = .strict) -> Report {
        var issues: [Issue] = []

        if pack.packID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.error(.emptyPackID, path: "packID", message: "Pack id must not be empty."))
        }

        if pack.programs.isEmpty {
            issues.append(.error(.emptyPack, path: "programs", message: "Pack contains no programs."))
        }

        issues.append(contentsOf: duplicateIssues(
            values: pack.programs.map(\.id.uuidString),
            path: "programs",
            code: .duplicateProgramID,
            message: "Pack has duplicate program ids."
        ))
        issues.append(contentsOf: duplicateIssues(
            values: pack.programs.map { ProgramPackHelpers.normalizedSlug($0.slug) },
            path: "programs",
            code: .duplicateProgramSlug,
            message: "Pack has duplicate program slugs."
        ))
        issues.append(contentsOf: duplicateIssues(
            values: pack.exercises.map { ProgramPackHelpers.normalizedSlug($0.slug) },
            path: "exercises",
            code: .duplicateExerciseSlug,
            message: "Pack has duplicate exercise slugs."
        ))
        issues.append(contentsOf: duplicateIssues(
            values: pack.routines.map { ProgramPackHelpers.normalizedSlug($0.slug) },
            path: "routines",
            code: .duplicateRoutineSlug,
            message: "Pack has duplicate routine slugs."
        ))

        let exerciseSlugs = Set(pack.exercises.map { ProgramPackHelpers.normalizedSlug($0.slug) })
        let routineSlugs = Set(pack.routines.map { ProgramPackHelpers.normalizedSlug($0.slug) })

        for (exerciseIndex, exercise) in pack.exercises.enumerated() {
            let path = "exercises[\(exerciseIndex)]"
            if ExerciseModality(rawValue: exercise.modality) == nil {
                issues.append(.error(.invalidExerciseModality, path: "\(path).modality", message: "Exercise modality is invalid."))
            }
        }

        for (routineIndex, routine) in pack.routines.enumerated() {
            let basePath = "routines[\(routineIndex)]"
            let itemOrders = routine.items.map(\.order)
            if !isStrictlyIncreasing(itemOrders) {
                issues.append(.error(.invalidOrdering, path: "\(basePath).items", message: "Routine items must be in strictly increasing order."))
            }
            if Set(itemOrders).count != itemOrders.count {
                issues.append(.error(.duplicateRoutineItemOrder, path: "\(basePath).items", message: "Routine contains duplicate item orders."))
            }

            for (itemIndex, item) in routine.items.enumerated() {
                let itemPath = "\(basePath).items[\(itemIndex)]"
                if !exerciseSlugs.contains(ProgramPackHelpers.normalizedSlug(item.exerciseSlug)) {
                    let severity: Issue.Severity = options.allowMissingAssets ? .warning : .error
                    issues.append(Issue(
                        severity: severity,
                        code: .missingExerciseReference,
                        path: "\(itemPath).exerciseSlug",
                        message: "Routine references a missing exercise slug."
                    ))
                }
                if ExerciseTrackingStyle(rawValue: item.trackingStyle) == nil {
                    issues.append(.error(.invalidTrackingStyle, path: "\(itemPath).trackingStyle", message: "Routine item tracking style is invalid."))
                }

                let setPlanOrders = item.setPlans.map(\.order)
                if !isStrictlyIncreasing(setPlanOrders) {
                    issues.append(.error(.invalidOrdering, path: "\(itemPath).setPlans", message: "Set plans must be in strictly increasing order."))
                }
                if Set(setPlanOrders).count != setPlanOrders.count {
                    issues.append(.error(.duplicateSetPlanOrder, path: "\(itemPath).setPlans", message: "Routine item contains duplicate set plan orders."))
                }

                for (setPlanIndex, setPlan) in item.setPlans.enumerated() {
                    let setPlanPath = "\(itemPath).setPlans[\(setPlanIndex)]"
                    if let weightUnit = setPlan.weightUnit, WeightUnit(rawValue: weightUnit) == nil {
                        issues.append(.error(.invalidWeightUnit, path: "\(setPlanPath).weightUnit", message: "Set plan weight unit is invalid."))
                    }
                    issues.append(contentsOf: numericIssues(
                        targetReps: setPlan.targetReps,
                        targetWeight: setPlan.targetWeight,
                        targetDurationSeconds: setPlan.targetDurationSeconds,
                        targetDistance: setPlan.targetDistance,
                        targetRPE: setPlan.targetRpe,
                        restSeconds: setPlan.restSeconds,
                        path: setPlanPath
                    ))
                }
            }
        }

        for (programIndex, program) in pack.programs.enumerated() {
            let programPath = "programs[\(programIndex)]"

            if program.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.error(.invalidProgramName, path: "\(programPath).name", message: "Program name must not be empty."))
            }

            let weekIndexes = program.weeks.map(\.index)
            if Set(weekIndexes).count != weekIndexes.count {
                issues.append(.error(.duplicateWeekIndex, path: "\(programPath).weeks", message: "Program contains duplicate week indexes."))
            }
            if !isStrictlyIncreasing(weekIndexes) {
                issues.append(.error(.invalidOrdering, path: "\(programPath).weeks", message: "Program weeks must be in strictly increasing order."))
            }

            for (weekOffset, week) in program.weeks.enumerated() {
                let weekPath = "\(programPath).weeks[\(weekOffset)]"
                let dayIndexes = week.days.map(\.index)
                if Set(dayIndexes).count != dayIndexes.count {
                    issues.append(.error(.duplicateDayIndex, path: "\(weekPath).days", message: "Week contains duplicate day indexes."))
                }
                if !isStrictlyIncreasing(dayIndexes) {
                    issues.append(.error(.invalidOrdering, path: "\(weekPath).days", message: "Week days must be in strictly increasing order."))
                }

                for (dayOffset, day) in week.days.enumerated() {
                    let dayPath = "\(weekPath).days[\(dayOffset)]"
                    if day.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(.error(.invalidDayTitle, path: "\(dayPath).title", message: "Day title must not be empty."))
                    }

                    let prescriptionOrders = day.prescriptions.map(\.order)
                    if Set(prescriptionOrders).count != prescriptionOrders.count {
                        issues.append(.error(.duplicatePrescriptionOrder, path: "\(dayPath).prescriptions", message: "Day contains duplicate prescription orders."))
                    }
                    if !isStrictlyIncreasing(prescriptionOrders) {
                        issues.append(.error(.invalidOrdering, path: "\(dayPath).prescriptions", message: "Prescriptions must be in strictly increasing order."))
                    }

                    if !day.isRestLikeDay {
                        let routineSlug = day.primaryRoutineReference?.slug.map { ProgramPackHelpers.normalizedSlug($0) }
                        if let routineSlug {
                            if !routineSlugs.contains(routineSlug) {
                                let severity: Issue.Severity = options.allowMissingAssets ? .warning : .error
                                issues.append(Issue(
                                    severity: severity,
                                    code: .missingRoutineReference,
                                    path: "\(dayPath).blocks",
                                    message: "Program day references a missing routine slug."
                                ))
                            }
                        } else {
                            issues.append(.error(.missingRoutineReference, path: "\(dayPath).blocks", message: "Program day is missing a routine reference."))
                        }
                    }

                    for (prescriptionOffset, prescription) in day.prescriptions.enumerated() {
                        let prescriptionPath = "\(dayPath).prescriptions[\(prescriptionOffset)]"
                        issues.append(contentsOf: numericIssues(
                            targetSets: prescription.targetSets,
                            targetReps: prescription.targetReps,
                            targetWeight: prescription.targetWeight,
                            targetDurationSeconds: prescription.targetDurationSeconds,
                            targetDistance: prescription.targetDistance,
                            targetRPE: prescription.targetRPE,
                            path: prescriptionPath
                        ))

                        for (ruleOffset, rule) in prescription.progressionRules.enumerated() {
                            if !rule.isValid {
                                issues.append(.error(.invalidProgressionRule, path: "\(prescriptionPath).progressionRules[\(ruleOffset)]", message: "Prescription contains an invalid progression rule."))
                            }
                        }
                    }
                }
            }
        }

        return Report(issues: issues.sorted(by: issueSort))
    }

    private static func duplicateIssues(
        values: [String],
        path: String,
        code: Issue.Code,
        message: String
    ) -> [Issue] {
        let duplicates = Dictionary(grouping: values, by: { $0 })
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .keys
            .sorted()

        return duplicates.map { value in
            .error(code, path: path, message: "\(message) Duplicate value: \(value).")
        }
    }

    private static func numericIssues(
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistance: Double? = nil,
        targetRPE: Double? = nil,
        restSeconds: Int? = nil,
        path: String
    ) -> [Issue] {
        var issues: [Issue] = []

        if let targetSets, targetSets <= 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetSets", message: "Target sets must be greater than zero."))
        }
        if let targetReps, targetReps <= 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetReps", message: "Target reps must be greater than zero."))
        }
        if let targetWeight, targetWeight < 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetWeight", message: "Target weight must be non-negative."))
        }
        if let targetDurationSeconds, targetDurationSeconds <= 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetDurationSeconds", message: "Target duration must be greater than zero."))
        }
        if let targetDistance, targetDistance <= 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetDistance", message: "Target distance must be greater than zero."))
        }
        if let targetRPE, !(0...10).contains(targetRPE) {
            issues.append(.error(.invalidNumericRange, path: "\(path).targetRPE", message: "Target RPE must be between 0 and 10."))
        }
        if let restSeconds, restSeconds < 0 {
            issues.append(.error(.invalidNumericRange, path: "\(path).restSeconds", message: "Rest seconds must be non-negative."))
        }

        return issues
    }

    private static func isStrictlyIncreasing(_ values: [Int]) -> Bool {
        guard values.count > 1 else { return true }
        return zip(values, values.dropFirst()).allSatisfy(<)
    }

    private static func issueSort(lhs: Issue, rhs: Issue) -> Bool {
        if lhs.severity != rhs.severity {
            return lhs.severity == .error
        }
        if lhs.path != rhs.path {
            return lhs.path < rhs.path
        }
        if lhs.code != rhs.code {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        return lhs.message < rhs.message
    }
}

private extension ProgramPackValidator.Issue {
    static func error(_ code: Code, path: String, message: String) -> Self {
        Self(severity: .error, code: code, path: path, message: message)
    }
}
