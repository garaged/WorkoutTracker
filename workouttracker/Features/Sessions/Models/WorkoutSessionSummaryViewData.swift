import Foundation

struct WorkoutSessionSummaryViewData: Hashable {
    struct SegmentRow: Identifiable, Hashable {
        let id: String
        let title: String
        let valueText: String
        let statusText: String?
    }

    struct PRItem: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
    }

    let titleText: String
    let dateText: String
    let overallStatusText: String
    let completedSetsText: String
    let skippedSetsText: String
    let elapsedText: String
    let endedText: String?
    let prSummaryText: String
    let prItems: [PRItem]
    let segmentRows: [SegmentRow]
    let honestyFootnoteText: String?
}
