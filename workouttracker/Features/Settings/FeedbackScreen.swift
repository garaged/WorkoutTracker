import SwiftUI
import UIKit

/// A simple “Diagnostics / Feedback” screen that lets you export logs (and optionally a backup)
/// when something feels off in real world usage.
///
/// Why this exists:
/// - Real bugs need context. Logs + a backup snapshot let you reproduce and fix issues fast.
/// - Export is one tap so it actually gets used.
struct FeedbackScreen: View {
    @Environment(\.backupExporter) private var backupExporter

    @State private var shareItems: [Any] = []
    @State private var showShare: Bool = false

    @State private var toast: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            Section {
                Text("If something looks wrong, export logs (and a backup if available) and attach them when reporting the issue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Export") {
                Button {
                    share(url: AppLogger.shared.logFileURL())
                } label: {
                    Label(AccessibilityLabels.Buttons.shareLogs, systemImage: "square.and.arrow.up")
                }
                .accessibilityHint(AccessibilityLabels.Buttons.shareLogsHint)

                Button {
                    copyDiagnosticsToClipboard()
                } label: {
                    Label(AccessibilityLabels.Buttons.copyDiagnostics, systemImage: "doc.on.doc")
                }
                .accessibilityHint(AccessibilityLabels.Buttons.copyDiagnosticsHint)

                Button {
                    exportBackup()
                } label: {
                    Label(AccessibilityLabels.Buttons.exportBackup, systemImage: "tray.and.arrow.up")
                }
                .accessibilityHint(AccessibilityLabels.Buttons.exportBackupHint)
                .disabled(backupExporter == nil)
            }

            Section("Logs") {
                Button(role: .destructive) {
                    AppLogger.shared.clearLogs()
                    toast = "Logs cleared"
                } label: {
                    Label(AccessibilityLabels.Buttons.clearLogs, systemImage: "trash")
                }
                .accessibilityHint(AccessibilityLabels.Buttons.clearLogsHint)
            }

            Section("Tips") {
                Text("Avoid logging secrets (tokens, passwords). This log file is meant to be shareable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .alert("Couldn’t export", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { self.toast = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: toast)
    }

    // MARK: - Actions

    private func exportBackup() {
        guard let exporter = backupExporter else {
            errorMessage = "No backup exporter is configured."
            return
        }

        do {
            let url = try exporter.exportBackup()
            share(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyDiagnosticsToClipboard() {
        let info = diagnosticInfoString()
        UIPasteboard.general.string = info
        toast = "Copied diagnostic info"
    }

    private func share(url: URL) {
        shareItems = [url]
        showShare = true
    }

    private func diagnosticInfoString() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let device = UIDevice.current
        let tz = TimeZone.current.identifier

        return [
            "App: Workout Tracker",
            "Version: \(version) (\(build))",
            "Device: \(device.model)",
            "iOS: \(device.systemName) \(device.systemVersion)",
            "Time Zone: \(tz)"
        ].joined(separator: "\n")
    }
}

// MARK: - UI helpers

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No-op.
    }
}

private struct ToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 10)
            .padding(.horizontal, 12)
            .accessibilityHidden(true)
    }
}
