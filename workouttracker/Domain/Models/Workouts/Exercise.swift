// File: Domain/Models/Workouts/Exercise.swift
import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var modalityRaw: String

    var instructions: String?
    var notes: String?

    // ✅ Media for the exercise header (image/GIF/video reference)
    var mediaKindRaw: String
    var mediaAssetName: String?
    var mediaURLString: String?

    // ... (your existing muscles/equipment storage here)

    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        modality: ExerciseModality = .strength,
        instructions: String? = nil,
        notes: String? = nil,
        mediaKind: ExerciseMediaKind = .none,
        mediaAssetName: String? = nil,
        mediaURLString: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.modalityRaw = modality.rawValue
        self.instructions = instructions
        self.notes = notes

        self.mediaKindRaw = mediaKind.rawValue
        self.mediaAssetName = mediaAssetName
        self.mediaURLString = mediaURLString

        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var modality: ExerciseModality {
        get { ExerciseModality(rawValue: modalityRaw) ?? .strength }
        set { modalityRaw = newValue.rawValue }
    }

    var mediaKind: ExerciseMediaKind {
        get { ExerciseMediaKind(rawValue: mediaKindRaw) ?? .none }
        set { mediaKindRaw = newValue.rawValue }
    }
}
