//
//  ContentView.swift
//  Virtus
//
//  Created by Rishi Jaguar on 12/21/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }
            
            WorkoutHomeView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
            
            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet.rectangle.portrait.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .task {
            // Ensure database is seeded on app start
            ExerciseSeeder.seed(context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Program.self, Workout.self, UserProfile.self], inMemory: true)
}
