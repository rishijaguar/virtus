//
//  Exercise.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetMuscleGroup: String // e.g., "Chest", "Legs"
    var secondaryMuscleGroups: [String]
    var type: String // Using String for raw value of ExerciseType to simplify persistence
    var instructions: String?
    
    init(name: String, targetMuscleGroup: String, secondaryMuscleGroups: [String] = [], type: ExerciseType = .weight_reps, instructions: String? = nil) {
        self.id = UUID()
        self.name = name
        self.targetMuscleGroup = targetMuscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.type = type.rawValue
        self.instructions = instructions
    }
    
    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: type) ?? .weight_reps }
        set { type = newValue.rawValue }
    }
}

enum ExerciseType: String, Codable, CaseIterable {
    case weight_reps // Standard lifting
    case weight_time // Weighted holds
    case weight_distance // Farmers carry
    case bodyweight_reps // Pushups
    case bodyweight_time // Planks
    case cardio_time // Running
    case cardio_distance // Running
    case cardio_time_distance // Running
}
