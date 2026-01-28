import XCTest
@testable import workouttracker

final class CoachSuggestionServiceTests: XCTestCase {
    
    private var svc: CoachSuggestionService!
    
    override func setUp() {
        super.setUp()
        svc = CoachSuggestionService()
    }
    
    // MARK: - Rest suggestion
    
    func test_suggestRest_usesPlannedRestAsBaseline_whenNoRPE() {
        let rest = svc.suggestRestSeconds(rpe: nil, plannedRestSeconds: 120, defaultRestSeconds: 90)
        XCTAssertEqual(rest, 120)
    }
    
    func test_suggestRest_lowRPE_shortensSlightly() {
        // base 120 -> 0.9 * 120 = 108 (min 45)
        let rest = svc.suggestRestSeconds(rpe: 6.0, plannedRestSeconds: 120, defaultRestSeconds: 90)
        XCTAssertEqual(rest, 108)
    }
    
    func test_suggestRest_midRPE_usesBaseline() {
        let rest = svc.suggestRestSeconds(rpe: 7.3, plannedRestSeconds: 120, defaultRestSeconds: 90)
        XCTAssertEqual(rest, 120)
    }
    
    func test_suggestRest_highRPE_increasesToAtLeast150() {
        // rpe 9.0 -> at least 150
        let rest = svc.suggestRestSeconds(rpe: 9.0, plannedRestSeconds: 90, defaultRestSeconds: 90)
        XCTAssertEqual(rest, 150)
    }
    
    func test_suggestRest_veryHighRPE_increasesToAtLeast180() {
        // rpe 9.6 -> at least 180
        let rest = svc.suggestRestSeconds(rpe: 9.6, plannedRestSeconds: 120, defaultRestSeconds: 90)
        XCTAssertEqual(rest, 180)
    }
    
    // MARK: - Prompt nudges
    
    func test_makePrompt_lowRPE_withWeight_suggestsWeightIncrease_kg() {
        let p = svc.makePrompt(
            completedWeight: 100,
            completedReps: 5,
            weightUnitRaw: "kg",
            rpe: 7.0,
            plannedRestSeconds: 120,
            defaultRestSeconds: 90
        )
        
        XCTAssertEqual(p.weightDelta, 2.5)
        XCTAssertNil(p.repsDelta)
        XCTAssertEqual(p.weightLabel, "+2.5 kg")
        XCTAssertEqual(p.suggestedRestSeconds, 120) // baseline for 7.0
    }
    
    func test_makePrompt_lowRPE_withWeight_suggestsWeightIncrease_lb() {
        let p = svc.makePrompt(
            completedWeight: 225,
            completedReps: 5,
            weightUnitRaw: "lb",
            rpe: 7.0,
            plannedRestSeconds: 120,
            defaultRestSeconds: 90
        )
        
        XCTAssertEqual(p.weightDelta, 5.0)
        XCTAssertNil(p.repsDelta)
        XCTAssertEqual(p.weightLabel, "+5 lb")
    }
    
    func test_makePrompt_midRPE_prefersReps_whenRepsPresent() {
        let p = svc.makePrompt(
            completedWeight: 80,
            completedReps: 8,
            weightUnitRaw: "kg",
            rpe: 8.2,
            plannedRestSeconds: 90,
            defaultRestSeconds: 90
        )
        
        XCTAssertNil(p.weightDelta)
        XCTAssertEqual(p.repsDelta, 1)
        XCTAssertEqual(p.repsLabel, "+1 rep")
        XCTAssertEqual(p.suggestedRestSeconds, 120) // rpe <= 8.5 => at least 120
    }
    
    func test_makePrompt_highRPE_hasNoPushSuggestion() {
        let p = svc.makePrompt(
            completedWeight: 100,
            completedReps: 3,
            weightUnitRaw: "kg",
            rpe: 9.1,
            plannedRestSeconds: 90,
            defaultRestSeconds: 90
        )
        
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
        XCTAssertEqual(p.suggestedRestSeconds, 150) // 9.1 => at least 150
    }
    
