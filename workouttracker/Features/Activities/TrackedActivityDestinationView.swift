import SwiftUI
import SwiftData

struct TrackedActivityDestinationView: View {
    let sessionID: UUID

    @Query private var sessions: [TrackedActivitySession]

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _sessions = Query(
            filter: #Predicate<TrackedActivitySession> { session in
                session.id == sessionID
            }
        )
    }

    var body: some View {
        if let session = sessions.first, session.quickStartTimingBlob != nil {
            QuickStartSessionScreen(sessionID: sessionID)
        } else {
            TrackedActivitySessionScreen(sessionID: sessionID)
        }
    }
}
