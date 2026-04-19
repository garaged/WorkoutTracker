import Foundation

enum ProgressionEngine {

    static func evaluate(
        session: WorkoutSession,
        program: TrainingProgram
    ) -> ProgressionDecision {
        guard session.status == .completed,
              let weekIndex = session.sourceProgramWeekIndex,
              let dayIndex = session.sourceProgramDayIndex,
              let week = program.orderedWeeks.first(where: { $0.index == weekIndex }),
              let day = week.orderedDays.first(where: { $0.index == dayIndex }) else {
            return ProgressionDecision(
                sessionID: session.id,
                assignmentID: session.programAssignmentId,
                programID: session.sourceProgramId,
                weekIndex: session.sourceProgramWeekIndex,
                dayIndex: session.sourceProgramDayIndex,
                action: .hold,
                reason: .insufficientData,
                adjustments: []
            )
        }

        return evaluate(session: session, programDay: day, weekIndex: weekIndex)
    }

    static func evaluate(
        session: WorkoutSession,
        programDay: ProgramDay,
        weekIndex: Int
    ) -> ProgressionDecision {
        let prescriptions = programDay.orderedPrescriptions

        guard !prescriptions.isEmpty else {
            return ProgressionDecision(
                sessionID: session.id,
                assignmentID: session.programAssignmentId,
                programID: session.sourceProgramId,
                weekIndex: weekIndex,
                dayIndex: programDay.index,
                action: .hold,
                reason: .noRuleConfigured,
                adjustments: []
            )
        }

        let sortedExercises = session.exercises.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let adjustments = prescriptions.map { prescription in
            adjustment(
                for: prescription,
                sessionExercises: sortedExercises,
                weekIndex: weekIndex
            )
        }

        let hasDeload = adjustments.contains(where: { $0.action == .deload })
        let hasRepeat = adjustments.contains(where: \.suggestsRepeatWeek)
        let hasIncrease = adjustments.contains(where: { $0.action == .increaseLoad || $0.action == .increaseReps })
        let hasAdvance = adjustments.contains(where: { $0.action == .advance })
        let hasInvalid = adjustments.contains(where: { $0.reason == .invalidRuleConfiguration })
        let hasInsufficient = adjustments.contains(where: { $0.reason == .insufficientData || $0.reason == .unitMismatch })
        let hasFailure = adjustments.contains(where: { $0.reason == .failedTarget })

        let overallAction: ProgressionDecision.Action
        let overallReason: ProgressionDecision.Reason

        if hasDeload {
            overallAction = .deload
            overallReason = .scheduledDeload
        } else if hasRepeat {
            overallAction = .repeatWeek
            overallReason = .failureThresholdReached
        } else if hasIncrease {
            overallAction = .increase
            overallReason = .prescriptionsProgressed
        } else if hasAdvance && !hasFailure && !hasInsufficient && !hasInvalid {
            overallAction = .advance
            overallReason = .prescriptionsProgressed
        } else if hasInvalid {
            overallAction = .hold
            overallReason = .invalidRuleConfiguration
        } else if hasInsufficient {
            overallAction = .hold
            overallReason = .insufficientData
        } else if hasFailure {
            overallAction = .hold
            overallReason = .targetNotMet
        } else {
            overallAction = .hold
            overallReason = .noRuleConfigured
        }

        return ProgressionDecision(
            sessionID: session.id,
            assignmentID: session.programAssignmentId,
            programID: session.sourceProgramId,
            weekIndex: weekIndex,
            dayIndex: programDay.index,
            action: overallAction,
            reason: overallReason,
            adjustments: adjustments
        )
    }

