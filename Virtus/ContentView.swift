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
            Text("Coach Interface")
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }
            
            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet.rectangle.portrait.fill")
                }
            
            Text("History & Stats")
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                
            Text("User Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Program.self, Workout.self, UserProfile.self], inMemory: true)
}