    func test_makePrompt_noRPE_prefersReps_ifPresent() {
        let p = svc.makePrompt(
            completedWeight: 0,
            completedReps: 10,
            weightUnitRaw: "kg",
            rpe: nil,
            plannedRestSeconds: 90,
            defaultRestSeconds: 90
        )
        
        XCTAssertNil(p.weightDelta)
        XCTAssertEqual(p.repsDelta, 1)
        XCTAssertEqual(p.repsLabel, "+1 rep")
        XCTAssertEqual(p.suggestedRestSeconds, 90)
    }
    
    // MARK: - PR detection
    
    func test_prAchievements_isStrictlyGreater_notEqual() {
        // If the completed set matches a prior set exactly, there should be NO PRs.
        let previous = [
            cs(weight: 100, reps: 8, unit: "kg"),
            cs(weight: 90, reps: 10, unit: "kg"),
        ]

        let completed = cs(weight: 100, reps: 8, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)

        XCTAssertTrue(ach.isEmpty)
    }
    
    func test_prAchievements_detectsBestWeight() {
        let previous = [
            cs(weight: 100, reps: 5, unit: "kg"),
            cs(weight: 90, reps: 8, unit: "kg"),
        ]
        
        let completed = cs(weight: 102.5, reps: 3, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)
        
        XCTAssertTrue(kinds(ach).contains(.bestWeight))
    }
    
    func test_prAchievements_detectsBestReps() {
        let previous = [
            cs(weight: 60, reps: 10, unit: "kg"),
            cs(weight: 80, reps: 8, unit: "kg"),
        ]
        
        let completed = cs(weight: 40, reps: 12, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)
        
        XCTAssertTrue(kinds(ach).contains(.bestReps))
    }
    
    func test_prAchievements_detectsBestVolume() {
        // prev best volume: 100*5=500
        let previous = [
            cs(weight: 100, reps: 5, unit: "kg"),
            cs(weight: 80, reps: 6, unit: "kg"),  // 480
        ]
        
        // completed volume: 90*6=540
        let completed = cs(weight: 90, reps: 6, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)
        
        XCTAssertTrue(kinds(ach).contains(.bestVolume))
    }
    
    func test_prAchievements_detectsBestE1RM() {
        // Epley: w * (1 + reps/30)
        // prev max: 100*(1+5/30)=116.666...
        let previous = [
            cs(weight: 100, reps: 5, unit: "kg"),
            cs(weight: 90, reps: 8, unit: "kg"),   // 114.0
        ]
        
        // completed: 102.5*(1+5/30)=119.583...
        let completed = cs(weight: 102.5, reps: 5, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)
        
        XCTAssertTrue(kinds(ach).contains(.bestE1RM))
    }
    
    func test_prAchievements_canReturnMultiplePRs() {
        // prev max weight 100, max reps 8, max volume 500, max e1rm 116.666
        let previous = [
            cs(weight: 100, reps: 5, unit: "kg"),
            cs(weight: 80, reps: 8, unit: "kg"),
        ]
        
        // 105kg x 9 reps blows up weight, reps, volume, e1rm
        let completed = cs(weight: 105, reps: 9, unit: "kg")
        let ach = svc.prAchievements(completed: completed, previous: previous)
        
        let ks = kinds(ach)
        XCTAssertTrue(ks.contains(.bestWeight))
        XCTAssertTrue(ks.contains(.bestReps))
        XCTAssertTrue(ks.contains(.bestVolume))
        XCTAssertTrue(ks.contains(.bestE1RM))
    }
    
    // MARK: - Helpers
    
    private func cs(weight: Double?, reps: Int?, unit: String) -> CoachSuggestionService.CompletedSet {
        .init(weight: weight, reps: reps, weightUnitRaw: unit, rpe: nil)
    }
    
    private func kinds(_ a: [CoachSuggestionService.PRAchievement]) -> Set<CoachSuggestionService.PRKind> {
        Set(a.map(\.kind))
    }
}
