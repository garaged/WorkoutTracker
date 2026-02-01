import Foundation

// File: workouttracker/Support/UIAccessibilityIdentifiers.swift
//
// Why this exists:
// - UI tests become dramatically more stable when they can target explicit identifiers.
// - Keeping them centralized prevents drift and makes refactors safer.
//
// Style:
// - dot-separated, feature-first: "activityEditor.saveButton"
enum UIAccessibilityIdentifiers {

    enum Timeline {
        static let newActivityButton = "timeline.newActivityButton"
    }

    enum ActivityEditor {
        static let titleField = "activityEditor.titleField"
        static let saveButton = "activityEditor.saveButton"
        static let cancelButton = "activityEditor.cancelButton"
        static let typePicker = "activityEditor.typePicker"
        static let routinePicker = "activityEditor.routinePicker"
    }

    enum Settings {
        static let verboseLoggingToggle = "settings.verboseLoggingToggle"
    }
}
