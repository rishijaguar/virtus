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
    @Query private var profiles: [UserProfile]
    
    @Bindable var workout: Workout
    @State private var showingExercisePicker = false
    
    private var preferredUnit: WeightUnit {
        if let raw = profiles.first?.preferredUnitRaw {
            return WeightUnit(rawValue: raw) ?? .lbs
        }
        return .lbs
    }
    
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
        
        // Add one empty set to start with user's preferred unit
        let firstSet = WorkoutSet(orderIndex: 0, unit: preferredUnit)
        firstSet.workoutExercise = newWorkoutExercise
        newWorkoutExercise.sets.append(firstSet)
        
        workout.exercises.append(newWorkoutExercise)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        let sortedExercises = workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })
        for index in offsets {
            let exerciseToDelete = sortedExercises[index]
            if let indexInMain = workout.exercises.firstIndex(of: exerciseToDelete) {
                workout.exercises.remove(at: indexInMain)
                modelContext.delete(exerciseToDelete)
            }
        }
    }
    
    private func finishWorkout() {
        workout.status = .completed
        workout.endTime = Date()
        dismiss()
    }
}

struct WorkoutExerciseRow: View {
    @Bindable var workoutExercise: WorkoutExercise
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workoutExercise.exercise?.name ?? "Unknown Exercise")
                .font(.headline)
            
            // Header aligning with the new spec
            HStack(spacing: 8) {
                Text("Set").font(.caption2).frame(width: 24)
                Text("Instr.").font(.caption2).frame(width: 45, alignment: .leading)
                Text(targetColumnTitle).font(.caption2).frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight").font(.caption2).frame(width: 60)
                Text("Reps").font(.caption2).frame(width: 40)
                Text("RPE").font(.caption2).frame(width: 35)
                Spacer().frame(width: 24) // Checkmark column
            }
            .foregroundColor(.secondary)
            
            ForEach(workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                WorkoutSetRow(set: set)
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
    
    private var targetColumnTitle: String {
        // If we have a session template, it's "Target". 
        // If we have no template but have history values, it's "Previous".
        if workoutExercise.workout?.sessionTemplateID != nil {
            return "Target"
        } else {
            return "Prev."
        }
    }
    
    private func addSet() {
        let count = workoutExercise.sets.count
        let lastSet = workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex }).last
        
        let newSet = WorkoutSet(orderIndex: count)
        newSet.weight = lastSet?.weight
        newSet.reps = lastSet?.reps
        newSet.unit = lastSet?.unit ?? .lbs
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
    
    var body: some View {
        HStack(spacing: 8) {
            // Set Number
            Text("\(set.orderIndex + 1)")
                .frame(width: 24)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Intensity Instruction (Static display)
            Text(set.displayIntensity ?? "-")
                .font(.caption2)
                .frame(width: 45, alignment: .leading)
                .lineLimit(1)
            
            // Target / Previous (Static display)
            Text(set.computedTarget ?? "-")
                .font(.caption2)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            
            // Weight Input
            HStack(spacing: 2) {
                TextField("0", value: optionalBinding($set.weight), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                
                Text(set.unitRaw)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 75)
            
            // Reps Input
            TextField("0", value: optionalIntBinding($set.reps), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
            
            // RPE Input
            TextField("-", value: optionalBinding($set.rpe), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 35)
            
            // Completion Toggle
            Button {
                withAnimation {
                    set.isCompleted.toggle()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .green : .gray)
            }
            .buttonStyle(.borderless)
            .frame(width: 24)
        }
        .opacity(set.isCompleted ? 0.6 : 1.0)
    }
    
    // Helper helpers
    func optionalBinding(_ binding: Binding<Double?>) -> Binding<Double> {
        Binding(
            get: { binding.wrappedValue ?? 0.0 },
            set: { binding.wrappedValue = $0 }
        )
    }
    func optionalIntBinding(_ binding: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { binding.wrappedValue ?? 0 },
            set: { binding.wrappedValue = $0 }
        )
    }
}

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
                            Text(exercise.targetMuscleGroup)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
