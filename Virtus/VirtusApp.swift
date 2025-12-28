//
//  VirtusApp.swift
//  Virtus
//
//  Created by Rishi Jaguar on 12/21/25.
//

import SwiftUI
import SwiftData

@main
struct VirtusApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            Program.self,
            ProgramDay.self,
            PlannedExercise.self,
            Workout.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            UserProfile.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
