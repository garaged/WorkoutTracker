// File: workouttracker/Support/SupportLinks.swift

import Foundation

/// Central place for all support-related external destinations.
///
/// Privacy note:
/// - These are opened explicitly by the user (Safari / Mail).
/// - The app does not send anything automatically.
enum SupportLinks {

    // MARK: - Configure these for your project

    /// Public repo (used to derive issues/FAQ/privacy URLs if you want).
    static let gitHubRepoURL = URL(string: "https://github.com/garaged/WorkoutTracker")

    /// Direct “new issue” entrypoint (optional).
    /// If you prefer issue templates/chooser, use:
    /// https://github.com/<owner>/<repo>/issues/new/choose
    static let gitHubNewIssueURL = URL(string: "https://github.com/garaged/WorkoutTracker/issues/new")

    /// A human-friendly support page (could be a GitHub Discussions page, a docs site, etc.)
    static let supportPageURL = URL(string: "https://github.com/garaged/WorkoutTracker#support")

    /// FAQ page/anchor (optional).
    static let faqURL = URL(string: "https://github.com/garaged/WorkoutTracker#faq")

    /// Privacy policy page (optional — can point at your PRIVACY.md in GitHub).
    static let privacyPolicyURL = URL(string: "https://github.com/garaged/WorkoutTracker/blob/main/PRIVACY.md")

    /// Support email (optional).
    static let supportEmailAddress = "garaged@gmail.com"
    static let supportEmailSubject = "Workout Tracker Support"

    // MARK: - Helpers

    static func mailtoURL(body: String) -> URL? {
        guard !supportEmailAddress.isEmpty else { return nil }

        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportEmailAddress

        // RFC-6068-ish handling via query items
        comps.queryItems = [
            URLQueryItem(name: "subject", value: supportEmailSubject),
            URLQueryItem(name: "body", value: body)
        ]

        return comps.url
    }

    /// Builds a GitHub new-issue URL with `title` and `body` prefilled.
    /// Works with standard GitHub query parameters: ?title=...&body=...
    static func gitHubNewIssuePrefilledURL(title: String, body: String) -> URL? {
        guard var base = gitHubNewIssueURL else { return nil }

        // If base already has query, we’ll append safely via URLComponents.
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }

        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "title", value: title))
        items.append(URLQueryItem(name: "body", value: body))
        comps.queryItems = items

        return comps.url
    }
}
