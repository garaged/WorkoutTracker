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
    
    // ✅ Minimal equipment tagging (Phase D)
    // Stored as comma-separated tags: "dumbbell,barbell,bench"
    var equipmentTagsRaw: String

    init(
        id: UUID = UUID(),
        name: String,
        modality: ExerciseModality = .strength,
        instructions: String? = nil,
        notes: String? = nil,
        mediaKind: ExerciseMediaKind = .none,
        mediaAssetName: String? = nil,
        mediaURLString: String? = nil,
        equipmentTagsRaw: String = "",              // ✅ NEW
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
        
        self.equipmentTagsRaw = equipmentTagsRaw    // ✅ NEW

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
    
    var equipmentTags: [String] {
        equipmentTagsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    func setEquipmentTags(_ tags: [String]) {
        equipmentTagsRaw = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        updatedAt = Date()
    }
    
    var equipmentTagSet: Set<String> {
        Set(equipmentTags)
    }

    func matchesEquipmentFilter(_ selectedTags: Set<String>) -> Bool {
        guard !selectedTags.isEmpty else { return true }
        return !equipmentTagSet.isDisjoint(with: selectedTags)
    }
}
