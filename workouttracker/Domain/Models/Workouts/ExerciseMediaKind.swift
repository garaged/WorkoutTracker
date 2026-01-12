// File: Domain/Models/Workouts/ExerciseMediaKind.swift
import Foundation

enum ExerciseMediaKind: String, Codable, CaseIterable {
    case none
    case bundledAsset   // e.g. "dumbbell_bench_press.gif" in app bundle / assets
    case remoteURL      // future-proof if you ever download media
}