    private static func adjustment(
        for prescription: ProgramPrescription,
        sessionExercises: [WorkoutSessionExercise],
        weekIndex: Int
    ) -> ProgramPrescriptionAdjustment {
        let matchedExercise = matchingExercise(for: prescription, in: sessionExercises)

        guard let matchedExercise else {
            return holdAdjustment(
                for: prescription,
                reason: .insufficientData,
                suggestsRepeatWeek: false
            )
        }

        let orderedSets = matchedExercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let completedSets = orderedSets.filter(\.completed)
        let expectedSets = max(prescription.targetSets ?? orderedSets.count, 1)

        if prescription.progressionRules.isEmpty {
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? matchedExercise.exerciseNameSnapshot,
                action: .advance,
                reason: .noRuleConfigured,
                nextTargetReps: prescription.targetReps,
                nextTargetWeight: prescription.targetWeight,
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: prescription.targetDistance,
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        if prescription.progressionRules.contains(where: { !$0.isValid }) {
            return holdAdjustment(
                for: prescription,
                reason: .invalidRuleConfiguration,
                exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot,
                suggestsRepeatWeek: false
            )
        }

        if hasWeightUnitMismatch(prescription: prescription, completedSets: completedSets) {
            return holdAdjustment(
                for: prescription,
                reason: .unitMismatch,
                exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot,
                suggestsRepeatWeek: false
            )
        }

        if let deloadRule = prescription.progressionRules.first(where: {
            if case .deloadEvery = $0 { return true }
            return false
        }), shouldDeload(deloadRule, weekIndex: weekIndex) {
            let deloadPercent = deloadPercent(for: deloadRule)
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? matchedExercise.exerciseNameSnapshot,
                action: .deload,
                reason: .scheduledDeload,
                nextTargetReps: prescription.targetReps,
                nextTargetWeight: scaledWeight(prescription.targetWeight, percent: 1 - deloadPercent),
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: scaledDistance(prescription.targetDistance, percent: 1 - deloadPercent),
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        let evaluation = evaluateCompletion(
            prescription: prescription,
            completedSets: completedSets,
            expectedSets: expectedSets
        )

        if let repeatRule = prescription.progressionRules.first(where: {
            if case .repeatWeekOnFailureThreshold = $0 { return true }
            return false
        }) {
            let threshold = failureThreshold(for: repeatRule)
            if evaluation.failedSetCount >= threshold {
                return holdAdjustment(
                    for: prescription,
                    reason: .failureThresholdReached,
                    exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot,
                    suggestsRepeatWeek: true
                )
            }
        }

        if let doubleRule = prescription.progressionRules.first(where: {
            if case .doubleProgression = $0 { return true }
            return false
        }) {
            return adjustmentForDoubleProgression(
                prescription: prescription,
                rule: doubleRule,
                evaluation: evaluation,
                exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot
            )
        }

        if let fixedRule = prescription.progressionRules.first(where: {
            if case .fixedLoadIncrease = $0 { return true }
            return false
        }) {
            return adjustmentForFixedIncrease(
                prescription: prescription,
                rule: fixedRule,
                evaluation: evaluation,
                exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot
            )
        }

        if evaluation.success {
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? matchedExercise.exerciseNameSnapshot,
                action: .advance,
                reason: .metTarget,
                nextTargetReps: prescription.targetReps,
                nextTargetWeight: prescription.targetWeight,
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: prescription.targetDistance,
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        return holdAdjustment(
            for: prescription,
            reason: evaluation.failedSetCount > 0 ? .failedTarget : .insufficientData,
            exerciseNameSnapshot: matchedExercise.exerciseNameSnapshot,
            suggestsRepeatWeek: false
        )
    }

    private static func adjustmentForFixedIncrease(
        prescription: ProgramPrescription,
        rule: ProgressionRule,
        evaluation: CompletionEvaluation,
        exerciseNameSnapshot: String
    ) -> ProgramPrescriptionAdjustment {
        guard evaluation.success else {
            return holdAdjustment(
                for: prescription,
                reason: evaluation.failedSetCount > 0 ? .failedTarget : .insufficientData,
                exerciseNameSnapshot: exerciseNameSnapshot,
                suggestsRepeatWeek: false
            )
        }

        guard case .fixedLoadIncrease(let step) = rule,
              let targetWeight = prescription.targetWeight else {
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? exerciseNameSnapshot,
                action: .advance,
                reason: .metTarget,
                nextTargetReps: prescription.targetReps,
                nextTargetWeight: prescription.targetWeight,
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: prescription.targetDistance,
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        return ProgramPrescriptionAdjustment(
            prescriptionID: prescription.id,
            exerciseID: prescription.exerciseId,
            exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? exerciseNameSnapshot,
            action: .increaseLoad,
            reason: .metTarget,
            nextTargetReps: prescription.targetReps,
            nextTargetWeight: targetWeight + step,
            nextTargetWeightUnit: prescription.weightUnit,
            nextTargetDurationSeconds: prescription.targetDurationSeconds,
            nextTargetDistance: prescription.targetDistance,
            nextTargetDistanceUnit: prescription.distanceUnit,
            nextTargetRPE: prescription.targetRPE,
            suggestsRepeatWeek: false
        )
    }

    private static func adjustmentForDoubleProgression(
        prescription: ProgramPrescription,
        rule: ProgressionRule,
        evaluation: CompletionEvaluation,
        exerciseNameSnapshot: String
    ) -> ProgramPrescriptionAdjustment {
        guard case .doubleProgression(let minReps, let maxReps, let loadStep) = rule else {
            return holdAdjustment(
                for: prescription,
                reason: .invalidRuleConfiguration,
                exerciseNameSnapshot: exerciseNameSnapshot,
                suggestsRepeatWeek: false
            )
        }

        guard evaluation.success, let minAchievedReps = evaluation.minimumCompletedReps else {
            return holdAdjustment(
                for: prescription,
                reason: evaluation.failedSetCount > 0 ? .failedTarget : .insufficientData,
                exerciseNameSnapshot: exerciseNameSnapshot,
                suggestsRepeatWeek: false
            )
        }

        let currentTargetReps = prescription.targetReps ?? minReps

        if minAchievedReps >= maxReps, let targetWeight = prescription.targetWeight {
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? exerciseNameSnapshot,
                action: .increaseLoad,
                reason: .metTarget,
                nextTargetReps: minReps,
                nextTargetWeight: targetWeight + loadStep,
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: prescription.targetDistance,
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        if minAchievedReps >= currentTargetReps, currentTargetReps < maxReps {
            return ProgramPrescriptionAdjustment(
                prescriptionID: prescription.id,
                exerciseID: prescription.exerciseId,
                exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? exerciseNameSnapshot,
                action: .increaseReps,
                reason: .repRangeProgression,
                nextTargetReps: min(currentTargetReps + 1, maxReps),
                nextTargetWeight: prescription.targetWeight,
                nextTargetWeightUnit: prescription.weightUnit,
                nextTargetDurationSeconds: prescription.targetDurationSeconds,
                nextTargetDistance: prescription.targetDistance,
                nextTargetDistanceUnit: prescription.distanceUnit,
                nextTargetRPE: prescription.targetRPE,
                suggestsRepeatWeek: false
            )
        }

        return holdAdjustment(
            for: prescription,
            reason: .failedTarget,
            exerciseNameSnapshot: exerciseNameSnapshot,
            suggestsRepeatWeek: false
        )
    }

    private static func matchingExercise(
        for prescription: ProgramPrescription,
        in sessionExercises: [WorkoutSessionExercise]
    ) -> WorkoutSessionExercise? {
        if let direct = sessionExercises.first(where: { $0.sourceProgramPrescriptionId == prescription.id }) {
            return direct
        }

        if let exerciseID = prescription.exerciseId,
           let byExerciseID = sessionExercises.first(where: { $0.exerciseId == exerciseID }) {
            return byExerciseID
        }

        if let snapshot = prescription.exerciseNameSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let byName = sessionExercises.first(where: {
               $0.exerciseNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == snapshot
           }) {
            return byName
        }

        return nil
    }

    private static func hasWeightUnitMismatch(
        prescription: ProgramPrescription,
        completedSets: [WorkoutSetLog]
    ) -> Bool {
        guard let targetUnit = prescription.weightUnit,
              prescription.targetWeight != nil else {
            return false
        }

        return completedSets.contains { ($0.weight != nil) && $0.weightUnit != targetUnit }
    }

    private static func scaledWeight(_ value: Double?, percent: Double) -> Double? {
        guard let value else { return nil }
        return max(0, value * percent)
    }

    private static func scaledDistance(_ value: Double?, percent: Double) -> Double? {
        guard let value else { return nil }
        return max(0, value * percent)
    }

    private static func shouldDeload(_ rule: ProgressionRule, weekIndex: Int) -> Bool {
        guard case .deloadEvery(let weeks, _) = rule, weeks > 0 else { return false }
        return weekIndex > 0 && weekIndex % weeks == 0
    }

    private static func deloadPercent(for rule: ProgressionRule) -> Double {
        guard case .deloadEvery(_, let percent) = rule else { return 0 }
        return percent
    }

    private static func failureThreshold(for rule: ProgressionRule) -> Int {
        guard case .repeatWeekOnFailureThreshold(let failedSets) = rule else { return .max }
        return failedSets
    }

    private struct CompletionEvaluation {
        let success: Bool
        let failedSetCount: Int
        let minimumCompletedReps: Int?
    }

    private static func evaluateCompletion(
        prescription: ProgramPrescription,
        completedSets: [WorkoutSetLog],
        expectedSets: Int
    ) -> CompletionEvaluation {
        guard !completedSets.isEmpty else {
            return CompletionEvaluation(success: false, failedSetCount: expectedSets, minimumCompletedReps: nil)
        }

        var failedSets = max(expectedSets - completedSets.count, 0)
        var minimumCompletedReps: Int? = nil

        for set in completedSets.prefix(expectedSets) {
            if let reps = set.reps {
                minimumCompletedReps = min(minimumCompletedReps ?? reps, reps)
            }

            if !setMeetsPrescription(set: set, prescription: prescription) {
                failedSets += 1
            }
        }

        let success = failedSets == 0 && completedSets.count >= expectedSets
        return CompletionEvaluation(success: success, failedSetCount: failedSets, minimumCompletedReps: minimumCompletedReps)
    }

    private static func setMeetsPrescription(
        set: WorkoutSetLog,
        prescription: ProgramPrescription
    ) -> Bool {
        if let targetReps = prescription.targetReps,
           (set.reps ?? 0) < targetReps {
            return false
        }

        if let targetWeight = prescription.targetWeight,
           (set.weight ?? 0) < targetWeight {
            return false
        }

        if let targetDurationSeconds = prescription.targetDurationSeconds,
           (set.actualDurationSeconds ?? 0) < targetDurationSeconds {
            return false
        }

        if let targetDistance = prescription.targetDistance,
           (set.actualDistance ?? 0) < targetDistance {
            return false
        }

        if let targetRPE = prescription.targetRPE,
           let actualRPE = set.rpe,
           actualRPE > targetRPE {
            return false
        }

        return true
    }

    private static func holdAdjustment(
        for prescription: ProgramPrescription,
        reason: ProgramPrescriptionAdjustment.Reason,
        exerciseNameSnapshot: String? = nil,
        suggestsRepeatWeek: Bool
    ) -> ProgramPrescriptionAdjustment {
        ProgramPrescriptionAdjustment(
            prescriptionID: prescription.id,
            exerciseID: prescription.exerciseId,
            exerciseNameSnapshot: prescription.exerciseNameSnapshot ?? exerciseNameSnapshot,
            action: .hold,
            reason: reason,
            nextTargetReps: prescription.targetReps,
            nextTargetWeight: prescription.targetWeight,
            nextTargetWeightUnit: prescription.weightUnit,
            nextTargetDurationSeconds: prescription.targetDurationSeconds,
            nextTargetDistance: prescription.targetDistance,
            nextTargetDistanceUnit: prescription.distanceUnit,
            nextTargetRPE: prescription.targetRPE,
            suggestsRepeatWeek: suggestsRepeatWeek
        )
    }
}
