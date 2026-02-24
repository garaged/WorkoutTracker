// File: workouttracker/Support/SupportLinks.swift

import Foundation

/// Central place for all support-related external destinations.
///
/// Privacy note:
/// - These are opened explicitly by the user (Safari / Mail).
/// - The app does not send anything automatically.
enum SupportLinks {

    // MARK: - config contact links

    static let gitHubRepoURL = URL(string: "https://github.com/garaged/WorkoutTracker")
    static let gitHubIssuesURL = URL(string: "https://github.com/garaged/WorkoutTracker/issues")

    static let gitHubNewIssueURL = URL(string: "https://github.com/garaged/WorkoutTracker/issues/new/choose")
    static let gitHubNewIssuePrefillBaseURL = URL(string: "https://github.com/garaged/WorkoutTracker/issues/new")

    static let supportPageURL = URL(string: "https://github.com/garaged/WorkoutTracker#support")
    static let faqURL = URL(string: "https://github.com/garaged/WorkoutTracker#faq")
    static let privacyPolicyURL = URL(string: "https://github.com/garaged/WorkoutTracker/blob/main/PRIVACY.md")

    static let supportEmailAddress = "garaged@gmail.com"

    /// ✅ Add this (fixes "Cannot find 'supportEmailSubject' in scope")
    static let supportEmailSubject = "Workout Tracker Support"

    // MARK: - Helpers

    static func mailtoURL(body: String) -> URL? {
        guard !supportEmailAddress.isEmpty else { return nil }

        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportEmailAddress
        comps.queryItems = [
            URLQueryItem(name: "subject", value: supportEmailSubject),
            URLQueryItem(name: "body", value: body)
        ]
        return comps.url
    }

    /// Builds a GitHub new-issue URL with `title` and `body` prefilled.
    /// Works best when GitHub serves the `/issues/new` page directly (no chooser redirect).
    static func gitHubNewIssuePrefilledURL(title: String, body: String) -> URL? {
        guard let base = gitHubNewIssuePrefillBaseURL,
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }

        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "title", value: title))
        items.append(URLQueryItem(name: "body", value: body))
        comps.queryItems = items

        return comps.url
    }
}
