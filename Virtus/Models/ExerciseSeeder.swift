//
//  ExerciseSeeder.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

struct ExerciseSeeder {
    static func seed(context: ModelContext) {
        // Check if we already have exercises to avoid duplicates
        let descriptor = FetchDescriptor<Exercise>()
        if let existingCount = try? context.fetchCount(descriptor), existingCount > 0 {
            print("Database already seeded with \(existingCount) exercises.")
            return
        }
        
        print("Seeding Exercise Database from Bundle JSON...")
        
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            print("❌ Error: exercises.json NOT FOUND in bundle.")
            print("Checking bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        print("✅ Found exercises.json at: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("✅ Read \(data.count) bytes from file.")
            let decoder = JSONDecoder()
            let dtos = try decoder.decode([ExerciseDTO].self, from: data)
            print("✅ Decoded \(dtos.count) exercises from JSON.")
            
            for dto in dtos {
                let type = ExerciseType(rawValue: dto.type) ?? .weight_reps
                let exercise = Exercise(
                    name: dto.name,
                    targetMuscleGroup: dto.targetMuscleGroup,
                    secondaryMuscleGroups: dto.secondaryMuscleGroups,
                    type: type,
                    instructions: dto.instructions
                )
                context.insert(exercise)
            }
            
            try context.save()
            print("🚀 Successfully seeded \(dtos.count) exercises.")
        } catch {
            print("❌ Failed to seed exercises: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding detail: \(decodingError)")
            }
        }
    }
}

// Temporary DTO for decoding
private struct ExerciseDTO: Codable {
    let name: String
    let targetMuscleGroup: String
    let secondaryMuscleGroups: [String]
    let type: String
    let instructions: String?
}
