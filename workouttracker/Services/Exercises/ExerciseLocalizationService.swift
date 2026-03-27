import Foundation

// File: workouttracker/Services/Exercises/ExerciseLocalizationService.swift
//
// Why this file lives here:
// Built-in exercise name resolution and localized search are shared app behavior.
// Keeping it in Services lets browse/detail surfaces reuse one identity-aware rule set.

enum ExerciseLocalizationService {
    static func displayName(for exercise: Exercise, locale: Locale = .autoupdatingCurrent) -> String {
        displayName(catalogKey: exercise.catalogKey, storedName: exercise.name, locale: locale)
    }

    static func displayName(catalogKey: String?, storedName: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard let catalogKey = normalizedCatalogKey(catalogKey) else {
            return storedName
        }

        let localizationKey = AppFormatting.exerciseCatalogNameKey(for: catalogKey)
        let localized = AppFormatting.localized(localizationKey, locale: locale)
        if localized != localizationKey {
            return localized
        }

        return defaultCatalogName(for: catalogKey) ?? storedName
    }

    static func searchTokens(for exercise: Exercise, locale: Locale = .autoupdatingCurrent) -> [String] {
        searchTokens(catalogKey: exercise.catalogKey, storedName: exercise.name, locale: locale)
    }

    static func searchTokens(catalogKey: String?, storedName: String, locale: Locale = .autoupdatingCurrent) -> [String] {
        let display = displayName(catalogKey: catalogKey, storedName: storedName, locale: locale)
        let fallback = normalizedCatalogKey(catalogKey).flatMap { defaultCatalogName(for: $0) }

        var tokens: [String] = []
        for token in [display, fallback, storedName] {
            guard let token else { continue }
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !tokens.contains(trimmed) else { continue }
            tokens.append(trimmed)
        }

        return tokens
    }

    static func matchesSearch(_ exercise: Exercise, query: String, locale: Locale = .autoupdatingCurrent) -> Bool {
        let normalizedQuery = normalizedSearchText(query, locale: locale)
        guard !normalizedQuery.isEmpty else { return true }

        return searchTokens(for: exercise, locale: locale).contains { token in
            normalizedSearchText(token, locale: locale).contains(normalizedQuery)
        }
    }

    static func sortDisplayName(for exercise: Exercise, locale: Locale = .autoupdatingCurrent) -> String {
        displayName(for: exercise, locale: locale)
    }

    private static let catalog: SeedCatalog? = {
        try? SeedCatalog.loadFromBundle()
    }()

    private static func defaultCatalogName(for catalogKey: String) -> String? {
        catalog?.exercise(forKey: catalogKey)?.name
    }

    private static func normalizedCatalogKey(_ key: String?) -> String? {
        guard let key else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedSearchText(_ value: String, locale: Locale) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }
}
