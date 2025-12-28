//
//  WorkoutSessionView.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var workout: Workout
    @State private var showingExercisePicker = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if workout.exercises.isEmpty {
                        ContentUnavailableView("No Exercises Added", systemImage: "dumbbell", description: Text("Tap + to add an exercise."))
                    } else {
                        ForEach(workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { workoutExercise in
                            WorkoutExerciseRow(workoutExercise: workoutExercise)
                        }
                        .onDelete(perform: deleteExercise)
                    }
                }
                
                Button(action: { showingExercisePicker = true }) {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        dismiss()
                        modelContext.delete(workout)
                    }
                    .tint(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        finishWorkout()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { selectedExercise in
                    addExercise(selectedExercise)
                }
            }
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        let count = workout.exercises.count
        let newWorkoutExercise = WorkoutExercise(orderIndex: count)
        newWorkoutExercise.exercise = exercise
        newWorkoutExercise.workout = workout
        
        // Add one empty set to start
        let firstSet = WorkoutSet(orderIndex: 0)
        firstSet.workoutExercise = newWorkoutExercise
        newWorkoutExercise.sets.append(firstSet)
        
        workout.exercises.append(newWorkoutExercise)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        // Simple delete for now. Re-ordering logic would go here.
        withAnimation {
            // Because we are sorting in the view, we need to map the index back to the real array or just rely on SwiftData's relationship management
            // Ideally we delete the object from the context
            let sortedExercises = workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })
            for index in offsets {
                let exerciseToDelete = sortedExercises[index]
                if let indexInMain = workout.exercises.firstIndex(of: exerciseToDelete) {
                    workout.exercises.remove(at: indexInMain)
                    modelContext.delete(exerciseToDelete)
                }
            }
        }
    }
    
    private func finishWorkout() {
        workout.status = .completed
        workout.endTime = Date()
        dismiss()
    }
}

// A row representing one exercise (e.g., "Bench Press") and its sets
struct WorkoutExerciseRow: View {
    @Bindable var workoutExercise: WorkoutExercise
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(workoutExercise.exercise?.name ?? "Unknown Exercise")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Header
            HStack {
                Text("Set").frame(width: 30)
                Text("lbs").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text("RPE").frame(width: 40)
                Text("✓").frame(width: 30)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Sets
            ForEach(workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                WorkoutSetRow(set: set, index: set.orderIndex + 1)
            }
            .onDelete(perform: deleteSet)
            
            Button("Add Set") {
                addSet()
            }
            .font(.caption)
            .padding(.top, 4)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
    
    private func addSet() {
        let count = workoutExercise.sets.count
        // Copy values from previous set for convenience
        let lastSet = workoutExercise.sets.last
        
        let newSet = WorkoutSet(orderIndex: count)
        newSet.weight = lastSet?.weight
        newSet.reps = lastSet?.reps
        
        newSet.workoutExercise = workoutExercise
        workoutExercise.sets.append(newSet)
    }
    
    private func deleteSet(at offsets: IndexSet) {
        let sortedSets = workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex })
        for index in offsets {
            let setToDelete = sortedSets[index]
            modelContext.delete(setToDelete)
        }
    }
}

struct WorkoutSetRow: View {
    @Bindable var set: WorkoutSet
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index)")
                .frame(width: 30)
                .foregroundColor(.secondary)
            
            TextField("-", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .textFieldStyle(.roundedBorder)
            
            TextField("-", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .textFieldStyle(.roundedBorder)
            
            TextField("-", value: $set.rpe, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 40)
                .textFieldStyle(.roundedBorder)
            
            Button {
                withAnimation {
                    set.isCompleted.toggle()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .frame(width: 30)
        }
    }
}

// A simple picker reusing the logic from ExerciseListView but designed for selection
struct ExercisePickerView: View {
    var onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if !exercise.targetMuscleGroup.isEmpty {
                                Text(exercise.targetMuscleGroup)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Exercise")
            .searchable(text: $searchText)
        }
    }
}
