import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FeedbackScreen: View {
    @Environment(\.openURL) private var openURL

    @State private var userNotes: String = ""
    @State private var showCopiedAlert: Bool = false

    private var supportSummary: String {
        SupportSummaryBuilder.build()
    }

    var body: some View {
        Form {
            Section {
                Text(AppFormatting.localized("Nothing is sent automatically. These options open your browser or mail app only when you tap them."))
                    .font(.footnote)
            }

            Section(AppFormatting.localized("Report a bug")) {
                Button {
                    openGitHubIssue()
                } label: {
                    Label(AppFormatting.localized("Open GitHub Issue"), systemImage: "ladybug")
                }
                .disabled(SupportLinks.gitHubNewIssueURL == nil)
            }

            Section(AppFormatting.localized("Contact")) {
                Button {
                    emailSupport()
                } label: {
                    Label(AppFormatting.localized("Email Support"), systemImage: "envelope")
                }
                .disabled(SupportLinks.mailtoURL(body: "test") == nil)

                if !SupportLinks.supportEmailAddress.isEmpty {
                    Button {
                        copyToClipboard(SupportLinks.supportEmailAddress)
                        showCopiedAlert = true
                    } label: {
                        Label(AppFormatting.localized("Copy support email"), systemImage: "doc.on.doc")
                    }
                }
            }

            Section(AppFormatting.localized("Describe what happened (optional)")) {
                TextEditor(text: $userNotes)
                    .frame(minHeight: 110)
                    .accessibilityLabel(AppFormatting.localized("Issue description"))

                Text(AppFormatting.localized("Tip: include steps to reproduce, what you expected, and what happened instead."))
                    .font(.footnote)
            }

            Section(AppFormatting.localized("Help & links")) {
                if let url = SupportLinks.supportPageURL {
                    Link(destination: url) {
                        Label(AppFormatting.localized("Support page"), systemImage: "questionmark.circle")
                    }
                }

                if let url = SupportLinks.faqURL {
                    Link(destination: url) {
                        Label(AppFormatting.localized("FAQ"), systemImage: "book")
                    }
                }

                if let url = SupportLinks.privacyPolicyURL {
                    Link(destination: url) {
                        Label(AppFormatting.localized("Privacy policy"), systemImage: "hand.raised")
                    }
                }
            }

            Section(AppFormatting.localized("Support summary")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppFormatting.localized("Copy/paste this into an issue or email. It’s generated locally on your device."))
                        .font(.footnote)

                    ScrollView(.vertical) {
                        Text(supportSummary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .frame(minHeight: 140)

                    HStack(spacing: 12) {
                        Button {
                            copyToClipboard(supportSummary)
                            showCopiedAlert = true
                        } label: {
                            Label(AppFormatting.localized("Copy"), systemImage: "doc.on.doc")
                        }

                        if #available(iOS 16.0, *) {
                            ShareLink(item: supportSummary) {
                                Label(AppFormatting.localized("Share"), systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppFormatting.localized("Support"))
        .alert(AppFormatting.localized("Copied"), isPresented: $showCopiedAlert) {
            Button(AppFormatting.localized("OK"), role: .cancel) {}
        } message: {
            Text(AppFormatting.localized("Copied to clipboard."))
        }
    }

    // MARK: - Actions

    private func openGitHubIssue() {
        let title = "Bug report"
        let body = buildOutboundBody()

        if let url = SupportLinks.gitHubNewIssuePrefilledURL(title: title, body: body) {
            openURL(url)
        } else if let url = SupportLinks.gitHubNewIssueURL {
            openURL(url)
        }
    }

    private func emailSupport() {
        let body = buildOutboundBody()
        if let url = SupportLinks.mailtoURL(body: body) {
            openURL(url)
        }
    }

    private func buildOutboundBody() -> String {
        // Human-friendly first, then diagnostics summary.
        var parts: [String] = []

        if !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(userNotes.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            parts.append("Describe the issue here (steps to reproduce, expected vs actual).")
        }

        parts.append("")
        parts.append("----")
        parts.append("Support Summary")
        parts.append("----")
        parts.append(supportSummary)

        return parts.joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private var supportSummary: String {
    SupportSummaryBuilder.build()
}

// MARK: - Support Summary Builder (local-only)

private enum SupportSummaryBuilder {
    static func build() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let locale = Locale.current.identifier
        let tz = TimeZone.current.identifier

        let osString: String = {
            #if canImport(UIKit)
            return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            #else
            return ProcessInfo.processInfo.operatingSystemVersionString
            #endif
        }()

        let deviceString: String = {
            #if canImport(UIKit)
            return UIDevice.current.model
            #else
            return "UnknownDevice"
            #endif
        }()

        var lines: [String] = []
        lines.append("\(appName) \(version) (\(build))")
        lines.append("Device: \(deviceString)")
        lines.append("OS: \(osString)")
        lines.append("Locale: \(locale)")
        lines.append("Time Zone: \(tz)")
        lines.append("Generated: \(ExportNamingFormatter.supportSummaryDateLine())")

        // If you already have a diagnostics/bug-report summary string in the app,
        // append it here (still local-only until user shares it).
        //
        // lines.append("")
        // lines.append(DiagnosticsSupportSummary.current)

        return lines.joined(separator: "\n")
    }
}
