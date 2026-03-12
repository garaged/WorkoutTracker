import Foundation
import UserNotifications

@MainActor
final class RestTimerNotificationScheduler {

    static let shared = RestTimerNotificationScheduler()

    private enum Constants {
        static let requestIdentifier = "rest-timer.active"
        static let customSoundName = "rest_end_emphatic_bell.wav"
    }

    private let center = UNUserNotificationCenter.current()
    private var latestScheduleToken = UUID()

    private init() {}

    /// Schedules a single local notification for the active rest timer.
    ///
    /// Why this lives in `Services/RestTimer`:
    /// - It belongs to the rest-timer lifecycle, not to any one screen.
    /// - Keeping notification wiring here makes start / extend / cancel behavior deterministic.
    func scheduleRestFinished(after seconds: TimeInterval, soundEnabled: Bool) {
        let clamped = max(1, Int(seconds.rounded(.up)))
        let token = UUID()
        latestScheduleToken = token

        let center = self.center

        Task { @MainActor in
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                await addRequest(after: clamped, soundEnabled: soundEnabled, token: token)

            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                guard granted else { return }
                await addRequest(after: clamped, soundEnabled: soundEnabled, token: token)

            case .denied:
                break

            @unknown default:
                break
            }
        }
    }

    func cancelActiveRestNotification() {
        latestScheduleToken = UUID()
        center.removePendingNotificationRequests(withIdentifiers: [Constants.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Constants.requestIdentifier])
    }

    private func addRequest(after seconds: Int, soundEnabled: Bool, token: UUID) async {
        guard latestScheduleToken == token else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest finished"
        content.body = "Time for your next set."
        if soundEnabled {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(Constants.customSoundName))
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: Constants.requestIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [Constants.requestIdentifier])
        try? await center.add(request)
    }
}
