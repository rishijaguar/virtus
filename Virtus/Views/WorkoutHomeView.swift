//
//  WorkoutHomeView.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentWorkout: Workout?
    @State private var isPresentingWorkout = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "dumbbell.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                
                Text("Ready to train?")
                    .font(.title)
                    .bold()
                
                Button(action: startEmptyWorkout) {
                    Text("Start Empty Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                NavigationLink(destination: ProgramListView()) {
                    Text("Browse Programs")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Workout")
            .fullScreenCover(item: $currentWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
        }
    }
    
    private func startEmptyWorkout() {
        let newWorkout = Workout(startTime: Date(), status: .inProgress)
        modelContext.insert(newWorkout)
        // We set the state binding to trigger the sheet
        currentWorkout = newWorkout
    }
}

#Preview {
    WorkoutHomeView()
        .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}
