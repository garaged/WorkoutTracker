import Foundation
import SwiftData

@MainActor
final class TemplateUpdateApplier {
    func apply(plan: TemplateUpdatePlan, context: ModelContext) throws {
        do {
            // 1) Mutate existing activities (deterministic order already in plan)
            for u in plan.updates {
                guard let a = try fetchActivity(id: u.activityId, context: context) else {
                    throw TemplateUpdateError.missingActivity(u.activityId)
                }
                apply(snapshot: u.after, to: a)
            }

            // 2) Create missing apply-day activity(ies)
            for c in plan.creates {
                // IMPORTANT: bind to locals so #Predicate doesn’t try to infer against PlannedActivityCreate
                let gk: String? = c.generatedKey

                let existing = try context.fetch(FetchDescriptor<Activity>(
                    predicate: #Predicate<Activity> { $0.generatedKey == gk }
                ))
                if !existing.isEmpty { continue }

                let a = Activity(
                    title: c.title,
                    startAt: c.startAt,
                    endAt: c.endAt,
                    laneHint: 0,
                    kind: c.kind,
                    workoutRoutineId: (c.kind == .workout ? c.workoutRoutineId : nil)
                )

                a.templateId = c.templateId
                a.dayKey = c.dayKey
                a.generatedKey = c.generatedKey

                a.plannedTitle = c.plannedTitle
                a.plannedStartAt = c.plannedStartAt
                a.plannedEndAt = c.plannedEndAt
                a.status = .planned

                // Invariants: if not workout, clear routine
                if a.kind != .workout {
                    a.workoutRoutineId = nil
                }

                context.insert(a)
            }

            // 3) Delete overrides last (so rollback never needs to recreate them)
            for key in plan.overrideKeysToDelete {
                let k = key
                let ovs = try context.fetch(FetchDescriptor<TemplateInstanceOverride>(
                    predicate: #Predicate<TemplateInstanceOverride> { $0.key == k }
                ))
                for ov in ovs { context.delete(ov) }
            }
        } catch {
            rollback(plan: plan, context: context)
            throw error
        }
    }

    func rollback(plan: TemplateUpdatePlan, context: ModelContext) {
        // Restore existing rows
        for (id, snap) in plan.beforeSnapshots {
            if let a = try? fetchActivity(id: id, context: context) {
                apply(snapshot: snap, to: a)
            }
        }

        // Delete any newly created rows (by generatedKey)
        for gk in plan.createdGeneratedKeys {
            let key: String? = gk
            if let created = try? context.fetch(FetchDescriptor<Activity>(
                predicate: #Predicate<Activity> { $0.generatedKey == key }
            )) {
                for a in created { context.delete(a) }
            }
        }
    }

    // MARK: - Helpers

    private func fetchActivity(id: UUID, context: ModelContext) throws -> Activity? {
        let wanted = id
        let fd = FetchDescriptor<Activity>(predicate: #Predicate<Activity> { $0.id == wanted })
        return try context.fetch(fd).first
    }

    private func apply(snapshot s: ActivitySnapshot, to a: Activity) {
        a.title = s.title
        a.startAt = s.startAt
        a.endAt = s.endAt

        a.templateId = s.templateId
        a.dayKey = s.dayKey
        a.generatedKey = s.generatedKey

        a.plannedTitle = s.plannedTitle
        a.plannedStartAt = s.plannedStartAt
        a.plannedEndAt = s.plannedEndAt

        // Keep status/session history as-is (snapshot includes status for completeness)
        a.status = s.status

        a.kind = s.kind
        a.workoutRoutineId = (s.kind == .workout ? s.workoutRoutineId : nil)

        // Invariants: if not workout, clear routine
        if a.kind != .workout {
            a.workoutRoutineId = nil
        }
    }
}
