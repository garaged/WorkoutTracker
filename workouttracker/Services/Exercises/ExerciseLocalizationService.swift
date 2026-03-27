import Foundation
import SwiftData

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

    static func displayName(
        exerciseID: UUID?,
        fallbackName: String,
        exercisesByID: [UUID: Exercise],
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let exerciseID, let exercise = exercisesByID[exerciseID] else {
            return fallbackName
        }
        return displayName(for: exercise, locale: locale)
    }

    static func searchTokens(for exercise: Exercise, locale: Locale = .autoupdatingCurrent) -> [String] {
        searchTokens(catalogKey: exercise.catalogKey, storedName: exercise.name, locale: locale)
    }

    static func searchTokens(catalogKey: String?, storedName: String, locale: Locale = .autoupdatingCurrent) -> [String] {
        let display = displayName(catalogKey: catalogKey, storedName: storedName, locale: locale)
        let fallback = normalizedCatalogKey(catalogKey).flatMap { defaultCatalogName(for: $0) }
        return dedupedTokens([display, fallback, storedName])
    }

    static func searchTokens(
        exerciseID: UUID?,
        fallbackName: String,
        exercisesByID: [UUID: Exercise],
        locale: Locale = .autoupdatingCurrent
    ) -> [String] {
        let liveTokens: [String]
        if let exerciseID, let exercise = exercisesByID[exerciseID] {
            liveTokens = searchTokens(for: exercise, locale: locale)
        } else {
            liveTokens = []
        }
        return dedupedTokens(liveTokens + [fallbackName])
    }

    static func matchesSearch(_ exercise: Exercise, query: String, locale: Locale = .autoupdatingCurrent) -> Bool {
        matches(tokens: searchTokens(for: exercise, locale: locale), query: query, locale: locale)
    }

    static func matchesSearch(
        exerciseID: UUID?,
        fallbackName: String,
        query: String,
        exercisesByID: [UUID: Exercise],
        locale: Locale = .autoupdatingCurrent
    ) -> Bool {
        matches(
            tokens: searchTokens(exerciseID: exerciseID, fallbackName: fallbackName, exercisesByID: exercisesByID, locale: locale),
            query: query,
            locale: locale
        )
    }

    static func sortDisplayName(for exercise: Exercise, locale: Locale = .autoupdatingCurrent) -> String {
        displayName(for: exercise, locale: locale)
    }

    static func indexByID(_ exercises: [Exercise]) -> [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    static func loadExercisesByID(context: ModelContext) -> [UUID: Exercise] {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return indexByID(exercises)
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

    private static func dedupedTokens(_ candidates: [String?]) -> [String] {
        var tokens: [String] = []
        for candidate in candidates {
            guard let candidate else { continue }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !tokens.contains(trimmed) else { continue }
            tokens.append(trimmed)
        }
        return tokens
    }

    private static func matches(tokens: [String], query: String, locale: Locale) -> Bool {
        let normalizedQuery = normalizedSearchText(query, locale: locale)
        guard !normalizedQuery.isEmpty else { return true }

        return tokens.contains { token in
            normalizedSearchText(token, locale: locale).contains(normalizedQuery)
        }
    }
}
